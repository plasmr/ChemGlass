import SwiftUI

enum TableColorMode: String, CaseIterable, Identifiable {
    case category, block, electronegativity, radius, mass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .category: return "Category"
        case .block: return "Block"
        case .electronegativity: return "Electronegativity"
        case .radius: return "Atomic radius"
        case .mass: return "Atomic mass"
        }
    }

    var unit: String {
        switch self {
        case .electronegativity: return "Pauling"
        case .radius: return "pm"
        case .mass: return "u"
        case .category, .block: return ""
        }
    }

    /// Numeric value used by the heat-map modes (nil for the categorical modes).
    func value(for element: Element) -> Double? {
        switch self {
        case .electronegativity: return element.electronegativity
        case .radius: return element.atomicRadius
        case .mass: return element.mass
        case .category, .block: return nil
        }
    }
}

func heatColor(_ fraction: Double) -> Color {
    let t = min(max(fraction, 0), 1)
    return Color(hue: 0.66 * (1 - t), saturation: 0.8, brightness: 0.95)
}

func blockColor(_ block: String) -> Color {
    switch block.lowercased() {
    case "s": return .orange
    case "p": return .green
    case "d": return .blue
    case "f": return .pink
    default: return .gray
    }
}

struct PeriodicTableView: View {
    @Environment(AppModel.self) private var model
    @AppStorage(SettingsKey.tableColorMode) private var colorMode: TableColorMode = .category
    @State private var searchText = ""
    @State private var highlightedKind: ElementCategory?

    private let spacing = 5.0

