import SwiftUI
import Foundation

// MARK: - Settings

enum SettingsKey {
    static let appearance = "appearance"
    static let palette = "backdropPalette"
    static let animateBackdrop = "animateBackdrop"
    static let definitionFontSize = "definitionFontSize"
    static let tableColorMode = "tableColorMode"
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Backdrop palettes

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum BackdropPalette: String, CaseIterable, Identifiable {
    case aurora, sunset, ocean, forest, graphite

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// Nine colours for a 3×3 mesh gradient (row-major), tuned for dark mode.
    private var hexes: [UInt32] {
        switch self {
        case .aurora:
            return [0x0B1026, 0x2B1E6B, 0x0E5A6B, 0x5B2A86, 0x1F4FD8, 0x14B8A6, 0x101B3D, 0x0F766E, 0x312E81]
        case .sunset:
            return [0x2A0A18, 0x7A1D3D, 0xB4452C, 0x5B1A4E, 0xE0662E, 0xF2A33C, 0x1F0B2E, 0x8A2A5B, 0xC2503A]
        case .ocean:
            return [0x03122B, 0x0B3A6E, 0x0E7490, 0x082F49, 0x1D8FE1, 0x22D3EE, 0x041C3A, 0x0C5A8A, 0x0EA5B7]
        case .forest:
            return [0x04170F, 0x0C3B25, 0x14532D, 0x0A2A1B, 0x1F8A4C, 0x4ADE80, 0x061F14, 0x14663A, 0x2F9E6A]
        case .graphite:
            return [0x0E0F13, 0x1B1D26, 0x272A36, 0x14161C, 0x3A3F52, 0x4B5573, 0x101218, 0x22252F, 0x30364A]
        }
    }

    func colors(for scheme: ColorScheme) -> [Color] {
        hexes.map { hex in
            let base = Color(hex: hex)
            return scheme == .dark ? base : base.mix(with: .white, by: 0.62)
        }
    }

    var swatch: LinearGradient {
        let colors = colors(for: .dark)
        return LinearGradient(colors: [colors[1], colors[4], colors[5]], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// A slowly drifting mesh gradient that gives the glass something to refract.
struct Backdrop: View {
    @AppStorage(SettingsKey.palette) private var palette: BackdropPalette = .aurora
    @AppStorage(SettingsKey.animateBackdrop) private var animate = true
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isAnimated = animate && !reduceMotion
        let colors = palette.colors(for: colorScheme)

        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !isAnimated)) { context in
            let time = isAnimated ? context.date.timeIntervalSinceReferenceDate : 0
            MeshGradient(width: 3, height: 3, points: Self.points(at: time), colors: colors)
        }
        .ignoresSafeArea()
    }

    private static func points(at time: Double) -> [SIMD2<Float>] {
        let t = Float(time)
        var points: [SIMD2<Float>] = []
        points.reserveCapacity(9)

        // Corners stay put, edge points slide along their edge, the centre point wanders.
        points.append(SIMD2<Float>(0, 0))
        points.append(SIMD2<Float>(0.5 + 0.06 * sin(t * 0.30), 0))
        points.append(SIMD2<Float>(1, 0))

        points.append(SIMD2<Float>(0, 0.5 + 0.06 * cos(t * 0.27 + 1)))
        points.append(SIMD2<Float>(0.5 + 0.08 * sin(t * 0.40 + 2), 0.5 + 0.08 * cos(t * 0.33 + 3)))
        points.append(SIMD2<Float>(1, 0.5 + 0.06 * sin(t * 0.35 + 2)))

        points.append(SIMD2<Float>(0, 1))
        points.append(SIMD2<Float>(0.5 + 0.06 * cos(t * 0.31 + 3), 1))
        points.append(SIMD2<Float>(1, 1))
        return points
    }
}

// MARK: - Liquid Glass helpers

private func makeGlass(tint: Color? = nil, interactive: Bool = false) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

extension View {
    /// A large content panel made of regular Liquid Glass.
    func glassPanel(cornerRadius: Double = 28, tint: Color? = nil) -> some View {
        glassEffect(makeGlass(tint: tint), in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    func glassCapsule(tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(makeGlass(tint: tint, interactive: interactive), in: Capsule())
    }
}

/// A small tinted label. Deliberately *not* glass, so it can sit on a glass panel without stacking effects.
struct TintChip: View {
    let title: String
    var systemImage: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(tint.opacity(0.2), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 0.75))
    }
}

/// Title + subtitle used at the top of screens.
struct ScreenHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.bold())
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
