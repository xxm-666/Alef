import PencilKit
import SwiftUI

struct AlphabetView: View {
    @Environment(StudyProgress.self) private var progress
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
        ScrollView {
            if letters.isEmpty {
                ContentUnavailableView.search(text: filter.searchQuery)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 12)], spacing: 12) {
                    ForEach(letters) { letter in
                        letterTile(letter)
                    }
                }
                .environment(\.layoutDirection, progress.alphabetFromRight ? .rightToLeft : .leftToRight)
                .padding()
            }
        }
        .navigationTitle("希伯来字母")
        .searchable(text: setting(\.searchQuery), prompt: "搜索字母、名称或读音")
        .toolbar {
            Menu {
                Picker("字母筛选", selection: setting(\.activeFilter)) {
                    ForEach(filters, id: \.0) { key, title in Text(title).tag(key) }
                }
            } label: {
                Label("筛选", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private func letterTile(_ letter: StudyLetter) -> some View {
        let mastery = progress.letterMastery[letter.id] ?? .unlearned
        return VStack(spacing: 6) {
            NavigationLink {
                LetterStudyView(letter: letter, content: content)
            } label: {
                card(letter).frame(maxWidth: .infinity, minHeight: 106)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(letter.nameChinese) \(letter.nameEnglish)")
            HStack(spacing: 14) {
                PronunciationButton(hebrew: letter.nameHebrew, fallback: letter.nameEnglish, iconOnly: true)
                if progress.display("showMastery") {
                    Button {
                        progress.setLetter(letter.id, mastery: mastery.next)
                    } label: {
                        Image(systemName: mastery.symbol)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("掌握度：\(mastery.title)")
                    .accessibilityHint("切换为\(mastery.next.title)")
                }
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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

    private func card(_ letter: StudyLetter) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                if progress.display("showBlock") { HebrewText(text: letter.hebrew, size: 36) }
                if progress.display("showCursive") { HebrewText(text: letter.hebrew, cursive: true, size: 33) }
                if progress.display("showSofit"), let sofit = letter.sofit {
                    HebrewText(text: sofit, size: 20).foregroundStyle(.secondary)
                }
            }
            if progress.display("showHebrewName") { HebrewText(text: letter.nameHebrew, size: 17) }
            if progress.display("showChineseName") { Text(letter.nameChinese).font(.subheadline) }
            if progress.display("showEnglishName") { Text(letter.nameEnglish).font(.caption) }
            if progress.display("showBegadkefat"), let variants = letter.begadkefat {
                HebrewText(text: "\(variants.withDagesh.glyph) · \(variants.withoutDagesh.glyph)", size: 14)
            }
            if progress.display("showModernSound") { Text(letter.modernIpa).font(.caption) }
            if progress.display("showBiblicalDiff", default: false) { Text(letter.biblicalIpa).font(.caption) }
            if progress.display("showTransliteration") { Text(letter.transliteration).font(.caption) }
            if progress.display("showGematria") {
                let numbers = letter.sofitInfo.map { "\(letter.gematria) / \($0.sofitGematria)" } ?? String(letter.gematria)
                Text(numbers).font(.caption)
            }
            if progress.display("showCategoryBadges", default: false) {
                let tags = filters.filter { letter.categories.contains($0.0) }.map(\.1)
                Text(tags.joined(separator: " · ")).font(.caption2)
            }
            if progress.display("showMastery") {
                Text((progress.letterMastery[letter.id] ?? .unlearned).title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .environment(\.layoutDirection, .leftToRight)
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
                HStack {
                    Button("上一个字母", systemImage: "chevron.left") { move(-1) }
                        .keyboardShortcut(progress.alphabetFromRight ? .rightArrow : .leftArrow, modifiers: [])
                    Spacer()
                    Button("下一个字母", systemImage: "chevron.right") { move(1) }
                        .keyboardShortcut(progress.alphabetFromRight ? .leftArrow : .rightArrow, modifiers: [])
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .environment(\.layoutDirection, progress.alphabetFromRight ? .rightToLeft : .leftToRight)
            }
            Section {
                HStack {
                    HebrewText(text: letter.hebrew, size: 74, style: .largeTitle)
                    HebrewText(text: letter.hebrew, cursive: true, size: 74, style: .largeTitle)
                    Spacer()
                    PronunciationButton(hebrew: letter.nameHebrew, fallback: letter.nameEnglish, iconOnly: true)
                }
                LabeledContent("希伯来语名称", value: letter.nameHebrew)
                LabeledContent("音译", value: letter.nameEnglish)
                LabeledContent("字母数值", value: String(letter.gematria))
                MasteryPicker(value: Binding(get: { progress.letterMastery[letter.id] ?? .unlearned }, set: {
                    progress.setLetter(letter.id, mastery: $0)
                }))
            }
            Section("发音") {
                LabeledContent("现代希伯来语", value: letter.modernIpa)
                LabeledContent("古典希伯来语", value: letter.biblicalIpa)
                Text(letter.pronunciationDesc)
                Text(letter.biblicalDiff).foregroundStyle(.secondary)
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
                    HStack {
                        HebrewText(text: sofit.medialGlyph, size: 36)
                        HebrewText(text: sofit.medialGlyph, cursive: true, size: 36)
                        Spacer()
                        Image(systemName: "arrow.right")
                        Spacer()
                        HebrewText(text: sofit.finalGlyph, size: 36)
                        HebrewText(text: sofit.finalGlyph, cursive: true, size: 36)
                    }
                    LabeledContent("词尾数值", value: String(sofit.sofitGematria))
                    Text(sofit.rule)
                    WordExampleRow(example: sofit.exampleWord)
                }
            }
            Section("笔顺与练习") {
                NavigationLink("查看笔顺并手写") { LetterWritingView(guide: letter.strokeGuide) }
                Text(letter.cursiveDesc)
            }
            Section("例词") {
                ForEach(Array(letter.examples.enumerated()), id: \.offset) { _, example in
                    WordExampleRow(example: example)
                }
            }
            Section("字源") {
                Text(letter.meaning)
                Text(letter.etymology)
            }
            if !letter.confusableWith.isEmpty {
                Section("易混字母") {
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
            PronunciationButton(hebrew: example.hebrew, fallback: example.transliteration, iconOnly: true)
        }
    }
}

private struct LetterWritingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let guide: StudyStrokes
    @State private var shape = "cursive"
    @State private var practiceID = UUID()
    @State private var showTracing = true
    @State private var selectedStroke: Int?
    @State private var animationStart: Date?

    private let secondsPerStroke = 1.15

    var body: some View {
        List {
            Picker("字形", selection: $shape) {
                Text("印刷").tag("block")
                Text("手写").tag("cursive")
                if guide.sofitBlockSteps != nil { Text("词尾印刷").tag("sofit-block") }
                if guide.sofitCursiveSteps != nil { Text("词尾手写").tag("sofit-cursive") }
            }
            .pickerStyle(.segmented)

            Section("笔顺") {
                TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 30, paused: animationStart == nil)) { timeline in
                    let position = animationStart.map { max(0, timeline.date.timeIntervalSince($0) / secondsPerStroke) }
                    StrokeDiagram(strokes: selectedStrokes, selectedStroke: selectedStroke, progress: position,
                                  reduceMotion: reduceMotion)
                }
                .frame(height: 164)
                Button(animationStart == nil ? "动画演示" : "重播笔顺", systemImage: animationStart == nil ? "play" : "arrow.counterclockwise") {
                    selectedStroke = nil
                    animationStart = .now
                }
                .disabled(selectedStrokes.isEmpty)
                ForEach(Array(selectedSteps.enumerated()), id: \.offset) { index, step in
                    Button {
                        animationStart = nil
                        selectedStroke = selectedStroke == index ? nil : index
                    } label: {
                        HStack {
                            Text(step).foregroundStyle(.primary)
                            Spacer()
                            if selectedStroke == index { Image(systemName: "checkmark") }
                        }
                    }
                    .accessibilityAddTraits(selectedStroke == index ? .isSelected : [])
                }
            }
            Section("手写练习") {
                ZStack {
                    StrokeDiagram(strokes: showTracing ? selectedStrokes : [], tracing: true)
                        .accessibilityHidden(true)
                    DrawingPad().id(practiceID)
                }
                .frame(height: 240)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                Toggle("显示描红字形", isOn: $showTracing)
                Button("清空练习", systemImage: "eraser") { practiceID = UUID() }
            }
        }
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
