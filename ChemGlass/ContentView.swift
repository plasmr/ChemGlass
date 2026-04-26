import SwiftUI
import Combine
import Foundation
import LaTeXSwiftUI

// MARK: - Models
struct GoldBookRoot: Codable {
    let terms: TermList
}

struct TermList: Codable {
    let list: [String: TermData]
}

struct TermData: Codable {
    let title: String
    let status: String
    let definition: String
}

struct Term: Identifiable, Hashable {
    let id: String
    let title: String
    let status: String
    let definition: String
}

struct Element: Identifiable, Codable, Hashable {
    let id: Int
    let symbol: String
    let name: String
    let mass: Double
    let category: String
    let row: Int
    let column: Int
    let atomicRadius: Double?
    let electronegativity: Double?
    let electronConfigShorthand: String
    let block: String
    let commonIons: String
    let details: String
}

// MARK: - App Settings Engine
class AppSettings: ObservableObject {
    @Published var themePreference: Int = 2
    @Published var definitionFontSize: Double = 28.0
    @Published var lavaTheme: String = "Neon"
    @Published var glassOpacity: Double = 0.3
    
    var colorScheme: ColorScheme? {
        if themePreference == 1 { return .light }
        if themePreference == 2 { return .dark }
        return nil
    }
}

// MARK: - ViewModels
class DictionaryViewModel: ObservableObject {
    @Published var terms: [Term] = []
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .aToZ
    @Published var statusFilter: String = "All"
    
    let subMap: [Character: String] = ["0":"₀", "1":"₁", "2":"₂", "3":"₃", "4":"₄", "5":"₅", "6":"₆", "7":"₇", "8":"₈", "9":"₉", "+":"₊", "-":"₋", "=":"₌", "(":"₍", ")":"₎", "a":"ₐ", "e":"ₑ", "h":"ₕ", "i":"ᵢ", "j":"ⱼ", "k":"ₖ", "l":"ₗ", "m":"ₘ", "n":"ₙ", "o":"ₒ", "p":"ₚ", "r":"ᵣ", "s":"ₛ", "t":"ₜ", "u":"ᵤ", "v":"ᵥ", "x":"ₓ"]
    
    let supMap: [Character: String] = ["0":"⁰", "1":"¹", "2":"²", "3":"³", "4":"⁴", "5":"⁵", "6":"⁶", "7":"⁷", "8":"⁸", "9":"⁹", "+":"⁺", "-":"⁻", "=":"₌", "(":"⁽", ")":"⁾", "n":"ⁿ", "i":"ⁱ", "a":"ᵃ", "b":"ᵇ", "c":"ᶜ", "d":"ᵈ", "e":"ᵉ", "f":"ᶠ", "g":"ᵍ", "h":"ʰ", "k":"ᵏ", "m":"ᵐ", "o":"ᵒ", "p":"ᵖ", "r":"ʳ", "s":"ˢ", "t":"ᵗ", "u":"ᵘ", "v":"ᵛ", "w":"ʷ", "x":"ˣ", "y":"ʸ", "z":"ᶻ"]
    
    let latexToUnicode: [String: String] = [
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ", "\\epsilon": "ε", "\\varepsilon": "ε",
        "\\zeta": "ζ", "\\eta": "η", "\\theta": "θ", "\\vartheta": "ϑ", "\\iota": "ι", "\\kappa": "κ", "\\lambda": "λ",
        "\\mu": "μ", "\\nu": "ν", "\\xi": "ξ", "\\pi": "π", "\\varpi": "ϖ", "\\rho": "ρ", "\\varrho": "ϱ", "\\sigma": "σ",
        "\\varsigma": "ς", "\\tau": "τ", "\\upsilon": "υ", "\\phi": "φ", "\\varphi": "φ", "\\chi": "χ", "\\psi": "ψ", "\\omega": "ω",
        "\\Gamma": "Γ", "\\Delta": "Δ", "\\Theta": "Θ", "\\Lambda": "Λ", "\\Xi": "Ξ", "\\Pi": "Π",
        "\\Sigma": "Σ", "\\Upsilon": "Υ", "\\Phi": "Φ", "\\Psi": "Ψ", "\\Omega": "Ω",
        "\\pm": "±", "\\mp": "∓", "\\times": "×", "\\div": "÷", "\\cdot": "·", "\\circ": "°",
        "\\leq": "≤", "\\geq": "≥", "\\neq": "≠", "\\approx": "≈", "\\equiv": "≡", "\\infty": "∞",
        "\\rightarrow": "→", "\\leftarrow": "←", "\\leftrightarrow": "↔", "\\Rightarrow": "⇒",
        "\\Leftarrow": "⇐", "\\Leftrightarrow": "⇔", "\\sum": "∑", "\\prod": "∏", "\\int": "∫",
        "\\partial": "∂", "\\nabla": "∇", "\\degree": "°", "\\prime": "′", "\\AA": "Å",
        "^{\\circ}": "°", "^{\\prime}": "′", "\\%": "%", "\\_": "_"
    ]
    
