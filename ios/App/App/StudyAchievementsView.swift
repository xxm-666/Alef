import SwiftUI

struct StudyAchievementsView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var requirementHeight: CGFloat = 32

    var body: some View {
        let earned = progress.earnedAchievements
        let unlocked = StudyAchievement.allCases.filter(earned.contains)
        let locked = StudyAchievement.allCases.filter { !earned.contains($0) }
        let measured = currentProgress
        StudyPage {
            overview(unlocked: unlocked.count, bestCombo: measured.bestAnswerCombo)
            if !unlocked.isEmpty {
                StudySectionTitle("已解锁")
                achievementGrid(unlocked, unlocked: true, measured: measured)
            }
            if !locked.isEmpty {
                StudySectionTitle("待解锁")
                achievementGrid(locked, unlocked: false, measured: measured)
            }
        }
        .studyDetail("学习成就")
    }

    private var currentProgress: StudyAchievementProgress {
        var measured = progress.achievementProgress
        measured.streakDays = progress.statistics.activeStreakDays()
        return measured
    }

    private func overview(unlocked: Int, bestCombo: Int) -> some View {
        let total = StudyAchievement.allCases.count
        let theme = progress.theme
        return StudyHeroCard(colors: [theme.primaryButton, theme.heroGradient.first ?? theme.primaryButton],
                             padding: 18, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 54, height: 54)
                    .background(Color.white.opacity(0.17), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("已解锁成就")
                        .font(.subheadline.weight(.semibold))
                    Text("\(unlocked) / \(total)")
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("已解锁 \(unlocked) 项成就，共 \(total) 项")
            ProgressView(value: Double(unlocked), total: Double(total))
                .tint(.white)
                .accessibilityHidden(true)
            if bestCombo > 0 {
                Label("最高 \(bestCombo) 连击", systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .accessibilityLabel("最高答题连击 \(bestCombo) 题")
            }
        }
    }

    private func achievementGrid(_ achievements: [StudyAchievement], unlocked: Bool,
                                 measured: StudyAchievementProgress) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                            count: typeSize.isAccessibilitySize ? 1 : 2)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(achievements) { achievement in
                achievementCard(achievement, unlocked: unlocked, value: measured.value(for: achievement))
            }
        }
    }

    private func achievementCard(_ achievement: StudyAchievement, unlocked: Bool, value: Int) -> some View {
        let theme = progress.theme
        let color = unlocked ? achievement.color(in: theme) : theme.mutedInk
        let current = min(max(0, value), achievement.goal)
        return StudyCard(spacing: 10) {
            HStack(alignment: .top) {
                Image(systemName: achievement.symbol)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 52, height: 52)
                    .background(unlocked ? color.opacity(0.15) : theme.insetSurface, in: Circle())
                    .overlay {
                        Circle().strokeBorder(color.opacity(unlocked ? 0.32 : 0.15), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
                Spacer(minLength: 4)
                Image(systemName: unlocked ? "checkmark.seal.fill" : "lock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(achievement.requirement)
                    .font(.caption)
                    .foregroundStyle(theme.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: typeSize.isAccessibilitySize ? nil : requirementHeight, alignment: .topLeading)
            }
            if !unlocked {
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(current) / \(achievement.goal)")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(theme.mutedInk)
                    ProgressView(value: Double(current), total: Double(achievement.goal))
                        .tint(theme.accent)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(achievement.title)，\(achievement.requirement)")
        .accessibilityValue(Text(unlocked ? "已解锁" : "待解锁，进度 \(current) / \(achievement.goal)"))
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
        case .comboThree: "三连击"
        case .comboFive: "五连击"
        case .comboTen: "十连击"
        }
    }

    var requirement: String {
        switch self {
        case .firstPractice: "记录第一次学习"
        case .tenLetters, .alphabet: "掌握 \(goal) 个字母"
        case .firstVocabularyGroup: "完成一组「今日记词」"
        case .twentyWords, .fiftyWords: "掌握 \(goal) 个单词"
        case .threeDays, .sevenDays: "连续学习 \(goal) 天"
        case .comboThree, .comboFive, .comboTen: "单轮连续答对 \(goal) 题"
        }
    }

    var symbol: String {
        switch self {
        case .firstPractice: "sparkles"
        case .tenLetters: "character.book.closed.fill"
        case .alphabet: "graduationcap.fill"
        case .firstVocabularyGroup: "pencil"
        case .twentyWords: "text.book.closed.fill"
        case .fiftyWords: "books.vertical.fill"
        case .threeDays: "flame.fill"
        case .sevenDays: "calendar.badge.checkmark"
        case .comboThree: "hand.thumbsup.fill"
        case .comboFive: "bolt.fill"
        case .comboTen: "trophy.fill"
        }
    }

    func color(in theme: StudyTheme) -> Color {
        switch self {
        case .firstPractice, .tenLetters, .alphabet: theme.accent
        case .firstVocabularyGroup, .twentyWords, .fiftyWords: theme.success
        case .threeDays, .sevenDays: theme.reminder
        case .comboThree, .comboFive, .comboTen: theme.accent
        }
    }
}
