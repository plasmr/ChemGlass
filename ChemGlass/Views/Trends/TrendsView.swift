import SwiftUI
import Charts

struct TrendsView: View {
    enum Metric: String, CaseIterable, Identifiable {
        case electronegativity, radius, mass

        var id: String { rawValue }

        var title: String {
            switch self {
            case .electronegativity: return "Electronegativity"
            case .radius: return "Atomic radius"
            case .mass: return "Atomic mass"
            }
        }

        var unit: String {
            switch self {
            case .electronegativity: return "Pauling scale"
            case .radius: return "pm"
            case .mass: return "u"
            }
        }

        func value(for element: Element) -> Double? {
            switch self {
            case .electronegativity: return element.electronegativity
            case .radius: return element.atomicRadius
            case .mass: return element.mass
            }
        }

        func formatted(_ value: Double) -> String {
            value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
        }
    }

    struct Point: Identifiable {
        let element: Element
        let value: Double
        var id: Int { element.id }
    }

    @Environment(AppModel.self) private var model
    @State private var metric: Metric = .electronegativity
    @State private var selectedNumber: Int?

    var body: some View {
        let points = model.elements.compactMap { element -> Point? in
            guard let value = metric.value(for: element) else { return nil }
            return Point(element: element, value: value)
        }
        let kinds = ElementCategory.allCases.filter { kind in points.contains { $0.element.kind == kind } }
        let selected = selectedNumber.flatMap { model.elementsByID[$0] }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ScreenHeader(title: "Periodic trends", subtitle: "Hover the chart to inspect an element.")
                Spacer()
                Picker("Property", selection: $metric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.title).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 380)
            }

            HStack(alignment: .top, spacing: 16) {
                chart(points: points, kinds: kinds)
                    .padding(20)
                    .glassPanel()

                sidePanel(points: points, selected: selected)
                    .frame(width: 270)
            }
        }
        .padding(16)
    }

    private func chart(points: [Point], kinds: [ElementCategory]) -> some View {
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Atomic number", point.element.id),
                    y: .value(metric.title, point.value)
                )
                .foregroundStyle(Color.secondary.opacity(0.25))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Atomic number", point.element.id),
                    y: .value(metric.title, point.value)
                )
                .foregroundStyle(by: .value("Category", point.element.kind.title))
                .symbolSize(point.element.id == selectedNumber ? 200 : 60)
            }

            if let selectedNumber {
                RuleMark(x: .value("Atomic number", selectedNumber))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartForegroundStyleScale(domain: kinds.map(\.title), range: kinds.map(\.color))
        .chartXSelection(value: $selectedNumber)
        .chartXScale(domain: 0...120)
        .chartXAxisLabel("Atomic number")
        .chartYAxisLabel("\(metric.title) (\(metric.unit))")
        .chartLegend(position: .bottom, spacing: 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sidePanel(points: [Point], selected: Element?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selected {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selected.symbol)
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                    Text(selected.name).font(.title3.bold())
                    TintChip(title: selected.kind.title, tint: selected.kind.color)

                    if let value = metric.value(for: selected) {
                        Text("\(metric.formatted(value)) \(metric.unit)")
                            .font(.title3.weight(.semibold))
                    } else {
                        Text("No data for this property")
                            .foregroundStyle(.secondary)
                    }

                    Button("Open in Periodic Table") { model.open(element: selected.id) }
                        .buttonStyle(.glass)
                }
            } else {
                Label("Select a point", systemImage: "cursorarrow.click.2")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let highest = points.max(by: { $0.value < $1.value }),
               let lowest = points.min(by: { $0.value < $1.value }) {
                extreme("Highest", point: highest)
                extreme("Lowest", point: lowest)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassPanel()
    }

    private func extreme(_ label: String, point: Point) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text("\(point.element.name) · \(metric.formatted(point.value)) \(metric.unit)")
                .font(.subheadline.weight(.medium))
        }
    }
}
