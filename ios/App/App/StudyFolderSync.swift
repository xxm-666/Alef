import Foundation
import Observation

enum StudySyncMerger {
    static let itemVersionsKey = "alef.sync.itemVersions.v1"
    private typealias ItemVersions = [String: [String: Int64]]
    private static let reviewKeys = [
        ("alef.wordSrs.v1", "alef.wordMastery.v1"),
        (StudyProgress.letterScheduleKey, "alef.mastery.v1")
    ]
    private static let favoriteKeys = ["alef.favoriteWords.v1", "alef.native.phraseFavorites.v1"]

    private static let appearanceKeys = [StudyProgress.appearanceKey, StudyProgress.themeKey, StudyProgress.dayThemeKey]
    private static let appearanceVersionItem = "selection"

    static func stampChanges(from old: [String: Data], to updated: inout [String: Data], at timestamp: Int64) {
        var versions = decode(ItemVersions.self, from: old[itemVersionsKey]) ?? [:]
        for (scheduleKey, masteryKey) in reviewKeys {
            guard old[scheduleKey] != updated[scheduleKey] || old[masteryKey] != updated[masteryKey] else { continue }
            let oldSchedules = decode([String: ReviewSchedule].self, from: old[scheduleKey]) ?? [:]
            let newSchedules = decode([String: ReviewSchedule].self, from: updated[scheduleKey]) ?? [:]
            let oldMastery = decode([String: Mastery].self, from: old[masteryKey]) ?? [:]
            let newMastery = decode([String: Mastery].self, from: updated[masteryKey]) ?? [:]
            let ids = Set(oldSchedules.keys).union(newSchedules.keys).union(oldMastery.keys).union(newMastery.keys)
            for id in ids where oldSchedules[id] != newSchedules[id] || oldMastery[id] != newMastery[id] {
                versions[scheduleKey, default: [:]][id] = timestamp
            }
        }
        for key in favoriteKeys {
            guard old[key] != updated[key] else { continue }
            let before = Set(decode([String].self, from: old[key]) ?? [])
            let after = Set(decode([String].self, from: updated[key]) ?? [])
            for id in before.symmetricDifference(after) {
                versions[key, default: [:]][id] = timestamp
            }
        }
        if appearanceKeys.contains(where: { old[$0] != updated[$0] }) {
            versions[StudyProgress.appearanceKey, default: [:]][appearanceVersionItem] = timestamp
        }
        if !versions.isEmpty { updated[itemVersionsKey] = encode(versions) }
    }