    enum SortOption {
        case aToZ, zToA
    }
    
    init() { loadJSON() }
    
    var availableStatuses: [String] {
        var statuses = Array(Set(terms.map { $0.status.capitalized })).sorted()
        statuses.insert("All", at: 0)
        return statuses
    }
    
    func cleanText(_ input: String) -> String {
        var text = input
        
        // 1. DYNAMIC UNICODE ENGINE: Replaces &#1234;, &#x1A;, and U+XXXX natively
        // Decodes Decimal HTML (e.g., &#384;)
        if let decRegex = try? NSRegularExpression(pattern: "&#([0-9]+);", options: []) {
            let matches = decRegex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text), let numRange = Range(match.range(at: 1), in: text),
                   let code = Int(String(text[numRange])), let scalar = UnicodeScalar(code) {
                    text.replaceSubrange(range, with: String(Character(scalar)))
                }
            }
        }
        
        // Decodes Hexadecimal HTML & U+ codes (e.g., &#x0180;, U+0180)
        if let hexRegex = try? NSRegularExpression(pattern: "(?:&#x|U\\+)([0-9A-Fa-f]+);?", options: []) {
            let matches = hexRegex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            for match in matches.reversed() {
                if let range = Range(match.range, in: text), let numRange = Range(match.range(at: 1), in: text),
                   let code = Int(String(text[numRange]), radix: 16), let scalar = UnicodeScalar(code) {
                    text.replaceSubrange(range, with: String(Character(scalar)))
                }
            }
        }

        // Basic Named Entities
        let namedEntities = ["&lt;": "<", "&gt;": ">", "&amp;": "&", "&quot;": "\"", "&apos;": "'", "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&deg;": "°", "&plusmn;": "±", "&micro;": "µ"]
        for (entity, char) in namedEntities {
            text = text.replacingOccurrences(of: entity, with: char)
        }
        
        // 2. Formatting destruction (Prevents tiny italics)
        let formatTags = ["<i>", "</i>", "<em>", "</em>", "<b>", "</b>", "<strong>", "</strong>"]
        for tag in formatTags {
            text = text.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
        }
        
        // 3. Greek & Math Symbol Translation
        for (latexCommand, unicodeChar) in latexToUnicode {
            text = text.replacingOccurrences(of: latexCommand, with: unicodeChar)
        }
        
        // 4. Subscript and Superscript parsing (HTML and LaTeX variants)
        let subPatterns = ["<sub>(.*?)</sub>", "_\\{([^}]+)\\}"]
        for pattern in subPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches.reversed() {
                    if let fullRange = Range(match.range, in: text), let innerRange = Range(match.range(at: 1), in: text) {
                        let innerText = String(text[innerRange])
                        let converted = innerText.map { char -> String in subMap[char] ?? String(char) }.joined()
                        text.replaceSubrange(fullRange, with: converted)
                    }
                }
            }
        }
        
        let supPatterns = ["<sup>(.*?)</sup>", "\\^\\{([^}]+)\\}"]
        for pattern in supPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches.reversed() {
                    if let fullRange = Range(match.range, in: text), let innerRange = Range(match.range(at: 1), in: text) {
                        let innerText = String(text[innerRange])
                        let converted = innerText.map { char -> String in supMap[char] ?? String(char) }.joined()
                        text.replaceSubrange(fullRange, with: converted)
                    }
                }
            }
        }
        
        // 5. Layout and Safe Stripping
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
        
        let safeTagsToRemove = ["<p>", "<span>", "</span>", "<div>", "</div>", "<a>", "</a>", "<sub>", "</sub>", "<sup>", "</sup>"]
        for tag in safeTagsToRemove {
            text = text.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
        }
        
        // 6. Strip LaTeX Math delimiters safely
        let mathDelimiters = ["$$", "$", "\\(", "\\)", "\\[", "\\]"]
        for delim in mathDelimiters {
            text = text.replacingOccurrences(of: delim, with: "")
        }
        
        return text.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func loadJSON() {
        guard let url = Bundle.main.url(forResource: "goldbook_offline", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(GoldBookRoot.self, from: data)
            let mappedTerms = decoded.terms.list.map { key, value in
                Term(id: key, title: self.cleanText(value.title).capitalized, status: value.status, definition: self.cleanText(value.definition))
            }
            DispatchQueue.main.async { self.terms = mappedTerms }
        } catch { print("Dictionary Decoding error: \(error)") }
    }
    
    var filteredTerms: [Term] {
        var result = terms
        if statusFilter != "All" { result = result.filter { $0.status.caseInsensitiveCompare(statusFilter) == .orderedSame } }
        if !searchText.isEmpty { result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }
        result.sort { sortOption == .aToZ ? $0.title < $1.title : $0.title > $1.title }
        return result
    }
}

