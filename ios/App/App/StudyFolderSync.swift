import Foundation
import Observation

enum StudySyncMerger {
    private enum Side { case local, remote }

    static func merge(local: [String: Data], remote: [String: Data],
                      localUpdatedAt: Int64, remoteUpdatedAt: Int64) -> [String: Data] {
        var result: [String: Data] = [:]
        let allKeys = Set(local.keys).union(remote.keys)

        let wordSrsWinner = srsWinners(
            local: decode([String: ReviewSchedule].self, from: local["alef.wordSrs.v1"]),
            remote: decode([String: ReviewSchedule].self, from: remote["alef.wordSrs.v1"]),
            remotePreferOnTie: remoteUpdatedAt > localUpdatedAt
        )
        let letterSrsWinner = srsWinners(
            local: decode([String: ReviewSchedule].self, from: local[StudyProgress.letterScheduleKey]),
            remote: decode([String: ReviewSchedule].self, from: remote[StudyProgress.letterScheduleKey]),
            remotePreferOnTie: remoteUpdatedAt > localUpdatedAt
        )

        for key in allKeys {
            switch (local[key], remote[key]) {
            case let (lData?, nil):
                result[key] = lData
            case let (nil, rData?):
                result[key] = rData
            case let (lData?, rData?):
                result[key] = mergeEntry(
                    key: key,
                    local: lData,
                    remote: rData,
                    localUpdatedAt: localUpdatedAt,
                    remoteUpdatedAt: remoteUpdatedAt,
                    wordSrsWinner: wordSrsWinner,
                    letterSrsWinner: letterSrsWinner
                )
            case (nil, nil):
                break
            }
        }
        return result
    }

    static func canonicalEqual(_ lhs: [String: Data], _ rhs: [String: Data]) -> Bool {
        guard Set(lhs.keys) == Set(rhs.keys) else { return false }
        return lhs.keys.allSatisfy { key in
            guard let a = lhs[key], let b = rhs[key] else { return false }
            return canonicalJSON(a) == canonicalJSON(b)
        }
    }

