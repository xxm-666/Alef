import Foundation
import Security

enum StudyAIProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    case aliyun = "Aliyun"

    var id: Self { self }

    var title: String {
        switch self {
        case .openAI: "OpenAI"
        case .openRouter: "OpenRouter · Whisper"
        case .aliyun: "阿里云 · 希伯来语"
        }
    }

    var model: String? {
        switch self {
        case .openAI: "gpt-4o-mini-transcribe"
        case .openRouter: "openai/whisper-large-v3"
        case .aliyun: nil
        }
    }

    func endpoint(gateway: String) throws -> URL {
        switch self {
        case .openAI: return URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        case .openRouter: return URL(string: "https://openrouter.ai/api/v1/audio/transcriptions")!
        case .aliyun:
            let text = gateway.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let components = URLComponents(string: text), components.scheme?.lowercased() == "https",
                  let host = components.host, !host.isEmpty,
                  components.user == nil, components.password == nil,
                  components.query == nil, components.fragment == nil,
                  let url = components.url else { throw StudyAIError.invalidGateway }
            return url
        }
    }
}

enum StudyAIKeychain {
    static let enabledKey = "alef.device.aiEnabled"
    static let gatewayKey = "alef.device.aiAliyunGateway"
    static let providerKey = "alef.device.aiProvider"
    static let revisionKey = "alef.device.aiSettingsRevision"

    private static func query(for provider: StudyAIProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.xxm666.alef.ai",
            kSecAttrAccount as String: provider.rawValue,
            kSecAttrSynchronizable as String: false
        ]
    }

    static func read(for provider: StudyAIProvider) throws -> String? {
        var lookup = query(for: provider)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else { throw StudyAIError.storage }
        return key
    }

    static func save(_ value: String, for provider: StudyAIProvider) throws {
        let query = query(for: provider)
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.utf8.allSatisfy({ (33...126).contains($0) }) else {
            throw StudyAIError.invalidKey
        }

        let update: [String: Any] = [kSecValueData as String: Data(key.utf8)]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var item = query.merging(update) { _, value in value }
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw StudyAIError.storage }
        } else if status != errSecSuccess {
            throw StudyAIError.storage
        }
    }

    static func remove(for provider: StudyAIProvider) throws {
        let status = SecItemDelete(query(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StudyAIError.storage }
    }
}

enum StudyAIError: LocalizedError {
    case storage, invalidKey, noKey, invalidGateway, invalidRecording, unauthorized, quota, requestFailed, noSpeech, timedOut

    var errorDescription: String? {
        switch self {
        case .storage: "无法访问本机钥匙串，请解锁设备后重试。"
        case .invalidKey: "请输入完整的 API 密钥，密钥中不能包含空格或换行。"
        case .noKey: "请先到「我的 → AI 功能」保存此服务的密钥。"
        case .invalidGateway: "请输入有效的 HTTPS 阿里云测试网关地址。"
        case .timedOut: "服务没有在测试等待时间内返回结果。阿里云录音任务可能仍在排队。"
        case .invalidRecording: "无法读取这次录音，请重录后再试。"
        case .unauthorized: "识别服务拒绝了请求，请检查 API 密钥和项目权限。"
        case .quota: "识别服务已达到请求频率或用量上限，请检查账户用量后重试。"
        case .requestFailed: "暂时无法连接或完成识别，请稍后重试。"
        case .noSpeech: "没有识别到可对照的希伯来语，请清楚地读一遍再试。"
        }
    }
}

struct StudyAITranscript: Sendable {
    let text: String
    let missingWords: [String]
    let extraWords: [String]

    init(text: String, expected: String) throws {
        let recognized = Self.words(in: text)
        guard recognized.contains(where: { $0.unicodeScalars.contains { (0x05D0...0x05EA).contains($0.value) } }) else {
            throw StudyAIError.noSpeech
        }
        self.text = text
        let difference = recognized.difference(from: Self.words(in: expected))
        missingWords = difference.removals.reversed().compactMap {
            if case let .remove(_, word, _) = $0 { return word }
            return nil
        }
        extraWords = difference.insertions.compactMap {
            if case let .insert(_, word, _) = $0 { return word }
            return nil
        }
    }

    private static func words(in text: String) -> [String] {
        // Niqqud and cantillation mark pronunciation but do not affect word matching.
        let scalars = text.decomposedStringWithCanonicalMapping.lowercased().unicodeScalars.filter {
            $0.properties.generalCategory != .nonspacingMark
        }
        return scalars.split { !CharacterSet.alphanumerics.contains($0) }.map {
            String(String.UnicodeScalarView($0))
        }
    }
}

enum StudyAITranscription {
    private struct Response: Decodable {
        let text: String
    }

    // The authorization header is sent only to the fixed API endpoint.
    private final class NoRedirect: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    static func analyze(recording: URL, expected: String, provider: StudyAIProvider, gateway: String) async throws -> StudyAITranscript {
        let endpoint = try provider.endpoint(gateway: gateway)
        guard let key = try StudyAIKeychain.read(for: provider) else { throw StudyAIError.noKey }
        guard let size = try? recording.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= 5_000_000,
              let data = try? Data(contentsOf: recording) else { throw StudyAIError.invalidRecording }
        try Task.checkCancellation()

        var request = URLRequest(url: endpoint, timeoutInterval: 55)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let body: Data
        if let model = provider.model {
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            body = multipart(audio: data, model: model, boundary: boundary)
        } else {
            request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
            body = data
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 60
        let session = URLSession(configuration: configuration, delegate: NoRedirect(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let (responseData, response) = try await session.upload(for: request, from: body)
        switch (response as? HTTPURLResponse)?.statusCode {
        case 200:
            guard let decoded = try? JSONDecoder().decode(Response.self, from: responseData) else {
                throw StudyAIError.requestFailed
            }
            return try StudyAITranscript(text: decoded.text, expected: expected)
        case 401, 403: throw StudyAIError.unauthorized
        case 422 where provider == .aliyun: throw StudyAIError.noSpeech
        case 429: throw StudyAIError.quota
        case 504 where provider == .aliyun: throw StudyAIError.timedOut
        default: throw StudyAIError.requestFailed
        }
    }
    static func multipart(audio: Data, model: String, boundary: String) -> Data {
        var body = Data()
        for (name, value) in [("model", model), ("language", "he"), ("response_format", "json")] {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"recording.m4a\"\r\nContent-Type: audio/mp4\r\n\r\n".utf8))
        body.append(audio)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }

}
