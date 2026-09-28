import SwiftUI
import Charts

struct CalculatorView: View {
    enum AmountUnit: String, CaseIterable, Identifiable {
        case grams = "g"
        case moles = "mol"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    @State private var formula = "C6H12O6"
    @State private var amountText = ""
    @State private var amountUnit: AmountUnit = .grams

    private static let avogadro = 6.02214076e23
    private static let examples = ["H2O", "CO2", "NaCl", "C6H12O6", "Ca(OH)2", "Al2(SO4)3", "CuSO4·5H2O", "C8H10N4O2"]

    var body: some View {
        let outcome = evaluate()

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(
                    title: "Molar mass calculator",
                    subtitle: "Type a formula – brackets and hydrates like CuSO4·5H2O work too."
                )
                inputPanel

                switch outcome {
                case .none:
                    EmptyView()
                case .failure(let error)?:
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassPanel(cornerRadius: 22, tint: Color.orange.opacity(0.25))
                case .success(let result)?:
                    resultPanel(result)
                    conversionPanel(result)
                }
            }
            .padding(20)
            .frame(maxWidth: 940, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Input

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Chemical formula", text: $formula)
                .textFieldStyle(.plain)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .autocorrectionDisabled()

            Text(FormulaFormatter.pretty(formula))
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(minHeight: 24, alignment: .leading)

            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(Self.examples, id: \.self) { example in
                            Button(FormulaFormatter.pretty(example)) { formula = example }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    // MARK: Result

    private func resultPanel(_ result: MolarMassResult) -> some View {
        let symbols = result.lines.map(\.symbol)
        let colors = result.lines.map { model.elementsBySymbol[$0.symbol]?.kind.color ?? .gray }

        return HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Molar mass").font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(result.total.formatted(.number.precision(.fractionLength(3))))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("g/mol").font(.title3).foregroundStyle(.secondary)
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    ForEach(result.lines) { line in
                        GridRow {
                            Text(line.symbol).font(.headline)
                            Text(line.name).foregroundStyle(.secondary)
                            Text("× \(line.count)").monospacedDigit()
                            Text(line.subtotal.formatted(.number.precision(.fractionLength(3))))
                                .monospacedDigit()
                                .gridColumnAlignment(.trailing)
                            Text(line.fraction.formatted(.percent.precision(.fractionLength(1))))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .gridColumnAlignment(.trailing)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Chart(result.lines) { line in
                SectorMark(
                    angle: .value("Mass", line.subtotal),
                    innerRadius: .ratio(0.62),
                    angularInset: 2
                )
                .cornerRadius(5)
                .foregroundStyle(by: .value("Element", line.symbol))
            }
            .chartForegroundStyleScale(domain: symbols, range: colors)
            .chartLegend(position: .bottom, spacing: 8)
            .frame(width: 210, height: 230)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    // MARK: Conversion

    private func conversionPanel(_ result: MolarMassResult) -> some View {
        let amount = Double(amountText.replacingOccurrences(of: ",", with: "."))

        return VStack(alignment: .leading, spacing: 14) {
            Text("Convert an amount").font(.headline)

            HStack(spacing: 12) {
                TextField("Amount", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Picker("Unit", selection: $amountUnit) {
                    ForEach(AmountUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)
            }

            if let amount, amount >= 0, result.total > 0 {
                let moles = amountUnit == .grams ? amount / result.total : amount
                let grams = amountUnit == .grams ? amount : amount * result.total
                HStack(spacing: 28) {
                    quantity("Mass", grams.formatted(.number.precision(.significantDigits(1...6))) + " g")
                    quantity("Amount", moles.formatted(.number.precision(.significantDigits(1...6))) + " mol")
                    quantity(
                        "Particles",
                        (moles * Self.avogadro).formatted(.number.notation(.scientific).precision(.significantDigits(3)))
                    )
                }
            } else {
                Text("Enter a mass in grams or an amount in moles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }

    private func quantity(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
    }

    // MARK: Evaluation

    private func evaluate() -> Result<MolarMassResult, FormulaError>? {
        let trimmed = formula.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            let counts = try FormulaParser(knownSymbols: model.knownSymbols).parse(trimmed)
            return .success(MolarMass.compute(counts: counts, elements: model.elementsBySymbol))
        } catch let error as FormulaError {
            return .failure(error)
        } catch {
            return .failure(.empty)
        }
    }
}