    private static func mergeEntry(key: String, local lData: Data, remote rData: Data,
                                   localUpdatedAt: Int64, remoteUpdatedAt: Int64,
                                   wordSrsWinner: [String: Side], letterSrsWinner: [String: Side]) -> Data {
        switch key {
        case "alef.studyStats.v1":
            guard let l = decode(StudyStatistics.self, from: lData),
                  let r = decode(StudyStatistics.self, from: rData) else {
                return remoteUpdatedAt > localUpdatedAt ? rData : lData
            }
            var merged = StudyStatistics()
            merged.totalReviews = max(l.totalReviews, r.totalReviews)
            merged.streakDays = max(l.streakDays, r.streakDays)
            if l.lastActiveDate == r.lastActiveDate {
                merged.lastActiveDate = l.lastActiveDate
                merged.todayReviews = max(l.todayReviews, r.todayReviews)
            } else if r.lastActiveDate > l.lastActiveDate {
                merged.lastActiveDate = r.lastActiveDate
                merged.todayReviews = r.todayReviews
            } else {
                merged.lastActiveDate = l.lastActiveDate
                merged.todayReviews = l.todayReviews
            }
            return encode(merged) ?? (remoteUpdatedAt > localUpdatedAt ? rData : lData)

        case "alef.wordSrs.v1", StudyProgress.letterScheduleKey:
            guard let l = decode([String: ReviewSchedule].self, from: lData),
                  let r = decode([String: ReviewSchedule].self, from: rData) else {
                return remoteUpdatedAt > localUpdatedAt ? rData : lData
            }
            var merged: [String: ReviewSchedule] = [:]
            for id in Set(l.keys).union(r.keys) {
                switch (l[id], r[id]) {
                case let (a?, nil): merged[id] = a
                case let (nil, b?): merged[id] = b
                case let (a?, b?):
                    merged[id] = pickSchedule(a, b, remotePreferOnTie: remoteUpdatedAt > localUpdatedAt) == .remote ? b : a
                case (nil, nil): break
                }
            }
            return encode(merged) ?? (remoteUpdatedAt > localUpdatedAt ? rData : lData)

        case "alef.wordMastery.v1", "alef.mastery.v1":
            guard let l = decode([String: Mastery].self, from: lData),
                  let r = decode([String: Mastery].self, from: rData) else {
                return remoteUpdatedAt > localUpdatedAt ? rData : lData
            }
            let winners = key == "alef.wordMastery.v1" ? wordSrsWinner : letterSrsWinner
            var merged: [String: Mastery] = [:]
            for id in Set(l.keys).union(r.keys) {
                switch (l[id], r[id]) {
                case let (a?, nil): merged[id] = a
                case let (nil, b?): merged[id] = b
                case let (a?, b?):
                    if let side = winners[id] {
                        merged[id] = side == .remote ? b : a
                    } else {
                        merged[id] = masteryRank(b) > masteryRank(a) ? b : a
                    }
                case (nil, nil): break
                }
            }
            return encode(merged) ?? (remoteUpdatedAt > localUpdatedAt ? rData : lData)

        case "alef.favoriteWords.v1", "alef.native.phraseFavorites.v1":
            guard let l = decode([String].self, from: lData),
                  let r = decode([String].self, from: rData) else {
                return remoteUpdatedAt > localUpdatedAt ? rData : lData
            }
            var seen = Set<String>()
            var merged: [String] = []
            for id in l + r where seen.insert(id).inserted {
                merged.append(id)
            }
            return encode(merged) ?? lData

        case DailyVocabularyPlan.storageKey:
            guard let l = decode(DailyVocabularyPlan.self, from: lData),
                  let r = decode(DailyVocabularyPlan.self, from: rData) else {
                return remoteUpdatedAt > localUpdatedAt ? rData : lData
            }
            if l.isValid != r.isValid { return r.isValid ? rData : lData }
            if r.day != l.day { return r.day > l.day ? rData : lData }
            let lScore = dailyScore(l)
            let rScore = dailyScore(r)
            if rScore != lScore { return rScore > lScore ? rData : lData }
            return remoteUpdatedAt > localUpdatedAt ? rData : lData

        default:
            return remoteUpdatedAt > localUpdatedAt ? rData : lData
        }
    }

    private static func srsWinners(local: [String: ReviewSchedule]?, remote: [String: ReviewSchedule]?,
                                   remotePreferOnTie: Bool) -> [String: Side] {
        guard let local, let remote else { return [:] }
        var winners: [String: Side] = [:]
        for id in Set(local.keys).intersection(remote.keys) {
            if let a = local[id], let b = remote[id] {
                winners[id] = pickSchedule(a, b, remotePreferOnTie: remotePreferOnTie)
            }
        }
        return winners
    }

    private static func pickSchedule(_ a: ReviewSchedule, _ b: ReviewSchedule, remotePreferOnTie: Bool) -> Side {
        if a.nextReviewAt != b.nextReviewAt { return b.nextReviewAt > a.nextReviewAt ? .remote : .local }
        if a.repetitions != b.repetitions { return b.repetitions > a.repetitions ? .remote : .local }
        if a.lapses != b.lapses { return b.lapses > a.lapses ? .remote : .local }
        return remotePreferOnTie ? .remote : .local
    }

    private static func masteryRank(_ mastery: Mastery) -> Int {
        switch mastery {
        case .unlearned: 0
        case .learning: 1
        case .mastered: 2
        }
    }