    static func merge(local: [String: Data], remote: [String: Data],
                      localUpdatedAt: Int64, remoteUpdatedAt: Int64) -> [String: Data] {
        var result: [String: Data] = [:]
        let localVersions = decode(ItemVersions.self, from: local[itemVersionsKey]) ?? [:]
        let remoteVersions = decode(ItemVersions.self, from: remote[itemVersionsKey]) ?? [:]
        let versions = localVersions.merging(remoteVersions) { a, b in a.merging(b, uniquingKeysWith: max) }
        var remaining = Set(local.keys).union(remote.keys)
        remaining.remove(itemVersionsKey)
        if !versions.isEmpty { result[itemVersionsKey] = encode(versions) }

        let localVersion = localVersions[StudyProgress.appearanceKey]?[appearanceVersionItem]
        let remoteVersion = remoteVersions[StudyProgress.appearanceKey]?[appearanceVersionItem]
        let localHasAppearance = localVersion != nil || local[StudyProgress.appearanceKey] != nil || local[StudyProgress.themeKey] != nil
        let remoteHasAppearance = remoteVersion != nil || remote[StudyProgress.appearanceKey] != nil || remote[StudyProgress.themeKey] != nil
        if localHasAppearance || remoteHasAppearance {
            let useRemote: Bool
            switch (localHasAppearance, remoteHasAppearance) {
            case (false, true): useRemote = true
            case (true, false): useRemote = false
            default:
                if localVersion != remoteVersion {
                    useRemote = (remoteVersion ?? -1) > (localVersion ?? -1)
                } else {
                    useRemote = remoteUpdatedAt > localUpdatedAt
                }
            }
            let appearance = useRemote ? remote : local
            // Legacy documents omit the override for manual themes. Keep that absence as part of the selection.
            for key in appearanceKeys {
                remaining.remove(key)
                result[key] = appearance[key]
            }
        }

        for (scheduleKey, masteryKey) in reviewKeys {
            remaining.remove(scheduleKey)
            remaining.remove(masteryKey)
            let localSchedules = decode([String: ReviewSchedule].self, from: local[scheduleKey]) ?? [:]
            let remoteSchedules = decode([String: ReviewSchedule].self, from: remote[scheduleKey]) ?? [:]
            let localMastery = decode([String: Mastery].self, from: local[masteryKey]) ?? [:]
            let remoteMastery = decode([String: Mastery].self, from: remote[masteryKey]) ?? [:]
            var schedules = localSchedules.merging(remoteSchedules) { a, b in
                preferRemoteSchedule(a, b, remotePreferOnTie: remoteUpdatedAt > localUpdatedAt) ? b : a
            }
            var mastery = localMastery.merging(remoteMastery) { a, b in masteryRank(b) > masteryRank(a) ? b : a }

            for id in Set(localSchedules.keys).intersection(remoteSchedules.keys) {
                if let a = localSchedules[id], let b = remoteSchedules[id],
                   let localLevel = localMastery[id], let remoteLevel = remoteMastery[id] {
                    mastery[id] = preferRemoteSchedule(a, b, remotePreferOnTie: remoteUpdatedAt > localUpdatedAt)
                        ? remoteLevel : localLevel
                }
            }
            for (id, _) in versions[scheduleKey] ?? [:] {
                let localVersion = localVersions[scheduleKey]?[id] ?? -1
                let remoteVersion = remoteVersions[scheduleKey]?[id] ?? -1
                let useRemote: Bool
                if localVersion != remoteVersion {
                    useRemote = remoteVersion > localVersion
                } else {
                    // Resolve edits made in the same millisecond consistently on both devices.
                    let a = reviewTieBreaker(localSchedules[id], localMastery[id])
                    let b = reviewTieBreaker(remoteSchedules[id], remoteMastery[id])
                    useRemote = a.lexicographicallyPrecedes(b)
                }
                schedules[id] = useRemote ? remoteSchedules[id] : localSchedules[id]
                mastery[id] = useRemote ? remoteMastery[id] : localMastery[id]
            }
            if local[scheduleKey] != nil || remote[scheduleKey] != nil || !schedules.isEmpty {
                result[scheduleKey] = encode(schedules)
            }
            if local[masteryKey] != nil || remote[masteryKey] != nil || !mastery.isEmpty {
                result[masteryKey] = encode(mastery)
            }
        }

        for key in favoriteKeys {
            remaining.remove(key)
            guard local[key] != nil || remote[key] != nil else { continue }
            let a = decode([String].self, from: local[key]) ?? []
            let b = decode([String].self, from: remote[key]) ?? []
            let localSet = Set(a)
            let remoteSet = Set(b)
            var seen = Set<String>()
            let merged = (a + b).filter { id in
                guard seen.insert(id).inserted else { return false }
                let localVersion = localVersions[key]?[id] ?? -1
                let remoteVersion = remoteVersions[key]?[id] ?? -1
                if localVersion > remoteVersion { return localSet.contains(id) }
                if remoteVersion > localVersion { return remoteSet.contains(id) }
                return localVersion < 0 || (localSet.contains(id) && remoteSet.contains(id))
            }
            result[key] = encode(merged)
        }

        for key in remaining {
            if let a = local[key], let b = remote[key] {
                result[key] = mergeEntry(key: key, local: a, remote: b,
                                         localUpdatedAt: localUpdatedAt, remoteUpdatedAt: remoteUpdatedAt)
            } else {
                result[key] = local[key] ?? remote[key]
            }
        }
        return result
    }

