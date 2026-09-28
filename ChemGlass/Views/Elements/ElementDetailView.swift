import SwiftUI

struct ElementDetailView: View {
    let element: Element

    @Environment(LibraryStore.self) private var library

    var body: some View {
        let kind = element.kind

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero(kind: kind)
                actions
                properties
                configuration
                if let shells = element.electronShells {
                    shellSection(shells: shells, tint: kind.color)
                }
            }
            .padding(20)
        }
        .task { library.recordView(ofElement: element.id) }
    }

    // MARK: Sections

    private func hero(kind: ElementCategory) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(element.id)")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(element.symbol)
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                Text(element.mass.formatted(.number.precision(.fractionLength(3))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 112, height: 128, alignment: .leading)
            .glassEffect(.regular.tint(kind.color.opacity(0.55)), in: RoundedRectangle(cornerRadius: 22))

            VStack(alignment: .leading, spacing: 8) {
                Text(element.name)
                    .font(.title.bold())
                TintChip(title: kind.title, tint: kind.color)
                Text(element.blockLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        let isFavorite = library.favoriteElementIDs.contains(element.id)
        return Button {
            library.toggleFavorite(element: element.id)
        } label: {
            Label(isFavorite ? "Favorited" : "Add to Favorites", systemImage: isFavorite ? "star.fill" : "star")
        }
        .buttonStyle(.glass)
        .tint(isFavorite ? .yellow : nil)
    }

    private var properties: some View {
        let states = element.oxidationStates

        return Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            row("Atomic mass", element.mass.formatted(.number.precision(.fractionLength(3))) + " u")
            row(
                "Electronegativity",
                element.electronegativity.map { $0.formatted(.number.precision(.fractionLength(2))) + " (Pauling)" } ?? "—"
            )
            row(
                "Atomic radius",
                element.atomicRadius.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...1))) + " pm" } ?? "—"
            )
            row("Oxidation states", states.isEmpty ? "—" : states.joined(separator: ", "))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).fontWeight(.medium)
        }
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Electron configuration").font(.headline)
            Text(ElectronConfiguration.superscripted(element.electronConfigShorthand))
                .font(.body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shellSection(shells: [Int], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Electron shells").font(.headline)
            ShellDiagram(shells: shells, tint: tint, symbol: element.symbol)
            Text(shells.map(String.init).joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}

/// A Bohr-style picture of how many electrons sit in each shell.
struct ShellDiagram: View {
    let shells: [Int]
    let tint: Color
    let symbol: String

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 8
            let inner = outer * 0.2
            let count = shells.count
            let step = count > 1 ? (outer - inner) / Double(count - 1) : 0

            for (index, electrons) in shells.enumerated() {
                let radius = count > 1 ? inner + step * Double(index) : outer * 0.6
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.stroke(ring, with: .color(Color.secondary.opacity(0.35)), lineWidth: 1)

                let dot = 3.2
                let offset = Double(index) * 0.45
                for electron in 0..<electrons {
                    let angle = 2 * Double.pi * Double(electron) / Double(max(electrons, 1)) + offset
                    let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                    let dotRect = CGRect(x: point.x - dot, y: point.y - dot, width: dot * 2, height: dot * 2)
                    context.fill(Path(ellipseIn: dotRect), with: .color(tint))
                }
            }

            let nucleus = max(inner * 0.75, 9)
            let nucleusRect = CGRect(x: center.x - nucleus, y: center.y - nucleus, width: nucleus * 2, height: nucleus * 2)
            context.fill(Path(ellipseIn: nucleusRect), with: .color(tint.opacity(0.9)))
            context.draw(Text(symbol).font(.system(size: nucleus * 0.9, weight: .bold, design: .rounded)), at: center)
        }
        .frame(height: 230)
        .accessibilityElement()
        .accessibilityLabel("Electron shells: \(shells.map(String.init).joined(separator: ", "))")
    }
}