    private static func dailyScore(_ plan: DailyVocabularyPlan) -> Int {
        let completed = plan.completedCount * 1_000
        let steps = plan.groups.reduce(0) { $0 + $1.studied + $1.answers.count + ($1.isComplete ? 1 : 0) }
        return completed + steps
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func canonicalJSON(_ data: Data) -> Data {
        do {
            let value = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
            return try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        } catch {
            return data
        }
    }
}

protocol StudySyncFolderStorage {
    func read(bookmarkData: Data, fileName: String) async throws -> (data: Data?, refreshedBookmark: Data?)
    func write(_ data: Data, bookmarkData: Data, fileName: String) async throws -> Data?
}

struct CoordinatedFolderStorage: StudySyncFolderStorage {
    func read(bookmarkData: Data, fileName: String) async throws -> (data: Data?, refreshedBookmark: Data?) {
        try await Task.detached(priority: .utility) {
            var isStale = false
            let folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let accessed = folderURL.startAccessingSecurityScopedResource()
            defer { if accessed { folderURL.stopAccessingSecurityScopedResource() } }

            let refreshed = isStale
                ? (try? folderURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil))
                : nil

            let fileURL = folderURL.appendingPathComponent(fileName, isDirectory: false)
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordError: NSError?
            var readData: Data?
            var readError: Error?

            coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordError) { targetURL in
                guard FileManager.default.fileExists(atPath: targetURL.path) else {
                    readData = nil
                    return
                }
                do {
                    readData = try Data(contentsOf: targetURL)
                } catch {
                    readError = error
                }
            }

            if let coordError { throw coordError }
            if let readError { throw readError }
            return (readData, refreshed)
        }.value
    }

    func write(_ data: Data, bookmarkData: Data, fileName: String) async throws -> Data? {
        try await Task.detached(priority: .utility) {
            var isStale = false
            let folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let accessed = folderURL.startAccessingSecurityScopedResource()
            defer { if accessed { folderURL.stopAccessingSecurityScopedResource() } }

            let refreshed = isStale
                ? (try? folderURL.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil))
                : nil

            let fileURL = folderURL.appendingPathComponent(fileName, isDirectory: false)
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordError: NSError?
            var writeError: Error?

            coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordError) { targetURL in
                do {
                    try data.write(to: targetURL, options: .atomic)
                } catch {
                    writeError = error
                }
            }

            if let coordError { throw coordError }
            if let writeError { throw writeError }
            return refreshed
        }.value
    }
}

@MainActor
@Observable
final class StudyFolderSyncManager {
    enum SyncState: Equatable {
        case unconfigured
        case idle
        case syncing
        case synced(Date)
        case failed(String)
    }

    static let syncFileName = "alef-sync.json"
    private static let bookmarkKey = "alef.sync.folderBookmark.v1"
    private static let folderNameKey = "alef.sync.folderName.v1"
    private static let lastSyncedAtKey = "alef.sync.lastSyncedAt.v1"

    private let defaults: UserDefaults
    private let storage: any StudySyncFolderStorage
    private var bookmarkData: Data?
    private var isSyncing = false

    private(set) var folderName: String?
    private(set) var state: SyncState
    private(set) var lastSummary: String?

    var isConfigured: Bool { bookmarkData != nil }

    init(defaults: UserDefaults = .standard, storage: any StudySyncFolderStorage = CoordinatedFolderStorage()) {
        self.defaults = defaults
        self.storage = storage
        let savedBookmark = defaults.data(forKey: Self.bookmarkKey)
        bookmarkData = savedBookmark
        folderName = defaults.string(forKey: Self.folderNameKey)
        if savedBookmark != nil {
            let timestamp = (defaults.object(forKey: Self.lastSyncedAtKey) as? NSNumber)?.int64Value ?? 0
            state = timestamp > 0
                ? .synced(Date(timeIntervalSince1970: Double(timestamp) / 1_000))
                : .idle
        } else {
            state = .unconfigured
        }
    }