class PeriodicTableViewModel: ObservableObject {
    @Published var elements: [Element] = []
    @Published var gridMap: [String: Element] = [:]
    
    var maxRow: Int { elements.map { $0.row }.max() ?? 7 }
    var maxCol: Int { elements.map { $0.column }.max() ?? 18 }
    
    init() { loadMendeleevData() }
    
    func loadMendeleevData() {
        guard let url = Bundle.main.url(forResource: "elements_data", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Element].self, from: data)
            DispatchQueue.main.async {
                self.elements = decoded
                var newMap: [String: Element] = [:]
                for el in decoded {
                    newMap["\(el.row)-\(el.column)"] = el
                }
                self.gridMap = newMap
            }
        } catch { print("Elements Decoding error: \(error)") }
    }
    
    func colorFor(category: String) -> Color {
        let cat = category.lowercased()
        if cat.contains("nonmetal") && !cat.contains("halogen") && !cat.contains("noble") { return .green }
        if cat.contains("noble gas") { return .purple }
        if cat.contains("alkali metal") { return .orange }
        if cat.contains("alkaline earth") { return .yellow }
        if cat.contains("metalloid") { return .teal }
        if cat.contains("halogen") { return .cyan }
        if cat.contains("transition metal") { return .blue }
        if cat.contains("post-transition metal") { return .indigo }
        if cat.contains("lanthanide") { return .pink }
        if cat.contains("actinide") { return .red }
        return .gray
    }
    
    func formatElectronConfig(_ config: String) -> String {
        let superscripts: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
        var formatted = ""
        var inSuperscript = false
        
        for char in config {
            if char.isWhitespace {
                inSuperscript = false; formatted.append(char)
            } else if char.isLetter {
                inSuperscript = false; formatted.append(char)
                if "spdf".contains(char.lowercased()) { inSuperscript = true }
            } else if char.isNumber {
                if inSuperscript { formatted.append(superscripts[char] ?? char) } else { formatted.append(char) }
            } else { formatted.append(char) }
        }
        return formatted
    }
}

// MARK: - Environmental Background
struct FluidGlassBackground: View {
    @ObservedObject var settings: AppSettings
    @State private var animate = false
    
    var colors: [Color] {
        switch settings.lavaTheme {
        case "Sunset": return [.red, .orange, .yellow]
        case "Ocean": return [.blue, .cyan, .mint]
        case "Forest": return [.green, .mint, .teal]
        default: return [.blue, .purple, .teal] // Neon
        }
    }
    
