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
                        NavigationLink {
                            LetterStudyView(letter: letter, content: content)
                        } label: {
                            card(letter)
                                .frame(maxWidth: .infinity, minHeight: 106)
                                .padding(8)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("\(letter.nameChinese) \(letter.nameEnglish)")
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
            if progress.display("showGematria") { Text(letter.gematria, format: .number).font(.caption) }
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
    let letter: StudyLetter
    let content: StudyContent

    var body: some View {
        List {
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
                    LabeledContent(variants.withDagesh.glyph, value: variants.withDagesh.modernIpa)
                    LabeledContent(variants.withoutDagesh.glyph, value: variants.withoutDagesh.modernIpa)
                    Text(variants.note)
                }
            }
            if let sofit = letter.sofitInfo {
                Section("词尾形 · Sofit") {
                    LabeledContent("词尾字形", value: sofit.finalGlyph)
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
        .navigationTitle("\(letter.hebrew) · \(letter.nameChinese)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { progress.write(letter.id, for: "alef.selectedLetterId.v1") }
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
    let guide: StudyStrokes
    @State private var shape = "block"
    @State private var practiceID = UUID()

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
                StrokeDiagram(strokes: selectedStrokes).frame(height: 164)
                ForEach(Array(selectedSteps.enumerated()), id: \.offset) { _, step in Text(step) }
            }
            Section("手写练习") {
                DrawingPad().id(practiceID).frame(height: 240)
                Button("清空练习", systemImage: "eraser") { practiceID = UUID() }
            }
        }
        .navigationTitle("笔顺与手写")
        .onChange(of: shape) { _, _ in practiceID = UUID() }
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

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            let xOffset = (size.width - 100 * scale) / 2
            let yOffset = (size.height - 100 * scale) / 2
            for (index, stroke) in strokes.enumerated() {
                let transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: xOffset, ty: yOffset)
                context.stroke(path(stroke.d).applying(transform), with: .foreground,
                               style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
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
        view.backgroundColor = .secondarySystemGroupedBackground
        view.tool = PKInkingTool(.pen, color: .label, width: 5)
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {}
}
