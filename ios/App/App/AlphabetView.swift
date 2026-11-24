import PencilKit
import SwiftUI

struct AlphabetView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    @State private var scope = "all"
    @State private var showsDisplay = false
    @State private var quickActions = false

    var body: some View {
        let options = content.letterDisplay(in: progress)
        let mastery = progress.letterMastery
        let letters = content.letters.filter { scope == "all" || mastery[$0.id] != .mastered }
        let masteredCount = content.letters.filter { mastery[$0.id] == .mastered }.count
        let streakDays = progress.statistics.activeStreakDays()
        let focusedLetter = continueLetter
        StudyPage(maxWidth: LetterGridLayout.maximumWidth) {
            HStack(alignment: .bottom) {
                StudyHeading(title: "认识希伯来字母", eyebrow: "ALEF · 22 字母")
                if streakDays > 0 {
                    Label("\(streakDays) 天", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(progress.theme.reminder)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(progress.theme.reminderSurface, in: Capsule())
                        .accessibilityLabel("连续学习 \(streakDays) 天")
                }
            }
            StudyHeroCard {
                HStack(spacing: 14) {
                    StudyProgressRing(value: Double(masteredCount), total: Double(max(1, content.letters.count)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("字母掌握进度")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.82))
                        Text("已掌握 \(masteredCount) / \(content.letters.count)")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                    if let next = focusedLetter {
                        Text(next.hebrew)
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(Color.white)
                            .frame(width: 52, height: 52)
                            .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                            }
                            .accessibilityHidden(true)
                    }
                }
                if let next = focusedLetter {
                    NavigationLink {
                        LetterStudyView(letter: next, content: content)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.body.weight(.semibold))
                            Text("继续学习 \(next.nameEnglish) · \(next.nameChinese)")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .opacity(0.85)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Color.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.26), lineWidth: 1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            controls
            if letters.isEmpty {
                ContentUnavailableView("没有需复习的字母", systemImage: "checkmark.circle",
                                       description: Text("切换到「全部」可以继续浏览字母表。"))
            } else {
                LazyVGrid(columns: LetterGridLayout.columns(options: options, typeSize: typeSize, quickActions: quickActions),
                          spacing: LetterGridLayout.spacing) {
                    ForEach(letters) { letter in
                        letterTile(letter, options: options, mastery: mastery[letter.id] ?? .unlearned,
                                   isFocused: letter.id == focusedLetter?.id)
                    }
                }
                .environment(\.layoutDirection, progress.alphabetFromRight ? .rightToLeft : .leftToRight)
            }

            LearningPathEntry(content: content, highlighted: false)
            NavigationLink {
                StudySofitView(content: content)
            } label: {
                StudyCard(padding: 12) {
                    StudyRow(title: "词尾变形", symbol: "textformat.abc", subtitle: "普通形与词尾形对照", value: "5 组",
                             badgeColors: progress.theme.indigoGradient)
                }
            }
            .buttonStyle(.plain)
        }
        .studyHome()
        .sheet(isPresented: $showsDisplay) {
            NavigationStack { StudyLetterDisplayView(content: content) }
                .presentationDragIndicator(.visible)
        }
    }

    private var continueLetter: StudyLetter? {
        let last = progress.read("alef.selectedLetterId.v1", default: "")
        return content.letters.first { $0.id == last }
            ?? content.letters.first { progress.letterMastery[$0.id] != .mastered }
            ?? content.letters.first
    }

    private var controls: some View {
        let directionButton = Button {
            progress.alphabetFromRight.toggle()
        } label: {
            Label(progress.alphabetFromRight ? "RTL" : "LTR", systemImage: "arrow.left.arrow.right")
        }
        .buttonStyle(StudyButtonStyle())
        .accessibilityLabel(progress.alphabetFromRight ? "当前从右向左排列，点按改为从左向右" : "当前从左向右排列，点按改为从右向左")

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                StudySegments(title: "字母范围", options: [("all", "全部"), ("review", "需复习")], selection: $scope)
                    .frame(maxWidth: 180)
                Spacer(minLength: 0)
                directionButton
                displayButton
            }
            VStack(alignment: .leading, spacing: 8) {
                StudySegments(title: "字母范围", options: [("all", "全部"), ("review", "需复习")], selection: $scope)
                HStack(spacing: 6) {
                    directionButton
                    displayButton
                }
            }
        }
    }

    private var displayButton: some View {
        Menu {
            Button("定制字母卡片", systemImage: "slider.horizontal.3") { showsDisplay = true }
            Toggle("快速操作", isOn: $quickActions)
            Button(progress.alphabetFromRight ? "改为从左向右排列" : "改为从右向左排列",
                   systemImage: "arrow.left.arrow.right") {
                progress.alphabetFromRight.toggle()
            }
        } label: {
            Label("显示项", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(StudyButtonStyle())
    }

    private func letterTile(_ letter: StudyLetter, options: [String: Bool], mastery: Mastery, isFocused: Bool) -> some View {
        StudyCard(highlighted: isFocused, padding: 0) {
            NavigationLink {
                LetterStudyView(letter: letter, content: content)
            } label: {
                VStack(spacing: 6) {
                    LetterTileContent(letter: letter, options: options)
                    if options["showMastery"] == true && !quickActions {
                        Image(systemName: mastery.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(masteryColor(mastery))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(masteryBadgeSurface(mastery), in: Capsule())
                            .accessibilityLabel(mastery.title)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 74)
                .padding(7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("打开字母详情")
            if quickActions {
                HStack(spacing: 0) {
                    PronunciationButton(hebrew: letter.nameHebrew, iconOnly: true,
                                        title: "朗读\(letter.nameChinese)")
                    Spacer(minLength: 0)
                    Menu {
                        ForEach(Mastery.allCases) { level in
                            Button(level.title, systemImage: level == mastery ? "checkmark" : level.symbol) {
                                if level != mastery { progress.setLetter(letter.id, mastery: level) }
                            }
                        }
                    } label: {
                        Image(systemName: mastery.symbol)
                            .foregroundStyle(masteryColor(mastery))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("\(letter.nameChinese)的掌握度")
                    .accessibilityValue(mastery.title)
                }
            }
        }
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(progress.theme.accent.opacity(0.65), lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    private func masteryColor(_ mastery: Mastery) -> Color {
        switch mastery {
        case .mastered: progress.theme.success
        case .learning: progress.theme.learningAction
        case .unlearned: progress.theme.mutedInk
        }
    }

    private func masteryBadgeSurface(_ mastery: Mastery) -> Color {
        switch mastery {
        case .mastered: progress.theme.successSurface
        case .learning: progress.theme.highlightedSurface
        case .unlearned: progress.theme.insetSurface
        }
    }

}

enum LetterGridLayout {
    static let spacing: CGFloat = 8
    static let maximumWidth: CGFloat = 740

    static func columns(options: [String: Bool], typeSize: DynamicTypeSize, quickActions: Bool = false) -> [GridItem] {
        if typeSize.isAccessibilitySize { return [GridItem(.flexible(), alignment: .top)] }
        let minimum: CGFloat
        if LetterTileContent.isDetailed(options) { minimum = typeSize >= .xxLarge ? 180 : 130 }
        else if quickActions || typeSize >= .xxLarge { minimum = 102 }
        else { minimum = 76 }
        return [GridItem(.adaptive(minimum: minimum), spacing: spacing, alignment: .top)]
    }
}

struct LetterTileContent: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric private var glyphHeight: CGFloat = 37
    let letter: StudyLetter
    let options: [String: Bool]

    static func isDetailed(_ options: [String: Bool]) -> Bool {
        options["showBiblicalDiff"] == true || options["showCategoryBadges"] == true
            || (options["showBlock"] == true && options["showCursive"] == true)
    }

    var body: some View {
        VStack(spacing: 4) {
            if options["showBlock"] == true || options["showCursive"] == true {
                let showBoth = options["showBlock"] == true && options["showCursive"] == true
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if options["showBlock"] == true { glyph(cursive: false, labeled: showBoth) }
                    if options["showCursive"] == true { glyph(cursive: true, labeled: showBoth) }
                    if isCompact, options["showSofit"] == true, let sofit = letter.sofit {
                        Group {
                            if options["showBlock"] == true {
                                HebrewText(text: sofit, size: 17)
                            } else {
                                StudyCursiveLetter(letter: letter, finalForm: true, size: 17)
                            }
                        }
                        .foregroundStyle(progress.theme.mutedInk)
                        .accessibilityLabel("词尾形 \(sofit)")
                    }
                }
                .frame(minHeight: glyphHeight)
            }
            if options["showChineseName"] == true { cardLine(Text(letter.nameChinese).font(.subheadline.weight(.semibold))) }
            if options["showEnglishName"] == true { cardLine(Text(isCompact ? letter.studyName : letter.nameEnglish).font(.caption).foregroundColor(.secondary)) }
            if options["showHebrewName"] == true {
                cardLine(Text(letter.nameHebrew).font(.caption))
            }
            if options["showModernSound"] == true || options["showTransliteration"] == true {
                let sounds = [options["showModernSound"] == true ? letter.modernIpa : nil,
                              options["showTransliteration"] == true ? letter.transliteration : nil].compactMap { $0 }
                cardLine(Text(sounds.joined(separator: " · ")).font(.caption2).foregroundColor(.secondary), lines: 2)
            }
            if options["showBiblicalDiff"] == true {
                cardLine(Text(letter.biblicalIpa).font(.caption2).foregroundColor(.secondary), lines: 2)
            }
            if options["showSofit"] == true || options["showBegadkefat"] == true || options["showGematria"] == true {
                let detail = annotations(letter, options: options)
                if !detail.isEmpty {
                    cardLine(Text(detail).font(.caption2).foregroundColor(.secondary), lines: 2)
                }
            }
            if options["showCategoryBadges"] == true {
                let tags = [("sofit", "词尾变形"), ("begadkefat", "达盖什"), ("guttural", "喉音字母")]
                    .filter { letter.categories.contains($0.0) }.map(\.1)
                cardLine(Text(tags.isEmpty ? " " : tags.joined(separator: " · ")).font(.caption2), lines: 2)
            }
        }
        .foregroundStyle(.primary)
    }

    private var isCompact: Bool { !Self.isDetailed(options) }

    private func glyph(cursive: Bool, labeled: Bool) -> some View {
        VStack(spacing: 2) {
            if cursive {
                StudyCursiveLetter(letter: letter, size: 30)
            } else {
                HebrewText(text: letter.hebrew, size: 35)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            if labeled {
                Text(cursive ? "手写" : "印刷")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    @ViewBuilder private func cardLine(_ text: Text, lines: Int = 1) -> some View {
        if typeSize.isAccessibilitySize {
            text.fixedSize(horizontal: false, vertical: true)
        } else {
            text.lineLimit(Self.isDetailed(options) ? max(2, lines) : lines, reservesSpace: true)
                .minimumScaleFactor(0.82)
        }
    }

    private func annotations(_ letter: StudyLetter, options: [String: Bool]) -> String {
        var details: [String] = []
        if !isCompact, options["showSofit"] == true, let sofit = letter.sofit { details.append("末 \(sofit)") }
        if options["showBegadkefat"] == true, let variants = letter.begadkefat {
            details.append("\(variants.withDagesh.glyph)/\(variants.withoutDagesh.glyph)")
        }
        if options["showGematria"] == true {
            details.append(String(letter.gematria))
        }
        return details.joined(separator: " · ")
    }
}

struct LetterStudyView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent
    private let showsFinalForm: Bool
    @State private var letter: StudyLetter
    @State private var classical = false

    init(letter: StudyLetter, content: StudyContent, showsFinalForm: Bool = false) {
        self.content = content
        self.showsFinalForm = showsFinalForm
        _letter = State(initialValue: letter)
    }

    private var displayGlyph: String {
        (showsFinalForm ? letter.sofitInfo?.finalGlyph : nil) ?? letter.hebrew
    }

    private var activeLetters: [StudyLetter] {
        showsFinalForm ? content.letters.filter { $0.sofitInfo != nil } : content.letters
    }

    private var letterPositionLabel: String {
        let list = activeLetters
        guard let idx = list.firstIndex(where: { $0.id == letter.id }) else { return "" }
        return "\(idx + 1) / \(list.count)"
    }

    var body: some View {
        StudyPage {
            letterHeader
            NavigationLink {
                LetterWritingView(guide: letter.strokeGuide, startsWithFinalForm: showsFinalForm)
            } label: {
                StudyCard(padding: 12) {
                    StudyRow(title: "笔顺与手写练习", symbol: "pencil.and.outline",
                             subtitle: "分步矢量笔顺动画与描红", badgeColors: progress.theme.indigoGradient)
                }
            }
            .buttonStyle(.plain)
            MasteryPicker(value: Binding(get: { progress.letterMastery[letter.id] ?? .unlearned }, set: {
                if (progress.letterMastery[letter.id] ?? .unlearned) != $0 { progress.setLetter(letter.id, mastery: $0) }
            }))
            if let schedule = progress.letterSchedule[letter.id] {
                StudyNotice(title: "下次复习 · \(schedule.displayDate)", symbol: "calendar",
                            note: "当前间隔 \(schedule.intervalLabel)",
                            reminder: schedule.isDue)
            }
            if let variants = letter.begadkefat { soundComparison(variants) }
            if showsFinalForm, let form = letter.sofitInfo { finalFormDetails(form) }
            if let example = letter.examples.first {
                StudySectionTitle("代表词")
                StudyCard {
                    WordExampleRow(example: example)
                    if letter.examples.count > 1 {
                        DisclosureGroup("更多例词") {
                            ForEach(Array(letter.examples.dropFirst().enumerated()), id: \.offset) { _, example in
                                WordExampleRow(example: example)
                            }
                        }
                    }
                }
            }
            StudyCard {
                DisclosureGroup("现代与古典读音") {
                    LabeledContent("现代希伯来语", value: letter.modernIpa)
                    Text(letter.pronunciationDesc)
                    LabeledContent("古典希伯来语", value: letter.biblicalIpa)
                    Text(letter.biblicalDiff).foregroundStyle(progress.theme.mutedInk)
                }
            }
            if !showsFinalForm, let form = letter.sofitInfo { finalFormDetails(form) }
            StudyCard {
                DisclosureGroup("字源与数值") {
                    LabeledContent("标准 Gematria", value: String(letter.gematria))
                    Text(letter.meaning)
                    Text(letter.etymology)
                    Text(letter.cursiveDesc).foregroundStyle(progress.theme.mutedInk)
                }
            }
            if !letter.confusableWith.isEmpty {
                StudyCard {
                    DisclosureGroup("易混字母") {
                        ForEach(content.letters.filter { letter.confusableWith.contains($0.id) }) { other in
                            NavigationLink {
                                LetterStudyView(letter: other, content: content)
                            } label: {
                                StudyRow(title: "\(other.hebrew) · \(other.nameChinese)", symbol: "arrow.left.arrow.right")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .id(letter.id)
        .studyDetail("\(displayGlyph) · \(letter.studyName)")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    move(progress.alphabetFromRight ? 1 : -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .accessibilityLabel(progress.alphabetFromRight ? "下一个字母" : "上一个字母")

                Button {
                    move(progress.alphabetFromRight ? -1 : 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .accessibilityLabel(progress.alphabetFromRight ? "上一个字母" : "下一个字母")

                StudyMemoryCurveEntry(schedule: progress.letterSchedule[letter.id], item: .letter)
            }
        }
        .onChange(of: letter.id, initial: true) { _, id in progress.write(id, for: "alef.selectedLetterId.v1") }
    }

    private var letterHeader: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return StudyCard {
            HStack(spacing: 14) {
                Text(displayGlyph)
                    .font(.system(size: 56, weight: .bold, design: .serif))
                    .foregroundStyle(Color.white)
                    .frame(width: 82, height: 82)
                    .background(
                        LinearGradient(colors: progress.theme.heroGradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                    )
                    .environment(\.layoutDirection, .rightToLeft)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(letter.studyName).font(.title2.bold())
                        Text(letter.nameHebrew)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(progress.theme.mutedInk)
                        Spacer(minLength: 4)
                        if !letterPositionLabel.isEmpty {
                            Text(letterPositionLabel)
                                .font(.caption2.weight(.bold).monospacedDigit())
                                .foregroundStyle(progress.theme.mutedInk)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(progress.theme.insetSurface, in: Capsule())
                        }
                    }
                    Text(letter.nameChinese).font(.headline)
                    Text("现代读音 \(letter.modernIpa)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(progress.theme.accent)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(progress.theme.ink)
            layout {
                letterForm(cursive: false)
                letterForm(cursive: true)
            }
            layout {
                PronunciationButton(hebrew: letter.nameHebrew,
                                    title: "朗读字母名", prominent: true)
                PronunciationButton(hebrew: letter.nameHebrew,
                                    rate: 0.68, title: "慢速字母名")
            }
        }
    }

    private func letterForm(cursive: Bool) -> some View {
        VStack(spacing: 2) {
            Text(cursive ? "手写体" : "印刷体").font(.caption).foregroundStyle(progress.theme.mutedInk)
            if cursive {
                StudyCursiveLetter(letter: letter, finalForm: showsFinalForm, size: 39)
            } else {
                HebrewText(text: displayGlyph, size: 39, style: .title)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func soundComparison(_ variants: StudyDagesh) -> some View {
        StudyCard {
            StudySectionTitle("达盖什发音对照")
            StudySegments(title: "发音体系", options: [(false, "现代希伯来语"), (true, "古典希伯来语")],
                          selection: $classical)
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                soundVariant(variants.withDagesh, title: "带达盖什", variants: variants)
                soundVariant(variants.withoutDagesh, title: "不带达盖什", variants: variants)
            }
            Text(variants.note).font(.footnote).foregroundStyle(progress.theme.mutedInk)
            NavigationLink {
                StudyRulesView(content: content, topic: "begadkefat")
            } label: {
                StudyRow(title: "查看达盖什规则", symbol: "book")
            }
            .buttonStyle(.plain)
        }
    }

    private func soundVariant(_ variant: StudyDagesh.Variant, title: String, variants: StudyDagesh) -> some View {
        VStack(spacing: 5) {
            HebrewText(text: variant.glyph, size: 35)
            Text(classical ? variant.biblicalIpa : variant.modernIpa).font(.headline)
            Text(title).font(.caption).foregroundStyle(progress.theme.mutedInk)
            if !classical {
                let sample = variants.modernExample(for: variant)
                PronunciationButton(hebrew: sample, title: "听音节 \(sample)", bundledOnly: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private func finalFormDetails(_ form: StudySofit) -> some View {
        StudyCard {
            StudySectionTitle("词尾形 · Sofit")
            HStack(spacing: 16) {
                letterForms("普通形", glyph: form.medialGlyph)
                Image(systemName: "arrow.right").accessibilityHidden(true)
                letterForms("词尾形", glyph: form.finalGlyph)
            }
            .frame(maxWidth: .infinity)
            LabeledContent("标准数值", value: String(letter.gematria))
            LabeledContent("词尾扩展数值", value: String(form.sofitGematria))
            Text(form.rule).font(.subheadline)
            WordExampleRow(example: form.exampleWord)
        }
    }

    private func letterForms(_ title: String, glyph: String) -> some View {
        VStack(spacing: 4) {
            HebrewText(text: glyph, size: 36)
            Text(title).font(.caption).foregroundStyle(progress.theme.mutedInk)
        }
    }

    private func move(_ offset: Int) {
        let letters = showsFinalForm ? content.letters.filter { $0.sofitInfo != nil } : content.letters
        guard let index = letters.firstIndex(where: { $0.id == letter.id }), !letters.isEmpty else { return }
        letter = letters[(index + offset + letters.count) % letters.count]
        classical = false
    }
}

struct StudySofitView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent

    private var letters: [StudyLetter] { content.letters.filter { $0.sofitInfo != nil } }

    var body: some View {
        StudyPage {
            Text("同一个字母，词尾换个样子").font(.headline).foregroundStyle(progress.theme.ink)
            ForEach(letters) { letter in
                if let form = letter.sofitInfo {
                    StudyCard(padding: 8) {
                        HStack {
                            NavigationLink {
                                LetterStudyView(letter: letter, content: content, showsFinalForm: true)
                            } label: {
                                HStack(spacing: 10) {
                                    HebrewText(text: form.medialGlyph, size: 30)
                                    Image(systemName: "arrow.right").font(.caption).accessibilityHidden(true)
                                    HebrewText(text: form.finalGlyph, size: 30)
                                    StudyRow(title: letter.studyName, symbol: "textformat", subtitle: letter.modernIpa)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(letter.nameChinese)，\(form.medialGlyph) 的词尾形是 \(form.finalGlyph)")
                            PronunciationButton(hebrew: form.exampleWord.hebrew,
                                                iconOnly: true, title: "朗读\(letter.studyName)的词尾例词")
                        }
                    }
                }
            }
            StudyNotice(title: "只在单词末尾使用", symbol: "info.circle",
                        note: "五个字母位于单词末尾时换用词尾形。记忆口诀：כמנפ״ץ（Kamnapetz）。")
            if let example = letters.first?.sofitInfo?.exampleWord {
                StudySectionTitle("例词")
                StudyCard { WordExampleRow(example: example) }
            }
            StudyCard {
                DisclosureGroup("标准数值与扩展数值") {
                    ForEach(letters) { letter in
                        if let form = letter.sofitInfo {
                            LabeledContent("\(letter.studyName) · \(form.finalGlyph)",
                                           value: "标准 \(letter.gematria) / 扩展 \(form.sofitGematria)")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .studyDetail("词尾变形")
    }
}

struct WordExampleRow: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let example: StudyExample
    var showNiqqud = true
    var cursive = false
    var bundledOnly = false

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 5)) : AnyLayout(HStackLayout(spacing: 10))
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                layout {
                    HebrewText(text: showNiqqud ? example.hebrew : withoutHebrewMarks(example.hebrew), cursive: cursive, size: 29)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.transliteration).font(.subheadline.weight(.medium)).foregroundStyle(progress.theme.ink)
                        Text(example.meaning).font(.subheadline).foregroundStyle(progress.theme.mutedInk)
                    }
                }
                Spacer(minLength: 0)
                PronunciationButton(hebrew: example.hebrew, iconOnly: true,
                                    title: "播放例词或例句", bundledOnly: bundledOnly)
            }
            if let note = example.note {
                Text(note).font(.footnote).foregroundStyle(progress.theme.mutedInk)
            }
        }
    }
}

struct StudyCursiveLetter: View {
    @Environment(StudyProgress.self) private var progress
    @ScaledMetric private var scale: CGFloat = 1
    let letter: StudyLetter
    var finalForm = false
    let size: CGFloat

    var body: some View {
        let guide = letter.strokeGuide
        let strokes = finalForm ? (guide.sofitCursiveStrokes ?? guide.cursiveStrokes) : guide.cursiveStrokes
        let side = size * scale * 1.25
        Canvas { context, canvas in
            let unit = canvas.width / 100
            let transform = CGAffineTransform(scaleX: unit, y: unit)
            let line = StrokeStyle(lineWidth: 5.5 * unit, lineCap: .round, lineJoin: .round)
            for stroke in strokes {
                context.stroke(stroke.path.applying(transform), with: .color(progress.theme.ink), style: line)
            }
        }
        .frame(width: side, height: side)
        .alignmentGuide(.firstTextBaseline) { $0.height * 0.78 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(finalForm ? (letter.sofit ?? letter.hebrew) : letter.hebrew)
    }
}

private struct LetterWritingView: View {
    @Environment(StudyProgress.self) private var progress
    @EnvironmentObject private var audio: StudyAudio
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var widthClass
    let guide: StudyStrokes
    @State private var shape: String
    @State private var markedGlyph = ""
    @State private var practiceID = UUID()
    @State private var showTracing = true
    @State private var showsDemonstration = false
    @State private var selectedStroke: Int?
    @State private var animationStart: Date?

    private let secondsPerStroke = 1.15

    init(guide: StudyStrokes, startsWithFinalForm: Bool) {
        self.guide = guide
        let initialShape: String
        if startsWithFinalForm, guide.sofitCursiveSteps != nil {
            initialShape = "sofit-cursive"
        } else if startsWithFinalForm, guide.sofitBlockSteps != nil {
            initialShape = "sofit-block"
        } else {
            initialShape = "cursive"
        }
        _shape = State(initialValue: initialShape)
    }

    var body: some View {
        ScrollViewReader { scroll in
            StudyPage(maxWidth: 760) {
                StudySegments(title: "字形", options: shapes, selection: $shape)
                if shape == "cursive", guide.cursiveMarks != nil {
                    StudySegments(title: "手写字母加点", options: markOptions, selection: $markedGlyph)
                }

                if sideBySide {
                    HStack(alignment: .top, spacing: 12) {
                        StudyCard {
                            StudySectionTitle("笔顺演示")
                            demonstration
                        }
                        .id("stroke-demo")
                        StudyCard { practice }
                    }
                } else {
                    StudyCard {
                        DisclosureGroup("笔顺演示", isExpanded: $showsDemonstration) {
                            demonstration.padding(.top, 8)
                        }
                        .frame(minHeight: 44)
                    }
                    .id("stroke-demo")
                    StudyCard { practice }
                }
                if !selectedSteps.isEmpty {
                    StudyCard { strokeSteps }
                }
            }
            .onChange(of: selectedStroke) { _, index in
                if index != nil && !sideBySide {
                    showsDemonstration = true
                    scroll.scrollTo("stroke-demo", anchor: .top)
                }
            }
        }
        .studyDetail("笔顺与手写")
        .onChange(of: showsDemonstration) { _, expanded in
            if !expanded { animationStart = nil }
        }
        .onChange(of: shape) { _, _ in resetPractice() }
        .onChange(of: markedGlyph) { _, _ in resetPractice() }
        .task(id: animationStart) {
            guard let started = animationStart else { return }
            do {
                try await Task.sleep(for: .seconds(secondsPerStroke * Double(selectedStrokes.count)))
                if animationStart == started { animationStart = nil }
            } catch {
                // A replay, a selection change, or leaving the view cancels the current animation.
            }
        }
    }

    private var sideBySide: Bool { widthClass == .regular && !typeSize.isAccessibilitySize }

    private func resetPractice() {
        animationStart = nil
        selectedStroke = nil
        practiceID = UUID()
    }

    @ViewBuilder private var strokeSteps: some View {
        if !selectedSteps.isEmpty {
            DisclosureGroup("查看 \(selectedSteps.count) 个笔画步骤") {
                ForEach(Array(selectedSteps.enumerated()), id: \.offset) { index, step in
                    Button {
                        animationStart = nil
                        selectedStroke = selectedStroke == index ? nil : index
                    } label: {
                        HStack {
                            Text("\(index + 1). \(step)").foregroundStyle(.primary)
                            Spacer()
                            if selectedStroke == index { Image(systemName: "checkmark.circle.fill") }
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(selectedStroke == index ? .isSelected : [])
                }
            }
        }
    }

    private var shapes: [(value: String, title: String)] {
        var options = [("block", "印刷"), ("cursive", "手写")]
        if guide.sofitBlockSteps != nil { options.append(("sofit-block", "词尾印刷")) }
        if guide.sofitCursiveSteps != nil { options.append(("sofit-cursive", "词尾手写")) }
        return options
    }

    private var demonstration: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30, paused: animationStart == nil)) { timeline in
                let position = animationStart.map { max(0, timeline.date.timeIntervalSince($0) / secondsPerStroke) }
                StrokeDiagram(strokes: selectedStrokes, selectedStroke: selectedStroke, progress: position, reduceMotion: reduceMotion)
            }
            .frame(height: sideBySide ? 224 : 144)
            .frame(maxWidth: .infinity)
            .background(progress.theme.insetSurface, in: RoundedRectangle(cornerRadius: 12))
            Button {
                selectedStroke = nil
                animationStart = .now
            } label: {
                Label(animationStart == nil ? "播放笔顺" : "重播笔顺",
                      systemImage: animationStart == nil ? "play" : "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(StudyButtonStyle())
            .disabled(selectedStrokes.isEmpty)
        }
    }

    private var practice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手写练习").font(.headline)
            HStack(spacing: 12) {
                Toggle("描红", isOn: $showTracing).frame(minHeight: 44)
                Button {
                    audio.playStrokeHaptic()
                    practiceID = UUID()
                } label: {
                    Image(systemName: "eraser").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("清空练习")
            }
            Rectangle()
                .fill(progress.theme.insetSurface)
                .aspectRatio(1.2, contentMode: .fit)
                .frame(maxHeight: 320)
                .overlay {
                    StrokeDiagram(strokes: showTracing ? selectedStrokes : [], tracing: true)
                        .accessibilityHidden(true)
                    DrawingPad { audio.playStrokeHaptic() }
                        .id(practiceID)
                        .accessibilityLabel("手写练习区")
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var selectedSteps: [String] {
        switch shape {
        case "cursive": guide.cursiveSteps + (selectedMark.map { [$0.step] } ?? [])
        case "sofit-block": guide.sofitBlockSteps ?? []
        case "sofit-cursive": guide.sofitCursiveSteps ?? []
        default: guide.blockSteps
        }
    }

    private var selectedStrokes: [StudyStrokes.Stroke] {
        switch shape {
        case "cursive": guide.cursiveStrokes + (selectedMark.map { [$0.stroke] } ?? [])
        case "sofit-block": guide.sofitBlockStrokes ?? []
        case "sofit-cursive": guide.sofitCursiveStrokes ?? []
        default: guide.blockStrokes
        }
    }

    private var selectedMark: StudyStrokes.CursiveMark? {
        guide.cursiveMarks?.first { $0.glyph == markedGlyph }
    }

    private var markOptions: [(value: String, title: String)] {
        [("", "无点")] + (guide.cursiveMarks ?? []).map { mark in
            (mark.glyph, "\(mark.label) \(mark.glyph)")
        }
    }
}

private struct StrokeDiagram: View {
    @Environment(StudyProgress.self) private var studyProgress
    let strokes: [StudyStrokes.Stroke]
    var selectedStroke: Int?
    var progress: Double?
    var reduceMotion = false
    var tracing = false

    var body: some View {
        let accent = studyProgress.theme.accent
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            let xOffset = (size.width - 100 * scale) / 2
            let yOffset = (size.height - 100 * scale) / 2
            let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: xOffset, ty: yOffset)
            var guides = Path()
            for coordinate in [20.0, 50.0, 80.0] {
                guides.move(to: CGPoint(x: 8, y: coordinate))
                guides.addLine(to: CGPoint(x: 92, y: coordinate))
                guides.move(to: CGPoint(x: coordinate, y: 8))
                guides.addLine(to: CGPoint(x: coordinate, y: 92))
            }
            context.stroke(guides.applying(transform), with: .color(.secondary.opacity(0.22)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            let line = StrokeStyle(lineWidth: tracing ? 5 : 3, lineCap: .round, lineJoin: .round)
            let activeMarker = selectedStroke ?? progress.map { min(Int($0), strokes.count - 1) }
            for (index, stroke) in strokes.enumerated() {
                let whole = stroke.path.applying(transform)
                let highlighted = selectedStroke == index
                let dimmed = selectedStroke != nil || progress != nil
                let baseColor = tracing ? accent.opacity(0.24) : (highlighted ? accent : Color.primary.opacity(dimmed ? 0.27 : 1))
                context.stroke(whole, with: .color(baseColor), style: line)
                if let progress {
                    let fraction = CGFloat(min(1, max(0, progress - Double(index))))
                    if fraction > 0 {
                        let visible = reduceMotion || fraction == 1 ? whole : whole.trimmedPath(from: 0, to: fraction)
                        context.stroke(visible, with: .color(accent), style: line)
                    }
                }
                guard let label = markerLabel(for: index, active: activeMarker) else { continue }
                let start = CGPoint(x: stroke.startX, y: stroke.startY).applying(transform)
                context.draw(Text(label).font(.caption2.bold()).foregroundColor(accent), at: CGPoint(x: start.x, y: start.y - 10))
            }
        }
        .accessibilityLabel("笔顺示意图")
    }

    private func markerLabel(for index: Int, active: Int?) -> String? {
        guard !tracing else { return nil }
        if let active { return index == active ? String(index + 1) : nil }
        let stroke = strokes[index]
        let sharedStart = strokes.indices.filter { other in
            strokes[other].startX == stroke.startX && strokes[other].startY == stroke.startY
        }
        guard sharedStart.first == index else { return nil }
        return sharedStart.map { String($0 + 1) }.joined(separator: "·")
    }
}

private extension StudyStrokes.Stroke {
    var path: Path {
        var path = Path()
        let tokens = d.split(separator: " ")
        var i = 0
        while i < tokens.count {
            let command = tokens[i]
            let count = command == "C" ? 6 : 2
            guard i + count < tokens.count else { break }
            let coordinates = tokens[(i + 1)...(i + count)].compactMap { Double($0) }
            guard coordinates.count == count else { break }
            let point = CGPoint(x: coordinates[0], y: coordinates[1])
            switch command {
            case "M": path.move(to: point)
            case "L": path.addLine(to: point)
            case "C": path.addCurve(to: CGPoint(x: coordinates[4], y: coordinates[5]), control1: point,
                                    control2: CGPoint(x: coordinates[2], y: coordinates[3]))
            default: return path
            }
            i += count + 1
        }
        return path
    }
}

private struct DrawingPad: UIViewRepresentable {
    var onStrokeAdded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStrokeAdded: onStrokeAdded)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawingPolicy = .anyInput
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.tool = PKInkingTool(.pen, color: .label, width: 5)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        context.coordinator.onStrokeAdded = onStrokeAdded
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onStrokeAdded: () -> Void
        private var lastStrokeCount = 0

        init(onStrokeAdded: @escaping () -> Void) {
            self.onStrokeAdded = onStrokeAdded
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let count = canvasView.drawing.strokes.count
            if count > lastStrokeCount {
                onStrokeAdded()
            }
            lastStrokeCount = count
        }
    }
}
