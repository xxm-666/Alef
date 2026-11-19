import PencilKit
import SwiftUI

struct AlphabetView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent

    var body: some View {
        let options = content.defaultDisplay.merging(progress.read("alef.displayConfig.v1", default: [:])) { _, saved in saved }
        let mastery = progress.letterMastery
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: LetterGridLayout.columns(options: options, typeSize: typeSize),
                          spacing: LetterGridLayout.spacing) {
                    ForEach(content.letters) { letter in
                        letterTile(letter, options: options, mastery: mastery[letter.id] ?? .unlearned)
                    }
                }
                .environment(\.layoutDirection, letterDirection)

                if options["showSofit"] == true {
                    let letters = content.letters.filter { $0.sofitInfo != nil }
                    if !letters.isEmpty { finalFormsSection(letters, options: options) }
                }
            }
            .frame(maxWidth: LetterGridLayout.maximumWidth)
            .frame(maxWidth: .infinity)
        }
        .contentMargins(.horizontal, LetterGridLayout.pageMargin, for: .scrollContent)
        .contentMargins(.vertical, 12, for: .scrollContent)
        .background(progress.theme.canvas)
        .navigationTitle("希伯来字母")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var letterDirection: LayoutDirection { progress.alphabetFromRight ? .rightToLeft : .leftToRight }

    private func finalFormsSection(_ letters: [StudyLetter], options: [String: Bool]) -> some View {
        let size: GridItem.Size = typeSize.isAccessibilitySize ? .flexible() : .adaptive(minimum: typeSize >= .xxLarge ? 124 : 80)
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("词尾形").font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text("这五个字形用于单词末尾。").font(.subheadline).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(size, spacing: 10, alignment: .top)], spacing: 10) {
                ForEach(letters) { letter in
                    if let form = letter.sofitInfo {
                        finalFormTile(letter, form: form, options: options)
                    }
                }
            }
            .environment(\.layoutDirection, letterDirection)
        }
        .padding(12)
        .background(progress.theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
    }

    private func finalFormTile(_ letter: StudyLetter, form: StudySofit, options: [String: Bool]) -> some View {
        let name: String? = if options["showChineseName"] == true {
            letter.nameChinese
        } else if options["showEnglishName"] == true {
            letter.nameEnglish
        } else if options["showHebrewName"] == true {
            letter.nameHebrew
        } else {
            nil
        }
        return NavigationLink {
            LetterStudyView(letter: letter, content: content, showsFinalForm: true)
        } label: {
            VStack(spacing: 4) {
                HebrewText(text: form.finalGlyph, cursive: options["showBlock"] != true && options["showCursive"] == true,
                           size: 42, style: .title)
                    .foregroundStyle(progress.theme.accent)
                if let name {
                    Text(name)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 72)
            .environment(\.layoutDirection, .leftToRight)
            .background(progress.theme.cardSurface, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel([form.finalGlyph, name, "词尾形"].compactMap { $0 }.joined(separator: "，"))
    }

    private func letterTile(_ letter: StudyLetter, options: [String: Bool], mastery: Mastery) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        return VStack(spacing: 0) {
            NavigationLink {
                LetterStudyView(letter: letter, content: content)
            } label: {
                LetterTileContent(letter: letter, options: options)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel([letter.hebrew, options["showChineseName"] == true ? letter.nameChinese : nil,
                                 options["showEnglishName"] == true ? letter.nameEnglish : nil].compactMap { $0 }.joined(separator: "，"))
            Divider().padding(.horizontal, 10)
            HStack(spacing: 0) {
                PronunciationButton(hebrew: letter.nameHebrew, fallback: letter.nameEnglish, iconOnly: true,
                                    title: "朗读\(letter.nameChinese)", minimumHitSize: 44)
                Spacer(minLength: 0)
                if options["showMastery"] == true {
                    Button {
                        progress.setLetter(letter.id, mastery: mastery.next)
                    } label: {
                        Image(systemName: mastery.symbol)
                            .foregroundStyle(mastery == .unlearned ? Color.secondary : progress.theme.accent)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("\(letter.nameChinese)的掌握度：\(mastery.title)")
                    .accessibilityHint("切换为\(mastery.next.title)")
                }
            }
            .padding(.horizontal, 4)
        }
        .environment(\.layoutDirection, .leftToRight)
        .background(progress.theme.cardSurface, in: shape)
        .overlay { shape.strokeBorder(Color(uiColor: .separator).opacity(0.4), lineWidth: 1).allowsHitTesting(false) }
    }
}

enum LetterGridLayout {
    static let pageMargin: CGFloat = 16
    static let spacing: CGFloat = 12
    static let maximumWidth: CGFloat = 780

    static func columns(options: [String: Bool], typeSize: DynamicTypeSize) -> [GridItem] {
        if typeSize.isAccessibilitySize { return [GridItem(.flexible(), alignment: .top)] }
        let minimum = minimumTileWidth(options: options, typeSize: typeSize)
        return [GridItem(.adaptive(minimum: minimum), spacing: spacing, alignment: .top)]
    }

    static func previewWidth(pageWidth: CGFloat, options: [String: Bool], typeSize: DynamicTypeSize) -> CGFloat {
        let width = min(maximumWidth, max(0, pageWidth - 2 * pageMargin))
        if typeSize.isAccessibilitySize { return width }
        let minimum = minimumTileWidth(options: options, typeSize: typeSize)
        let count = max(1, ((width + spacing) / (minimum + spacing)).rounded(.down))
        return (width - (count - 1) * spacing) / count
    }

    private static func minimumTileWidth(options: [String: Bool], typeSize: DynamicTypeSize) -> CGFloat {
        if LetterTileContent.isDetailed(options) { return typeSize >= .xxLarge ? 200 : 136 }
        return typeSize >= .xxLarge ? 146 : 104
    }
}

struct LetterTileContent: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric private var glyphHeight: CGFloat = 46
    let letter: StudyLetter
    let options: [String: Bool]

    static func isDetailed(_ options: [String: Bool]) -> Bool {
        options["showBiblicalDiff"] == true || options["showCategoryBadges"] == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if options["showBlock"] == true || options["showCursive"] == true {
                let showBoth = options["showBlock"] == true && options["showCursive"] == true
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if options["showBlock"] == true { glyph(cursive: false, labeled: showBoth) }
                    if options["showCursive"] == true { glyph(cursive: true, labeled: showBoth) }
                }
                .frame(minHeight: glyphHeight)
                .accessibilityHidden(true)
            }
            if options["showChineseName"] == true { cardLine(Text(letter.nameChinese).font(.subheadline.weight(.semibold))) }
            if options["showEnglishName"] == true { cardLine(Text(letter.nameEnglish).font(.caption).foregroundColor(.secondary)) }
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
                cardLine(Text(detail.isEmpty ? " " : detail).font(.caption2).foregroundColor(.secondary), lines: 2)
            }
            if options["showCategoryBadges"] == true {
                let tags = [("sofit", "词尾变形"), ("begadkefat", "达盖什"), ("guttural", "喉音字母")]
                    .filter { letter.categories.contains($0.0) }.map(\.1)
                cardLine(Text(tags.isEmpty ? " " : tags.joined(separator: " · ")).font(.caption2), lines: 2)
            }
        }
        .foregroundStyle(.primary)
    }

    private func glyph(cursive: Bool, labeled: Bool) -> some View {
        VStack(spacing: 2) {
            HebrewText(text: letter.hebrew, cursive: cursive, size: cursive ? 31 : 34)
                .foregroundStyle(cursive ? Color.primary : progress.theme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
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
        if options["showSofit"] == true, let sofit = letter.sofit { details.append("末 \(sofit)") }
        if options["showBegadkefat"] == true, let variants = letter.begadkefat {
            details.append("\(variants.withDagesh.glyph)/\(variants.withoutDagesh.glyph)")
        }
        if options["showGematria"] == true {
            details.append(letter.sofitInfo.map { "\(letter.gematria)/\($0.sofitGematria)" } ?? String(letter.gematria))
        }
        return details.joined(separator: " · ")
    }
}

struct LetterStudyView: View {
    @Environment(StudyProgress.self) private var progress
    let content: StudyContent
    private let showsFinalForm: Bool
    @State private var letter: StudyLetter
    @State private var showDagesh = true

    init(letter: StudyLetter, content: StudyContent, showsFinalForm: Bool = false) {
        self.content = content
        self.showsFinalForm = showsFinalForm
        _letter = State(initialValue: letter)
    }

    private var displayGlyph: String {
        (showsFinalForm ? letter.sofitInfo?.finalGlyph : nil) ?? letter.hebrew
    }

    var body: some View {
        List {
            Section {
                letterHeader
                MasteryPicker(value: Binding(get: { progress.letterMastery[letter.id] ?? .unlearned }, set: {
                    progress.setLetter(letter.id, mastery: $0)
                }))
            }
            Section {
                NavigationLink {
                    LetterWritingView(guide: letter.strokeGuide, startsWithFinalForm: showsFinalForm)
                } label: {
                    Label("笔顺与手写练习", systemImage: "pencil.and.outline")
                        .frame(minHeight: 44)
                }
            }
            if showsFinalForm, let sofit = letter.sofitInfo {
                finalFormDetails(sofit)
            }
            if let example = letter.examples.first {
                Section("例词") {
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
            Section("发音") {
                LabeledContent("现代希伯来语", value: letter.modernIpa)
                Text(letter.pronunciationDesc)
                DisclosureGroup("古典读音与变化") {
                    LabeledContent("古典希伯来语", value: letter.biblicalIpa)
                    Text(letter.biblicalDiff).foregroundStyle(.secondary)
                }
            }
            if let variants = letter.begadkefat {
                Section("达盖什 · Begadkefat") {
                    Picker("字形预览", selection: $showDagesh) {
                        Text("带点 \(variants.withDagesh.glyph)").tag(true)
                        Text("无点 \(variants.withoutDagesh.glyph)").tag(false)
                    }
                    .pickerStyle(.segmented)
                    let variant = showDagesh ? variants.withDagesh : variants.withoutDagesh
                    HStack {
                        HebrewText(text: variant.glyph, size: 44)
                        Spacer()
                        Text(variant.name).font(.headline)
                    }
                    LabeledContent("现代 \(variant.modernSound)", value: variant.modernIpa)
                    LabeledContent("古典读音", value: variant.biblicalIpa)
                    Text(variants.note)
                }
            }
            if !showsFinalForm, let sofit = letter.sofitInfo {
                finalFormDetails(sofit)
            }
            DisclosureGroup("字源与字形说明") {
                LabeledContent("字母数值", value: String(letter.gematria))
                Text(letter.meaning)
                Text(letter.etymology)
                Text(letter.cursiveDesc)
            }
            if !letter.confusableWith.isEmpty {
                DisclosureGroup("易混字母") {
                    ForEach(content.letters.filter { letter.confusableWith.contains($0.id) }) { other in
                        NavigationLink("\(other.hebrew) · \(other.nameChinese)") {
                            LetterStudyView(letter: other, content: content)
                        }
                    }
                }
            }
        }
        .studyGroupedBackground()
        .id(letter.id)
        .navigationTitle("\(displayGlyph) · \(letter.nameChinese)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: letter.id, initial: true) { _, id in progress.write(id, for: "alef.selectedLetterId.v1") }
    }

    private var letterHeader: some View {
        VStack(spacing: 10) {
            HStack {
                letterNavigation(-1)
                Spacer(minLength: 4)
                Text("\(letter.nameHebrew) · \(letter.nameEnglish)")
                    .font(.headline).multilineTextAlignment(.center)
                    .environment(\.layoutDirection, .leftToRight)
                Spacer(minLength: 4)
                letterNavigation(1)
            }
            .environment(\.layoutDirection, progress.alphabetFromRight ? .rightToLeft : .leftToRight)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 40) {
                    letterForm(cursive: false)
                    letterForm(cursive: true)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(spacing: 12) {
                    letterForm(cursive: false)
                    letterForm(cursive: true)
                }
            }
            PronunciationButton(hebrew: letter.nameHebrew, fallback: letter.nameEnglish, minimumHitSize: 44)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func letterNavigation(_ offset: Int) -> some View {
        let previous = offset < 0
        let left = previous != progress.alphabetFromRight
        return Button { move(offset) } label: {
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .environment(\.layoutDirection, .leftToRight)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(previous ? "上一个字母" : "下一个字母")
        .keyboardShortcut(left ? .leftArrow : .rightArrow, modifiers: [])
    }

    private func letterForm(cursive: Bool) -> some View {
        VStack(spacing: 4) {
            HebrewText(text: displayGlyph, cursive: cursive, size: 62, style: .largeTitle)
                .foregroundStyle(cursive ? Color.primary : progress.theme.accent)
            Text(cursive ? "手写体" : "印刷体").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func finalFormDetails(_ form: StudySofit) -> some View {
        Section("词尾形 · Sofit") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { finalForms(form) }.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 12) { finalForms(form) }
            }
            LabeledContent("词尾数值", value: String(form.sofitGematria))
            Text(form.rule)
            WordExampleRow(example: form.exampleWord)
        }
    }

    @ViewBuilder private func finalForms(_ form: StudySofit) -> some View {
        letterForms("普通形", glyph: form.medialGlyph)
        letterForms("词尾形", glyph: form.finalGlyph)
    }

    private func letterForms(_ title: String, glyph: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                HebrewText(text: glyph, size: 36)
                HebrewText(text: glyph, cursive: true, size: 36)
            }
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func move(_ offset: Int) {
        let letters = showsFinalForm ? content.letters.filter { $0.sofitInfo != nil } : content.letters
        guard let index = letters.firstIndex(where: { $0.id == letter.id }) else { return }
        letter = letters[(index + offset + letters.count) % letters.count]
        showDagesh = true
    }
}

struct WordExampleRow: View {
    let example: StudyExample

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HebrewText(text: example.hebrew)
                Text(example.transliteration).foregroundStyle(.secondary)
                Text(example.meaning)
                if let note = example.note { Text(note).foregroundStyle(.secondary) }
            }
            Spacer()
            PronunciationButton(hebrew: example.hebrew, fallback: example.transliteration, iconOnly: true, minimumHitSize: 44)
        }
    }
}

private struct LetterWritingView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var widthClass
    let guide: StudyStrokes
    @State private var shape: String
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
        VStack(spacing: 0) {
            Group {
                if typeSize >= .xxLarge { shapePicker.pickerStyle(.menu) }
                else { shapePicker.pickerStyle(.segmented) }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)

            ScrollViewReader { scroll in
                List {
                    if sideBySide {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("笔顺演示").font(.headline)
                                demonstration
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .id("stroke-demo")
                            practice.frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .padding(.vertical, 8)
                    } else {
                        DisclosureGroup("笔顺演示", isExpanded: $showsDemonstration) {
                            demonstration
                        }
                        .frame(minHeight: 44)
                        .id("stroke-demo")
                        practice.padding(.vertical, 8)
                    }
                    strokeSteps
                }
                .studyGroupedBackground()
                .contentMargins(.vertical, 8, for: .scrollContent)
                .onChange(of: selectedStroke) { _, index in
                    if index != nil && !sideBySide {
                        showsDemonstration = true
                        scroll.scrollTo("stroke-demo", anchor: .top)
                    }
                }
            }
        }
        .background(progress.theme.canvas)
        .navigationTitle("笔顺与手写")
        .onChange(of: showsDemonstration) { _, expanded in
            if !expanded { animationStart = nil }
        }
        .onChange(of: shape) { _, _ in
            animationStart = nil
            selectedStroke = nil
            practiceID = UUID()
        }
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

    private var shapePicker: some View {
        Picker("字形", selection: $shape) {
            Text("印刷").tag("block")
            Text("手写").tag("cursive")
            if guide.sofitBlockSteps != nil { Text("词尾印刷").tag("sofit-block") }
            if guide.sofitCursiveSteps != nil { Text("词尾手写").tag("sofit-cursive") }
        }
    }

    private var demonstration: some View {
        VStack(alignment: .leading, spacing: 8) {
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30, paused: animationStart == nil)) { timeline in
                let position = animationStart.map { max(0, timeline.date.timeIntervalSince($0) / secondsPerStroke) }
                StrokeDiagram(strokes: selectedStrokes, selectedStroke: selectedStroke, progress: position, reduceMotion: reduceMotion)
            }
            .frame(height: sideBySide ? 224 : 144)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
            Button {
                selectedStroke = nil
                animationStart = .now
            } label: {
                Label(animationStart == nil ? "播放笔顺" : "重播笔顺",
                      systemImage: animationStart == nil ? "play" : "arrow.counterclockwise")
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
            .disabled(selectedStrokes.isEmpty)
        }
    }

    private var practice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手写练习").font(.headline)
            HStack(spacing: 12) {
                Toggle("描红", isOn: $showTracing).frame(minHeight: 44)
                Button {
                    practiceID = UUID()
                } label: {
                    Image(systemName: "eraser").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("清空练习")
            }
            Rectangle()
                .fill(Color(uiColor: .tertiarySystemFill))
                .aspectRatio(1.2, contentMode: .fit)
                .frame(maxHeight: 320)
                .overlay {
                    StrokeDiagram(strokes: showTracing ? selectedStrokes : [], tracing: true)
                        .accessibilityHidden(true)
                    DrawingPad().id(practiceID).accessibilityLabel("手写练习区")
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var selectedSteps: [String] {
        switch shape {
        case "cursive": guide.cursiveSteps
        case "sofit-block": guide.sofitBlockSteps ?? []
        case "sofit-cursive": guide.sofitCursiveSteps ?? []
        default: guide.blockSteps
        }
    }

    private var selectedStrokes: [StudyStrokes.Stroke] {
        switch shape {
        case "cursive": guide.cursiveStrokes
        case "sofit-block": guide.sofitBlockStrokes ?? []
        case "sofit-cursive": guide.sofitCursiveStrokes ?? []
        default: guide.blockStrokes
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
            for (index, stroke) in strokes.enumerated() {
                let whole = path(stroke.d).applying(transform)
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
                guard !tracing else { continue }
                let start = CGPoint(x: stroke.startX, y: stroke.startY).applying(transform)
                context.draw(Text("\(index + 1)").font(.caption2.bold()).foregroundColor(accent), at: CGPoint(x: start.x, y: start.y - 10))
            }
        }
        .accessibilityLabel("笔顺示意图")
    }

    private func path(_ description: String) -> Path {
        var path = Path()
        let tokens = description.split(separator: " ")
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
    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawingPolicy = .anyInput
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.tool = PKInkingTool(.pen, color: .label, width: 5)
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {}
}