    var body: some View {
        ZStack {
            Color.primary.opacity(0.05).ignoresSafeArea()
            
            Circle()
                .fill(colors[0].opacity(0.5))
                .blur(radius: 120)
                .frame(width: 600)
                .offset(x: animate ? 400 : -400, y: animate ? -300 : 400)
            
            Circle()
                .fill(colors[1].opacity(0.5))
                .blur(radius: 120)
                .frame(width: 500)
                .offset(x: animate ? -400 : 400, y: animate ? 300 : -300)
                
            Circle()
                .fill(colors[2].opacity(0.4))
                .blur(radius: 150)
                .frame(width: 500)
                .offset(x: animate ? 200 : -200, y: animate ? 200 : -200)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Main Application View
struct ContentView: View {
    @StateObject private var dictViewModel = DictionaryViewModel()
    @StateObject private var tableViewModel = PeriodicTableViewModel()
    @StateObject private var settings = AppSettings()
    
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            FluidGlassBackground(settings: settings)
            
            TabView {
                DictionarySplitView(viewModel: dictViewModel, settings: settings, showSettings: $showSettings)
                    .tabItem { Label("Dictionary", systemImage: "text.book.closed.fill") }
                    .tag(0)
                
                PeriodicTableContainer(viewModel: tableViewModel, settings: settings, showSettings: $showSettings)
                    .tabItem { Label("Elements", systemImage: "atom") }
                    .tag(1)
            }
            .preferredColorScheme(settings.colorScheme)
        }
        .frame(minWidth: 1100, minHeight: 750)
        .sheet(isPresented: $showSettings) {
            SettingsGlassView(settings: settings)
        }
    }
}

// MARK: - Settings Glass Modal
struct SettingsGlassView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss
    @State private var localFontSize: Double = 28.0
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("App Theme", selection: $settings.themePreference) {
                        Text("System").tag(0)
                        Text("Light Mode").tag(1)
                        Text("Dark Mode").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Typography & Readability") {
                    VStack(alignment: .leading) {
                        Text("Definition Font Size: \(Int(localFontSize))pt")
                        Slider(value: $localFontSize, in: 16...60, step: 1) { editing in
                            if !editing { settings.definitionFontSize = localFontSize }
                        }
                    }
                }
                
                Section("Liquid Glass Customization") {
                    Picker("Lava Lamp Theme", selection: $settings.lavaTheme) {
                        Text("Neon").tag("Neon")
                        Text("Sunset").tag("Sunset")
                        Text("Ocean").tag("Ocean")
                        Text("Forest").tag("Forest")
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Glass Frosting Opacity")
                        Slider(value: $settings.glassOpacity, in: 0.05...0.8)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(.ultraThinMaterial)
            .navigationTitle("App Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                localFontSize = settings.definitionFontSize
            }
        }
        .frame(width: 450, height: 420)
    }
}

// MARK: - Liquid Glass Dictionary (Split View)
struct DictionarySplitView: View {
    @ObservedObject var viewModel: DictionaryViewModel
    @ObservedObject var settings: AppSettings
    @Binding var showSettings: Bool
    
    @State private var selectedTerm: Term?
    