    func configureFolder(url: URL, progress: StudyProgress) async {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let name = url.lastPathComponent.isEmpty ? "同步文件夹" : url.lastPathComponent
            saveBookmark(bookmark, name: name)
            await sync(progress: progress, force: true)
        } catch {
            state = .failed("无法保存文件夹访问权限：\(error.localizedDescription)")
        }
    }

    func disconnect() {
        bookmarkData = nil
        folderName = nil
        lastSummary = nil
        state = .unconfigured
        defaults.removeObject(forKey: Self.bookmarkKey)
        defaults.removeObject(forKey: Self.folderNameKey)
        defaults.removeObject(forKey: Self.lastSyncedAtKey)
    }

    func sync(progress: StudyProgress, now: Date = .now, force: Bool = false) async {
        guard !isSyncing, let initialBookmark = bookmarkData else { return }
        isSyncing = true
        state = .syncing
        defer { isSyncing = false }

        do {
            let readResult = try await storage.read(bookmarkData: initialBookmark, fileName: Self.syncFileName)
            if let refreshed = readResult.refreshedBookmark {
                saveBookmark(refreshed, name: folderName)
            }

            let activeBookmark = bookmarkData ?? initialBookmark
            let localSnapshot = progress.syncSnapshot()

            if let remoteData = readResult.data {
                let remote: (entries: [String: Data], updatedAt: Int64)
                do {
                    remote = try progress.parseSyncDocument(remoteData)
                } catch {
                    state = .failed("同步文件 \(Self.syncFileName) 格式无效，已保留本机数据。")
                    return
                }

                let merged: [String: Data]
                let mergedUpdatedAt: Int64
                if !progress.hasMeaningfulData {
                    merged = remote.entries
                    mergedUpdatedAt = remote.updatedAt
                } else {
                    merged = StudySyncMerger.merge(
                        local: localSnapshot,
                        remote: remote.entries,
                        localUpdatedAt: progress.localUpdatedAt,
                        remoteUpdatedAt: remote.updatedAt
                    )
                    let baseTime = max(progress.localUpdatedAt, remote.updatedAt)
                    if !StudySyncMerger.canonicalEqual(localSnapshot, merged)
                        && !StudySyncMerger.canonicalEqual(remote.entries, merged) {
                        mergedUpdatedAt = max(baseTime, Int64(now.timeIntervalSince1970 * 1_000))
                    } else {
                        mergedUpdatedAt = baseTime
                    }
                }

                let localChanged = !StudySyncMerger.canonicalEqual(localSnapshot, merged)
                let remoteChanged = !StudySyncMerger.canonicalEqual(remote.entries, merged)

                if remoteChanged {
                    let payload = try progress.encodeSyncDocument(entries: merged, updatedAt: mergedUpdatedAt)
                    if let refreshed = try await storage.write(payload, bookmarkData: activeBookmark, fileName: Self.syncFileName) {
                        saveBookmark(refreshed, name: folderName)
                    }
                }

                if localChanged {
                    progress.applySyncedEntries(merged, updatedAt: mergedUpdatedAt, syncDate: now)
                } else {
                    progress.markBackupExported(on: now)
                }

                if localChanged && remoteChanged {
                    lastSummary = "已双向合并本机与云端进度"
                } else if localChanged {
                    lastSummary = "已从同步文件夹恢复最新进度"
                } else if remoteChanged {
                    lastSummary = "已将本机进度同步到文件夹"
                } else {
                    lastSummary = "本机与同步文件夹已是最新"
                }
            } else if progress.hasMeaningfulData {
                let timestamp = max(progress.localUpdatedAt, Int64(now.timeIntervalSince1970 * 1_000))
                let payload = try progress.encodeSyncDocument(entries: localSnapshot, updatedAt: timestamp)
                if let refreshed = try await storage.write(payload, bookmarkData: activeBookmark, fileName: Self.syncFileName) {
                    saveBookmark(refreshed, name: folderName)
                }
                progress.markBackupExported(on: now)
                lastSummary = "已创建并上传 \(Self.syncFileName)"
            } else if force {
                lastSummary = "已连接同步文件夹，开始学习后将自动同步"
            } else {
                state = .idle
                return
            }

            let syncedMs = Int64(now.timeIntervalSince1970 * 1_000)
            defaults.set(NSNumber(value: syncedMs), forKey: Self.lastSyncedAtKey)
            state = .synced(now)
        } catch {
            state = .failed("同步失败：\(error.localizedDescription)")
        }
    }

    private func saveBookmark(_ data: Data, name: String?) {
        bookmarkData = data
        defaults.set(data, forKey: Self.bookmarkKey)
        if let name {
            folderName = name
            defaults.set(name, forKey: Self.folderNameKey)
        }
    }
}