    private static func reviewTieBreaker(_ schedule: ReviewSchedule?, _ mastery: Mastery?) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return ((try? encoder.encode(schedule)) ?? Data()) + ((try? encoder.encode(mastery)) ?? Data())
    }

    static func canonicalEqual(_ lhs: [String: Data], _ rhs: [String: Data]) -> Bool {
        guard Set(lhs.keys) == Set(rhs.keys) else { return false }
        return lhs.keys.allSatisfy { key in
            guard let a = lhs[key], let b = rhs[key] else { return false }
            return canonicalJSON(a) == canonicalJSON(b)
        }
    }

    private static func mergeEntry(key: String, local lData: Data, remote rData: Data,
                                   localUpdatedAt: Int64, remoteUpdatedAt: Int64) -> Data {
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

    private static func preferRemoteSchedule(_ a: ReviewSchedule, _ b: ReviewSchedule, remotePreferOnTie: Bool) -> Bool {
        // Older documents have no per-item version. Infer when the schedule was set.
        let calendar = Calendar.current
        let aEdited = calendar.date(byAdding: .day, value: -a.intervalDays, to: a.reviewDate) ?? a.reviewDate
        let bEdited = calendar.date(byAdding: .day, value: -b.intervalDays, to: b.reviewDate) ?? b.reviewDate
        if aEdited != bEdited { return bEdited > aEdited }
        if a.repetitions != b.repetitions { return b.repetitions > a.repetitions }
        if a.lapses != b.lapses { return b.lapses > a.lapses }
        return remotePreferOnTie
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
    private var folderGeneration = 0

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
            folderGeneration += 1
            saveBookmark(bookmark, name: name)
            await sync(progress: progress, force: true)
        } catch {
            state = .failed("无法保存文件夹访问权限：\(error.localizedDescription)")
        }
    }

    func disconnect() {
        folderGeneration += 1
        bookmarkData = nil
        folderName = nil
        lastSummary = nil
        state = .unconfigured
        defaults.removeObject(forKey: Self.bookmarkKey)
        defaults.removeObject(forKey: Self.folderNameKey)
        defaults.removeObject(forKey: Self.lastSyncedAtKey)
    }

    func sync(progress: StudyProgress, now: Date = .now, force: Bool = false) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        while let initialBookmark = bookmarkData {
            let generation = folderGeneration
            state = .syncing
            do {
                let readResult = try await storage.read(bookmarkData: initialBookmark, fileName: Self.syncFileName)
                guard folderGeneration == generation else { continue }
                if let refreshed = readResult.refreshedBookmark {
                    saveBookmark(refreshed, name: folderName)
                }

                let activeBookmark = bookmarkData ?? initialBookmark
                let localRevision = progress.syncRevision
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
                    if localSnapshot.isEmpty {
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

                    progress.observeSyncTimestamp(mergedUpdatedAt)
                    if remoteChanged {
                        let payload = try progress.encodeSyncDocument(entries: merged, updatedAt: mergedUpdatedAt)
                        let refreshed = try await storage.write(payload, bookmarkData: activeBookmark, fileName: Self.syncFileName)
                        guard folderGeneration == generation else { continue }
                        if let refreshed {
                            saveBookmark(refreshed, name: folderName)
                        }
                    }

                    guard progress.syncRevision == localRevision else { continue }
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
                } else if !localSnapshot.isEmpty {
                    let timestamp = max(progress.localUpdatedAt, Int64(now.timeIntervalSince1970 * 1_000))
                    progress.observeSyncTimestamp(timestamp)
                    let payload = try progress.encodeSyncDocument(entries: localSnapshot, updatedAt: timestamp)
                    let refreshed = try await storage.write(payload, bookmarkData: activeBookmark, fileName: Self.syncFileName)
                    guard folderGeneration == generation else { continue }
                    if let refreshed {
                        saveBookmark(refreshed, name: folderName)
                    }
                    guard progress.syncRevision == localRevision else { continue }
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
                return
            } catch {
                guard folderGeneration == generation else { continue }
                state = .failed("同步失败：\(error.localizedDescription)")
                return
            }
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
