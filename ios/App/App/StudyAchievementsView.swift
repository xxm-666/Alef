import SwiftUI

struct StudyAchievementsView: View {
    @Environment(StudyProgress.self) private var progress

    var body: some View {
        let earned = progress.earnedAchievements
        let unlocked = StudyAchievement.allCases.filter(earned.contains)
        let locked = StudyAchievement.allCases.filter { !earned.contains($0) }
        let measured = currentProgress
        StudyPage {
            overview(unlocked: unlocked.count)
            if !unlocked.isEmpty {
                StudySectionTitle("已解锁")
                achievementList(unlocked, unlocked: true, measured: measured)
            }
            if !locked.isEmpty {
                StudySectionTitle("待解锁")
                achievementList(locked, unlocked: false, measured: measured)
            }
        }
        .studyDetail("学习成就")
    }

    private var currentProgress: StudyAchievementProgress {
        var measured = progress.achievementProgress
        measured.streakDays = progress.statistics.activeStreakDays()
        return measured
    }

    private func overview(unlocked: Int) -> some View {
        let total = StudyAchievement.allCases.count
        return StudyCard(spacing: 12) {
            HStack(spacing: 11) {
                StudyIconBadge(symbol: "trophy.fill", colors: progress.theme.warmGradient, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text("已解锁 \(unlocked) / \(total)")
                        .font(.headline)
                        .foregroundStyle(progress.theme.ink)
                        .accessibilityLabel("已解锁 \(unlocked) 项成就，共 \(total) 项")
                    if unlocked < total {
                        Text("达到学习目标后自动解锁")
                            .font(.subheadline)
                            .foregroundStyle(progress.theme.mutedInk)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            ProgressView(value: Double(unlocked), total: Double(total))
                .tint(progress.theme.accent)
                .accessibilityHidden(true)
        }
    }

    private func achievementList(_ achievements: [StudyAchievement], unlocked: Bool,
                                 measured: StudyAchievementProgress) -> some View {
        StudyCard(padding: 12, spacing: 0) {
            ForEach(achievements) { achievement in
                if achievement != achievements.first { Divider() }
                achievementRow(achievement, unlocked: unlocked, value: measured.value(for: achievement))
            }
        }
    }

    private func achievementRow(_ achievement: StudyAchievement, unlocked: Bool, value: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if unlocked {
                StudyIconBadge(symbol: achievement.symbol, colors: progress.theme.heroGradient, size: 36)
            } else {
                Image(systemName: "lock")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.mutedInk)
                    .frame(width: 36, height: 36)
                    .background(progress.theme.highlightedSurface, in: RoundedRectangle(cornerRadius: 11))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(progress.theme.ink)
                Text(achievement.requirement)
                    .font(.caption)
                    .foregroundStyle(progress.theme.mutedInk)
                if !unlocked {
                    Text("进度 \(min(value, achievement.goal)) / \(achievement.goal)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(progress.theme.mutedInk)
                }
            }
            Spacer(minLength: 0)
            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(progress.theme.success)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private extension StudyAchievement {
    var title: String {
        switch self {
        case .firstPractice: "学习起步"
        case .tenLetters: "字母入门"
        case .alphabet: "字母全通"
        case .firstVocabularyGroup: "第一组记词"
        case .twentyWords: "词汇起步"
        case .fiftyWords: "词汇进阶"
        case .threeDays: "三日坚持"
        case .sevenDays: "一周坚持"
        }
    }

    var requirement: String {
        switch self {
        case .firstPractice: "记录第一次学习"
        case .tenLetters, .alphabet: "掌握 \(goal) 个字母"
        case .firstVocabularyGroup: "完成一组「今日记词」的认读和拼写"
        case .twentyWords, .fiftyWords: "掌握 \(goal) 个单词"
        case .threeDays, .sevenDays: "连续学习 \(goal) 天"
        }
    }

    var symbol: String {
        switch self {
        case .firstPractice: "sparkles"
        case .tenLetters, .alphabet: "character.book.closed.fill"
        case .firstVocabularyGroup: "pencil"
        case .twentyWords, .fiftyWords: "text.book.closed.fill"
        case .threeDays, .sevenDays: "flame.fill"
        }
    }
}