    var body: some View {
        let range = heatRange
        let query = TextCleaner.fold(searchText.trimmingCharacters(in: .whitespaces))

        VStack(spacing: 14) {
            controls(query: query)

            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    tableGrid(size: proxy.size, range: range, query: query)
                        .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            }

            legend(range: range)
        }
        .padding(16)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Filter by name, symbol or number")
        .inspector(isPresented: inspectorBinding) {
            inspectorContent
                .inspectorColumnWidth(min: 300, ideal: 340, max: 420)
        }
        .onChange(of: colorMode) { highlightedKind = nil }
    }

    // MARK: Controls

    private func controls(query: String) -> some View {
        HStack(spacing: 12) {
            Picker("Color by", selection: $colorMode) {
                ForEach(TableColorMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 520)

            Spacer()

            if !query.isEmpty {
                let count = model.elements.filter { matches($0, query: query) }.count
                Text(count == 1 ? "1 match" : "\(count) matches")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Grid

    private func tableGrid(size: CGSize, range: ClosedRange<Double>?, query: String) -> some View {
        let tile = tileSize(for: size)
        let selectedID = model.selectedElementID

        return Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(1...max(model.maxRow, 1), id: \.self) { row in
                if model.emptyRows.contains(row) {
                    Color.clear.frame(height: tile * 0.35)
                } else {
                    GridRow {
                        ForEach(1...max(model.maxColumn, 1), id: \.self) { column in
                            cell(row: row, column: column, tile: tile, range: range, query: query, selectedID: selectedID)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func cell(row: Int, column: Int, tile: Double, range: ClosedRange<Double>?, query: String, selectedID: Int?) -> some View {
        if let element = model.element(row: row, column: column) {
            ElementTile(
                element: element,
                tint: tint(for: element, range: range),
                size: tile,
                isSelected: selectedID == element.id,
                isDimmed: isDimmed(element, query: query)
            ) {
                withAnimation(.smooth(duration: 0.3)) {
                    model.selectedElementID = (model.selectedElementID == element.id) ? nil : element.id
                }
            }
        } else if let label = placeholder(row: row, column: column) {
            RoundedRectangle(cornerRadius: tile * 0.2)
                .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .overlay {
                    Text(label)
                        .font(.system(size: tile * 0.17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: tile, height: tile * 1.1)
        } else {
            Color.clear.frame(width: tile, height: tile * 1.1)
        }
    }

    /// The two "57–71 / 89–103" markers in group 3 of the standard layout.
    private func placeholder(row: Int, column: Int) -> String? {
        guard column == 3 else { return nil }
        if row == 6 { return "57–71" }
        if row == 7 { return "89–103" }
        return nil
    }

    private func tileSize(for size: CGSize) -> Double {
        let columns = Double(max(model.maxColumn, 1))
        let rows = Double(max(model.maxRow, 1))
        let gapRows = Double(model.emptyRows.count)
        let padding = 32.0

        let byWidth = (size.width - padding - spacing * (columns - 1)) / columns
        let byHeight = (size.height - padding - spacing * (rows - 1)) / ((rows - gapRows) * 1.1 + gapRows * 0.35)
        return max(30, min(72, byWidth, byHeight))
    }

    // MARK: Colour & filtering

    private var heatRange: ClosedRange<Double>? {
        let values = model.elements.compactMap { colorMode.value(for: $0) }
        guard let low = values.min(), let high = values.max(), high > low else { return nil }
        return low...high
    }

    private func tint(for element: Element, range: ClosedRange<Double>?) -> Color {
        switch colorMode {
        case .category:
            return element.kind.color
        case .block:
            return blockColor(element.block)
        case .electronegativity, .radius, .mass:
            guard let value = colorMode.value(for: element), let range else { return .gray }
            return heatColor((value - range.lowerBound) / (range.upperBound - range.lowerBound))
        }
    }

    private func matches(_ element: Element, query: String) -> Bool {
        if query.isEmpty { return true }
        if let number = Int(query), number == element.id { return true }
        return TextCleaner.fold(element.name).contains(query) || TextCleaner.fold(element.symbol).contains(query)
    }

    private func isDimmed(_ element: Element, query: String) -> Bool {
        if let kind = highlightedKind, colorMode == .category, element.kind != kind { return true }
        return !matches(element, query: query)
    }

    // MARK: Legend

    @ViewBuilder
    private func legend(range: ClosedRange<Double>?) -> some View {
        switch colorMode {
        case .category:
            let kinds = ElementCategory.allCases.filter { kind in model.elements.contains { $0.kind == kind } }
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(kinds) { kind in
                            Button {
                                withAnimation(.smooth) {
                                    highlightedKind = (highlightedKind == kind) ? nil : kind
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(kind.color).frame(width: 10, height: 10)
                                    Text(kind.title)
                                }
                                .font(.caption.weight(.medium))
                            }
                            .buttonStyle(.glass)
                            .tint(highlightedKind == kind ? kind.color : nil)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        case .block:
            HStack(spacing: 14) {
                ForEach(["s", "p", "d", "f"], id: \.self) { block in
                    HStack(spacing: 6) {
                        Circle().fill(blockColor(block)).frame(width: 10, height: 10)
                        Text("\(block)-block").font(.caption.weight(.medium))
                    }
                }
            }
        case .electronegativity, .radius, .mass:
            if let range {
                HStack(spacing: 10) {
                    Text(format(range.lowerBound)).font(.caption).foregroundStyle(.secondary)
                    LinearGradient(
                        colors: stride(from: 0.0, through: 1.0, by: 0.25).map(heatColor),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 260, height: 10)
                    .clipShape(.capsule)
                    Text(format(range.upperBound)).font(.caption).foregroundStyle(.secondary)
                    Text(colorMode.unit).font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
    }

    // MARK: Inspector

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { model.selectedElementID != nil },
            set: { isPresented in
                if !isPresented { model.selectedElementID = nil }
            }
        )
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if let id = model.selectedElementID, let element = model.elementsByID[id] {
            ElementDetailView(element: element)
        }
    }
}

// MARK: - Tile

struct ElementTile: View {
    let element: Element
    let tint: Color
    let size: Double
    let isSelected: Bool
    let isDimmed: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.2)

        Button(action: action) {
            VStack(spacing: 0) {
                HStack {
                    Text("\(element.id)")
                        .font(.system(size: size * 0.2, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                Text(element.symbol)
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                if size >= 50 {
                    Text(element.name)
                        .font(.system(size: size * 0.15, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(size * 0.09)
            .frame(width: size, height: size * 1.1)
            .background {
                if isSelected {
                    shape.fill(.clear).glassEffect(.regular.tint(tint.opacity(0.55)), in: shape)
                } else {
                    shape.fill(tint.opacity(isHovering ? 0.42 : 0.26))
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [tint.opacity(isSelected ? 1 : 0.85), .white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 2 : 0.8
                )
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering && !isSelected ? 1.08 : 1)
        .opacity(isDimmed ? 0.22 : 1)
        .animation(.smooth(duration: 0.18), value: isHovering)
        .animation(.smooth(duration: 0.25), value: isDimmed)
        .onHover { isHovering = $0 }
        .help("\(element.name) (\(element.symbol))")
        .accessibilityLabel("\(element.name), atomic number \(element.id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