    var body: some View {
        NavigationSplitView {
            List(viewModel.filteredTerms, selection: $selectedTerm) { term in
                VStack(alignment: .leading, spacing: 6) {
                    Text(term.title)
                        .font(.system(size: 17, weight: .bold, design: .default))
                    Text(term.status.capitalized)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
                .tag(term)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationTitle("IUPAC Dictionary")
            .searchable(text: $viewModel.searchText, prompt: "Search chemistry terms...")
            .toolbar {
                ToolbarItemGroup {
                    Menu {
                        Picker("Sort", selection: $viewModel.sortOption) {
                            Text("A to Z").tag(DictionaryViewModel.SortOption.aToZ)
                            Text("Z to A").tag(DictionaryViewModel.SortOption.zToA)
                        }
                        Picker("Status", selection: $viewModel.statusFilter) {
                            ForEach(viewModel.availableStatuses, id: \.self) { status in
                                Text(status).tag(status)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            
        } detail: {
            if let term = selectedTerm {
                DictionaryDetailGlassView(term: term, settings: settings)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "book.pages")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Select a term to view its definition.")
                        .font(.system(size: 20, weight: .semibold, design: .default))
                        .foregroundColor(.secondary)
                }
            }
        }
        .background(.ultraThinMaterial.opacity(settings.glassOpacity))
    }
}

struct DictionaryDetailGlassView: View {
    let term: Term
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(term.title)
                    .font(.system(size: settings.definitionFontSize * 1.5, weight: .heavy, design: .default))
                
                Divider()
                
                // Pure Native Rendering with San Francisco Pro
                Text(term.definition)
                    .font(.system(size: settings.definitionFontSize, weight: .regular, design: .default))
                    .lineSpacing(8)
                
                Spacer()
            }
            .padding(40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .background(Color.primary.opacity(settings.glassOpacity * 0.5))
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(LinearGradient(colors: [.primary.opacity(0.4), .clear, .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(32)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Liquid Glass Periodic Table
struct PeriodicTableContainer: View {
    @ObservedObject var viewModel: PeriodicTableViewModel
    @ObservedObject var settings: AppSettings
    @Binding var showSettings: Bool
    
    @State private var selectedElementID: Int? = nil
    
    // Calculates which row currently contains the expanded element to fix clipping
    var activeRow: Int {
        if let id = selectedElementID, let el = viewModel.elements.first(where: { $0.id == id }) {
            return el.row
        }
        return -1
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear
                
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(spacing: 8) {
                        ForEach(1...viewModel.maxRow, id: \.self) { r in
                            HStack(spacing: 8) {
                                ForEach(1...viewModel.maxCol, id: \.self) { c in
                                    if let element = viewModel.gridMap["\(r)-\(c)"] {
                                        LiquidGlassElementTile(
                                            element: element,
                                            color: viewModel.colorFor(category: element.category),
                                            nativeConfig: viewModel.formatElectronConfig(element.electronConfigShorthand),
                                            settings: settings,
                                            selectedElementID: $selectedElementID
                                        )
                                        // Tile-level Z-Index
                                        .zIndex(selectedElementID == element.id ? 9999 : 1)
                                    } else {
                                        Spacer().frame(width: 70, height: 80)
                                    }
                                }
                            }
                            // FIXED Z-INDEX CLIPPING BUG: Active row is forced absolute top layer
                            .zIndex(r == activeRow ? 9999 : Double(100 - r))
                        }
                    }
                    .padding(50)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .scrollClipDisabled()
            }
            .navigationTitle("Periodic Table")
            .toolbar {
                ToolbarItem {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
    }
}

// MARK: - Custom Liquid Glass Component
struct LiquidGlassElementTile: View {
    let element: Element
    let color: Color
    let nativeConfig: String
    @ObservedObject var settings: AppSettings
    @Binding var selectedElementID: Int?
    
    @State private var isHovered = false
    var isSelected: Bool { selectedElementID == element.id }
    
    var body: some View {
        VStack {
            HStack {
                Text("\(element.id)")
                    .font(.system(size: isSelected ? 18 : 12, weight: .bold, design: .default))
                Spacer()
                if isSelected {
                    Text(String(format: "%.3f", element.mass))
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                }
            }
            .padding([.leading, .top, .trailing], isSelected ? 16 : 8)
            
            Spacer()
            
            Text(element.symbol)
                .font(.system(size: isSelected ? 72 : 26, weight: .heavy, design: .default))
                .foregroundColor(color)
            
            Text(element.name)
                .font(.system(size: isSelected ? 24 : 11, weight: .bold, design: .default))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.bottom, isSelected ? 8 : 8)
            
            if isSelected {
                VStack(spacing: 12) {
                    Text(element.category.capitalized)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(color.opacity(0.3).background(.ultraThinMaterial))
                        .cornerRadius(12)
                    
                    Divider().padding(.vertical, 4)
                    
                    Text("Electron Configuration")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.secondary)
                    
                    Text(nativeConfig)
                        .font(.system(size: 18, weight: .medium, design: .default))
                    
                    Divider().padding(.vertical, 4)
                    
                    Text(element.details)
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .padding(.bottom, 20)
            }
        }
        .frame(width: isSelected ? 320 : 70, height: isSelected ? 440 : 80)
        // Background rendering stabilized to prevent hit-box breaking
        .background(.ultraThinMaterial.opacity(isSelected ? 1 : 0))
        .background(color.opacity(isHovered || isSelected ? settings.glassOpacity * 2 : settings.glassOpacity))
        .cornerRadius(isSelected ? 32 : 16)
        .overlay(
            RoundedRectangle(cornerRadius: isSelected ? 32 : 16)
                .stroke(LinearGradient(colors: [color.opacity(0.8), .primary.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected || isHovered ? color.opacity(0.5) : .clear, radius: isSelected ? 40 : (isHovered ? 20 : 0), y: isHovered ? 10 : 0)
        .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.15 : 1.0))
        .offset(y: isHovered && !isSelected ? -5 : 0)
        // Makes the entire frame tappable, fixing interaction bugs
        .contentShape(Rectangle())
        .onHover { hovering in
            if !isSelected {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovered = hovering
                }
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if selectedElementID == element.id {
                    selectedElementID = nil
                } else {
                    selectedElementID = element.id
                }
            }
        }
    }
}
