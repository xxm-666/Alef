import PencilKit
import SwiftUI

struct AlphabetView: View {
    @Environment(StudyProgress.self) private var progress
    @Environment(\.dynamicTypeSize) private var typeSize
    let content: StudyContent

    private struct Filter: Codable {
        var searchQuery = ""
        var activeFilter = "all"
    }

    private let filters = [
        ("all", "所有字母"), ("sofit", "词尾变形"), ("begadkefat", "达盖什"),
        ("guttural", "喉音字母"), ("confusable", "易混字母"), ("needs_review", "需复习")
    ]

    var body: some View {
        let options = content.defaultDisplay.merging(progress.read("alef.displayConfig.v1", default: [:])) { _, saved in saved }
        let mastery = progress.letterMastery
        let visibleLetters = letters
        ScrollView {
            if visibleLetters.isEmpty {
                if filter.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("没有符合筛选条件的字母", systemImage: "line.3.horizontal.decrease.circle")
                } else {
                    ContentUnavailableView.search(text: filter.searchQuery)
                }
            } else {
                LazyVGrid(columns: columns(for: options), spacing: 12) {
                    ForEach(visibleLetters) { letter in
                        letterTile(letter, options: options, mastery: mastery[letter.id] ?? .unlearned)
                    }
                }
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, progress.alphabetFromRight ? .rightToLeft : .leftToRight)
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .contentMargins(.vertical, 12, for: .scrollContent)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let title = filters.first(where: { $0.0 == filter.activeFilter && $0.0 != "all" })?.1 {
                HStack {
                    Label(title, systemImage: "line.3.horizontal.decrease")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Button("清除筛选") { setting(\.activeFilter).wrappedValue = "all" }
                        .frame(minHeight: 44)
                }
                .frame(maxWidth: 780)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .systemGroupedBackground))
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("希伯来字母")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: setting(\.searchQuery), placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索字母、名称或读音")
        .toolbar {
            Menu {
                Picker("字母筛选", selection: setting(\.activeFilter)) {
                    ForEach(filters, id: \.0) { key, title in Text(title).tag(key) }
                }
            } label: {
                Label("筛选", systemImage: filter.activeFilter == "all" ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityValue(filters.first { $0.0 == filter.activeFilter }?.1 ?? "所有字母")
        }
    }

    private func columns(for options: [String: Bool]) -> [GridItem] {
        if typeSize.isAccessibilitySize { return [GridItem(.flexible(), alignment: .top)] }
        let minimum: CGFloat
        if LetterTileContent.isDetailed(options) { minimum = typeSize >= .xxLarge ? 200 : 136 }
        else { minimum = typeSize >= .xxLarge ? 146 : 104 }
        return [GridItem(.adaptive(minimum: minimum), spacing: 12, alignment: .top)]
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
                            .foregroundStyle(mastery == .unlearned ? Color.secondary : Color.accentColor)
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
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
        .overlay { shape.strokeBorder(Color(uiColor: .separator).opacity(0.4), lineWidth: 1).allowsHitTesting(false) }
    }

    private var filter: Filter { progress.read("alef.gridState.v1", default: Filter()) }

    private func setting(_ keyPath: WritableKeyPath<Filter, String>) -> Binding<String> {
        Binding(get: { filter[keyPath: keyPath] }, set: { value in
            var state = filter
            state[keyPath: keyPath] = value
            progress.write(state, for: "alef.gridState.v1")
        })
    }

    private var letters: [StudyLetter] {
        let state = filter
        let mastery = progress.letterMastery
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return content.letters.filter { letter in
            let included = switch state.activeFilter {
            case "all": true
            case "confusable": !letter.confusableWith.isEmpty
            case "needs_review": mastery[letter.id] != .mastered
            default: letter.categories.contains(state.activeFilter)
            }
            let searchable = [letter.hebrew, letter.sofit ?? "", letter.nameChinese, letter.nameEnglish, letter.nameHebrew,
                              letter.transliteration, letter.modernSound, letter.modernIpa]
            return included && (query.isEmpty || searchable.contains { $0.localizedStandardContains(query) })
        }
    }
}

struct LetterTileContent: View {
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
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if options["showBlock"] == true { HebrewText(text: letter.hebrew, size: 34).foregroundStyle(.tint) }
                    if options["showCursive"] == true { HebrewText(text: letter.hebrew, cursive: true, size: 31).foregroundStyle(.primary) }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)
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
    @State private var letter: StudyLetter
    @State private var showDagesh = true

