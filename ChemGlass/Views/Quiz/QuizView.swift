import SwiftUI
import Observation

@Observable
final class QuizSession {
    enum Kind: String, CaseIterable, Identifiable {
        case symbolToName, nameToSymbol, category, definition

        var id: String { rawValue }

        var title: String {
            switch self {
            case .symbolToName: return "Symbol → Name"
            case .nameToSymbol: return "Name → Symbol"
            case .category: return "Category"
            case .definition: return "Definitions"
            }
        }
    }

    struct Question {
        let prompt: String
        let caption: String
        let options: [String]
        let answer: String
        let explanation: String
        var isLongPrompt: Bool { prompt.count > 24 }
    }

    var kind: Kind = .symbolToName
    private(set) var question: Question?
    private(set) var selection: String?
    private(set) var score = 0
    private(set) var answered = 0
    private(set) var streak = 0
    private(set) var bestStreak = 0

    @ObservationIgnored private var definitionPool: [Term] = []

    var isAnswered: Bool { selection != nil }

    func reset(elements: [Element], terms: [Term]) {
        score = 0
        answered = 0
        streak = 0
        advance(elements: elements, terms: terms)
    }

    func advance(elements: [Element], terms: [Term]) {
        selection = nil
        question = makeQuestion(elements: elements, terms: terms)
    }

    func submit(_ option: String) {
        guard let question = question, selection == nil else { return }
        selection = option
        answered += 1
        if option == question.answer {
            score += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
        } else {
            streak = 0
        }
    }

    // MARK: Question generation

    private func makeQuestion(elements: [Element], terms: [Term]) -> Question? {
        switch kind {
        case .symbolToName:
            guard let target = elements.randomElement() else { return nil }
            let others = elements.filter { $0.id != target.id }.shuffled().prefix(3).map(\.name)
            return Question(
                prompt: target.symbol,
                caption: "Which element has this symbol?",
                options: ([target.name] + others).shuffled(),
                answer: target.name,
                explanation: "\(target.symbol) is \(target.name), element number \(target.id)."
            )

        case .nameToSymbol:
            guard let target = elements.randomElement() else { return nil }
            let others = elements.filter { $0.id != target.id }.shuffled().prefix(3).map(\.symbol)
            return Question(
                prompt: target.name,
                caption: "What is the symbol for this element?",
                options: ([target.symbol] + others).shuffled(),
                answer: target.symbol,
                explanation: "\(target.name) has the symbol \(target.symbol)."
            )

        case .category:
            guard let target = elements.randomElement() else { return nil }
            let present = Set(elements.map { $0.kind }).filter { $0 != .unknown }
            let others = present.filter { $0 != target.kind }.shuffled().prefix(3).map(\.title)
            return Question(
                prompt: target.name,
                caption: "Which family does this element belong to?",
                options: ([target.kind.title] + others).shuffled(),
                answer: target.kind.title,
                explanation: "\(target.name) (\(target.symbol)) is among the \(target.kind.title.lowercased())."
            )

        case .definition:
            if definitionPool.isEmpty {
                definitionPool = terms.filter { (40...260).contains($0.definition.count) }
            }
            guard terms.count >= 4, let target = definitionPool.randomElement() else { return nil }
            var titles: Set<String> = [target.title]
            var attempts = 0
            while titles.count < 4, attempts < 100, let candidate = terms.randomElement() {
                titles.insert(candidate.title)
                attempts += 1
            }
            return Question(
                prompt: target.definition,
                caption: "Which IUPAC term is defined here?",
                options: Array(titles).shuffled(),
                answer: target.title,
                explanation: "This is the definition of “\(target.title)”."
            )
        }
    }
}

struct QuizView: View {
    @Environment(AppModel.self) private var model
    @State private var session = QuizSession()

    var body: some View {
        @Bindable var bindableSession = session

        ScrollView {
            VStack(spacing: 20) {
                statsRow

                Picker("Quiz type", selection: $bindableSession.kind) {
                    ForEach(QuizSession.Kind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if let question = session.question {
                    questionCard(question)
                    optionsGrid(question)
                    footer(question)
                } else {
                    ContentUnavailableView("No question available", systemImage: "questionmark.circle")
                }
            }
            .padding(24)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            if session.question == nil { advance() }
        }
        .onChange(of: session.kind) { advance() }
    }

    private func advance() {
        session.advance(elements: model.elements, terms: model.terms)
    }

    // MARK: Pieces

    private var statsRow: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                stat("Score", "\(session.score)/\(session.answered)")
                stat("Streak", "\(session.streak)")
                stat("Best streak", "\(session.bestStreak)")
                Spacer()
                Button("Reset") {
                    session.reset(elements: model.elements, terms: model.terms)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.bold)).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    private func questionCard(_ question: QuizSession.Question) -> some View {
        VStack(spacing: 10) {
            Text(question.caption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(question.prompt)
                .font(question.isLongPrompt ? .title3 : .system(size: 56, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
        .glassPanel()
    }

    private func optionsGrid(_ question: QuizSession.Question) -> some View {
        GlassEffectContainer(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        withAnimation(.smooth) { session.submit(option) }
                    } label: {
                        HStack {
                            Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.secondary)
                            Text(option).frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .tint(tint(for: option, question: question))
                    .allowsHitTesting(!session.isAnswered)
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
                }
            }
        }
    }

    private func tint(for option: String, question: QuizSession.Question) -> Color? {
        guard session.isAnswered else { return nil }
        if option == question.answer { return .green }
        if option == session.selection { return .red }
        return nil
    }

    private func footer(_ question: QuizSession.Question) -> some View {
        HStack {
            if session.isAnswered {
                Label(
                    session.selection == question.answer ? "Correct!" : "Not quite.",
                    systemImage: session.selection == question.answer ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .foregroundStyle(session.selection == question.answer ? Color.green : Color.red)
                .font(.headline)
                Text(question.explanation).foregroundStyle(.secondary)
            } else {
                Text("Press 1–4 to answer").foregroundStyle(.secondary)
            }
            Spacer()
            Button(session.isAnswered ? "Next question" : "Skip") { advance() }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.return, modifiers: [])
        }
    }
}
