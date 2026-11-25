import Foundation

struct StudyWidgetWord: Decodable, Equatable {
    let id: String
    let hebrew: String
    let transliteration: String
    let meaningZh: String

    static let preview = Self(id: "shalom", hebrew: "שָׁלוֹם", transliteration: "shalom", meaningZh: "你好；和平")
}

enum StudyWidgetWords {
    // Keep the kind used by the original default widget so existing placements update in place.
    static let kind = "DailyLetterWidget"
    static let groupID = "group.com.xxm666.alef.study"
    static let interval: TimeInterval = 2 * 60 * 60

    static func candidates(for learnedIDs: Set<String>, in vocabulary: [StudyWidgetWord]) -> [StudyWidgetWord] {
        vocabulary.filter { learnedIDs.contains($0.id) }.sorted { $0.id < $1.id }
    }

    static func word(on date: Date, from candidates: [StudyWidgetWord]) -> StudyWidgetWord? {
        guard !candidates.isEmpty else { return nil }
        let slot = Int(floor(date.timeIntervalSince1970 / interval))
        let remainder = slot % candidates.count
        return candidates[remainder < 0 ? remainder + candidates.count : remainder]
    }

    static func timelineDates(from now: Date) -> [Date] {
        let start = floor(now.timeIntervalSince1970 / interval) * interval
        return [now] + (1...12).map { Date(timeIntervalSince1970: start + Double($0) * interval) }
    }

    static func groupIdentifiers(signedGroups: [String], provisioningProfile: Data? = nil) -> [String] {
        var seen: Set<String> = []
        let provisioned = provisioningProfile.map(groups(in:)) ?? []
        return (provisioned + signedGroups + [groupID]).filter { identifier in
            (identifier == groupID || identifier.hasPrefix(groupID + ".")) && seen.insert(identifier).inserted
        }
    }

    private static func groups(in profile: Data) -> [String] {
        // Development provisioning profiles wrap an XML property list in a CMS signature.
        guard let start = profile.range(of: Data("<?xml".utf8))?.lowerBound,
              let end = profile.range(of: Data("</plist>".utf8), in: start..<profile.endIndex)?.upperBound,
              let payload = try? PropertyListSerialization.propertyList(from: profile[start..<end],
                                                                       options: [], format: nil),
              let fields = payload as? [String: Any],
              let entitlements = fields["Entitlements"] as? [String: Any] else { return [] }
        return entitlements["com.apple.security.application-groups"] as? [String] ?? []
    }

    #if os(iOS)
    private static let installedGroupIdentifiers: [String] = {
        let bundle = Bundle.main
        let signedGroups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? []
        // SideStore can provision a team-suffixed group without adding ALTAppGroups to Info.plist.
        let profile = try? Data(contentsOf: bundle.bundleURL.appendingPathComponent("embedded.mobileprovision"))
        return groupIdentifiers(signedGroups: signedGroups, provisioningProfile: profile)
    }()

    static var snapshotURL: URL? {
        let manager = FileManager.default
        for group in installedGroupIdentifiers {
            if let container = manager.containerURL(forSecurityApplicationGroupIdentifier: group),
               manager.fileExists(atPath: container.path) {
                return container.appendingPathComponent("learned-widget-words.json")
            }
        }
        return nil
    }
    #endif

    static func readIDs(from url: URL) -> Set<String> {
        guard let data = try? Data(contentsOf: url),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return Set(ids)
    }

    static func writeIDs(_ ids: Set<String>, to url: URL) throws -> Bool {
        let data = try JSONEncoder().encode(ids.sorted())
        guard data != (try? Data(contentsOf: url)) else { return false }
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        return true
    }
}
