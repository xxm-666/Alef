"""Test-only HTTPS upstream for Alef's Aliyun Hebrew transcription option."""

import hmac
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import BoundedSemaphore
from time import monotonic, sleep
from urllib.parse import urlsplit
from uuid import uuid4

import oss2
from aliyunsdkcore.client import AcsClient
from aliyunsdkcore.request import CommonRequest

MAX_AUDIO_BYTES = 5_000_000
REGIONS = {"cn-shanghai", "cn-beijing", "cn-shenzhen"}
PENDING = {"RUNNING", "QUEUEING"}
CAPACITY = BoundedSemaphore(2)


class NoSpeech(Exception):
    pass


class AliyunTranscriber:
    def __init__(self):
        self.region = os.environ.get("ALEF_OSS_REGION", "cn-shanghai")
        if self.region not in REGIONS:
            raise ValueError("Set ALEF_OSS_REGION to cn-shanghai, cn-beijing, or cn-shenzhen.")
        self.app_key = os.environ["ALEF_NLS_APP_KEY"]
        self.access_id = os.environ["ALIBABA_CLOUD_ACCESS_KEY_ID"]
        self.access_secret = os.environ["ALIBABA_CLOUD_ACCESS_KEY_SECRET"]
        self.bucket_name = os.environ["ALEF_OSS_BUCKET"]

    def request(self, client, action, method, parameter, value):
        request = CommonRequest()
        request.set_protocol_type("https")
        request.set_domain(f"filetrans.{self.region}.aliyuncs.com")
        request.set_version("2018-08-17")
        request.set_action_name(action)
        request.set_method(method)
        if method == "POST":
            request.add_body_params(parameter, value)
        else:
            request.add_query_param(parameter, value)
        return json.loads(client.do_action_with_exception(request))

    def transcribe(self, audio):
        client = AcsClient(self.access_id, self.access_secret, self.region, timeout=5)
        bucket = oss2.Bucket(
            oss2.AuthV4(self.access_id, self.access_secret),
            f"https://oss-{self.region}.aliyuncs.com",
            self.bucket_name,
            region=self.region,
            connect_timeout=5,
        )
        key = f"alef-transcription/{uuid4().hex}.m4a"
        uploaded = False
        try:
            bucket.put_object(key, audio, headers={"Content-Type": "audio/mp4"})
            uploaded = True
            file_link = bucket.sign_url("GET", key, 300, slash_safe=True)
            task = {
                "appkey": self.app_key,
                "file_link": file_link,
                "version": "4.0",
                "enable_sample_rate_adaptive": True,
            }
            submitted = self.request(client, "SubmitTask", "POST", "Task", json.dumps(task))
            if submitted.get("StatusText") != "SUCCESS" or not submitted.get("TaskId"):
                raise RuntimeError("Recognition task was rejected.")
            deadline = monotonic() + 32
            while monotonic() < deadline:
                sleep(1.5)
                result = self.request(client, "GetTaskResult", "GET", "TaskId", submitted["TaskId"])
                status = result.get("StatusText")
                if status in PENDING:
                    continue
                if status == "SUCCESS_WITH_NO_VALID_FRAGMENT":
                    raise NoSpeech
                if status != "SUCCESS":
                    raise RuntimeError("Recognition task failed.")
                sentences = result.get("Result", {}).get("Sentences", [])
                text = " ".join(sentence["Text"].strip() for sentence in sentences).strip()
                if not text:
                    raise NoSpeech
                return text
            raise TimeoutError
        finally:
            if uploaded:
                try:
                    bucket.delete_object(key)
                except Exception:
                    # Configure an OSS lifecycle rule for cleanup if the object cannot be deleted here.
                    print("Temporary audio cleanup failed.", flush=True)


class TestGateway(BaseHTTPRequestHandler):
    def setup(self):
        super().setup()
        self.connection.settimeout(10)

    def log_message(self, *args):
        pass

    def reply(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_POST(self):
        if urlsplit(self.path).path != "/transcribe":
            self.reply(404, {"error": "not_found"})
            return
        authorization = self.headers.get("Authorization", "").encode("utf-8")
        if not hmac.compare_digest(authorization, self.server.authorization):
            self.reply(401, {"error": "unauthorized"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if not 0 < length <= MAX_AUDIO_BYTES or self.headers.get_content_type() != "audio/mp4":
            self.reply(400, {"error": "invalid_audio"})
            return
        if not CAPACITY.acquire(blocking=False):
            self.reply(429, {"error": "busy"})
            return
        try:
            audio = self.rfile.read(length)
            if len(audio) != length:
                self.reply(400, {"error": "incomplete_audio"})
                return
            text = self.server.transcriber.transcribe(audio)
        except NoSpeech:
            self.reply(422, {"error": "no_speech"})
        except TimeoutError:
            self.reply(504, {"error": "timeout"})
        except Exception:
            self.reply(502, {"error": "recognition_failed"})
        else:
            self.reply(200, {"text": text})
        finally:
            CAPACITY.release()


def main():
    token = os.environ["ALEF_GATEWAY_KEY"]
    if not token.isascii() or len(token) < 24 or any(not 33 <= ord(char) <= 126 for char in token):
        raise ValueError("ALEF_GATEWAY_KEY must be at least 24 printable, non-space ASCII characters.")
    transcriber = AliyunTranscriber()
    # Bind to loopback. Use a TLS-terminating reverse proxy on the test server.
    with ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("ALEF_GATEWAY_PORT", "8765"))), TestGateway) as server:
        server.authorization = f"Bearer {token}".encode("ascii")
        server.transcriber = transcriber
        server.serve_forever()


if __name__ == "__main__":
    main()