    init(letter: StudyLetter, content: StudyContent) {
        self.content = content
        _letter = State(initialValue: letter)
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
                    LetterWritingView(guide: letter.strokeGuide)
                } label: {
                    Label("笔顺与手写练习", systemImage: "pencil.and.outline")
                        .frame(minHeight: 44)
                }
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
            if let sofit = letter.sofitInfo {
                Section("词尾形 · Sofit") {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { finalForms(sofit) }.fixedSize(horizontal: true, vertical: false)
                        VStack(alignment: .leading, spacing: 12) { finalForms(sofit) }
                    }
                    LabeledContent("词尾数值", value: String(sofit.sofitGematria))
                    Text(sofit.rule)
                    WordExampleRow(example: sofit.exampleWord)
                }
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
        .id(letter.id)
        .navigationTitle("\(letter.hebrew) · \(letter.nameChinese)")
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
            HebrewText(text: letter.hebrew, cursive: cursive, size: 62, style: .largeTitle)
                .foregroundStyle(cursive ? Color.primary : Color.accentColor)
            Text(cursive ? "手写体" : "印刷体").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
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
        guard let index = content.letters.firstIndex(where: { $0.id == letter.id }) else { return }
        letter = content.letters[(index + offset + content.letters.count) % content.letters.count]
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var widthClass
    let guide: StudyStrokes
    @State private var shape = "cursive"
    @State private var practiceID = UUID()
    @State private var showTracing = true
    @State private var selectedStroke: Int?
    @State private var animationStart: Date?

    private let secondsPerStroke = 1.15

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

            List {
                if widthClass == .regular && !typeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: 24) {
                        demonstration.frame(maxWidth: .infinity, alignment: .topLeading)
                        practice.frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.vertical, 8)
                } else {
                    demonstration.padding(.vertical, 8)
                    practice.padding(.vertical, 8)
                }
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
            .contentMargins(.vertical, 8, for: .scrollContent)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("笔顺与手写")
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
            Text("笔顺演示").font(.headline)
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30, paused: animationStart == nil)) { timeline in
                let position = animationStart.map { max(0, timeline.date.timeIntervalSince($0) / secondsPerStroke) }
                StrokeDiagram(strokes: selectedStrokes, selectedStroke: selectedStroke, progress: position, reduceMotion: reduceMotion)
            }
            .frame(height: widthClass == .regular ? 224 : 144)
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
            Toggle("显示描红字形", isOn: $showTracing).frame(minHeight: 44)
            Button {
                practiceID = UUID()
            } label: {
                Label("清空练习", systemImage: "eraser").frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
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
    let strokes: [StudyStrokes.Stroke]
    var selectedStroke: Int?
    var progress: Double?
    var reduceMotion = false
    var tracing = false

    var body: some View {
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
                let baseColor: Color = tracing ? .accentColor.opacity(0.24) : (highlighted ? .accentColor : .primary.opacity(dimmed ? 0.27 : 1))
                context.stroke(whole, with: .color(baseColor), style: line)
                if let progress {
                    let fraction = CGFloat(min(1, max(0, progress - Double(index))))
                    if fraction > 0 {
                        let visible = reduceMotion || fraction == 1 ? whole : whole.trimmedPath(from: 0, to: fraction)
                        context.stroke(visible, with: .color(.accentColor), style: line)
                    }
                }
                guard !tracing else { continue }
                let start = CGPoint(x: stroke.startX, y: stroke.startY).applying(transform)
                context.draw(Text("\(index + 1)").font(.caption2.bold()).foregroundColor(.accentColor), at: CGPoint(x: start.x, y: start.y - 10))
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
