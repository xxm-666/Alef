# 阿里云希伯来语跟读测试网关

1. 在阿里云智能语音交互控制台创建录音文件识别项目，选「通用-希伯来语（16 kHz）」，取得项目 AppKey。创建同地域的私有 OSS Bucket，并为 `alef-transcription/` 配置生命周期清理规则作为兜底。
2. 使用仅可提交和查询录音识别任务、读写及删除该 OSS 前缀的 RAM 凭据。在测试服务器的环境中设置以下变量。阿里云凭据留在服务端。

   | 变量 | 值 |
   |---|---|
   | `ALIBABA_CLOUD_ACCESS_KEY_ID`、`ALIBABA_CLOUD_ACCESS_KEY_SECRET` | RAM 凭据 |
   | `ALEF_NLS_APP_KEY` | 希伯来语项目 AppKey |
   | `ALEF_OSS_BUCKET` | 私有 Bucket 名称 |
   | `ALEF_OSS_REGION` | Bucket 与识别项目地域，默认 `cn-shanghai` |
   | `ALEF_GATEWAY_KEY` | 至少 24 字符的随机测试密钥，例如用 `openssl rand -hex 24` 生成 |
3. 在本目录执行 `python -m pip install -r requirements.txt`，然后执行 `python server.py`。服务监听 `127.0.0.1:8765`。在 HTTPS 反向代理中仅转发 `POST /transcribe`，允许最多 5 MB 的请求体，设置至少 60 秒的上游读超时。
4. iPhone 上打开「我的 → AI 功能」，选择「阿里云 · 希伯来语」，填写完整 HTTPS 地址（例如 `https://你的测试域名/transcribe`）和 `ALEF_GATEWAY_KEY`。配置 OpenRouter 时直接填写自己的 OpenRouter API Key。启用后可用同一段录音分别请求两家服务。

网关在识别结束或超时后尝试删除临时 OSS 音频。识别任务异步排队，测试端最多轮询约半分钟，超时会立即反馈，阿里云可能仍在处理任务。服务只适用于受控测试环境。
