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

struct Term: Identifiable {
    let id: String
    let title: String
    let status: String
    let definition: String
}

struct Element: Identifiable, Codable {
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

// MARK: - ViewModels
class DictionaryViewModel: ObservableObject {
    @Published var terms: [Term] = []
    @Published var searchText: String = ""
    
    init() { loadJSON() }
    
    func cleanText(_ input: String) -> String {
        var text = input
        
        // 1. Decode HTML Entities that IUPAC uses
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#x2014;", with: "—")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        
        // 2. Convert IUPAC Math Delimiters to standard Markdown LaTeX
        text = text.replacingOccurrences(of: "\\[", with: "$$")
        text = text.replacingOccurrences(of: "\\]", with: "$$")
        text = text.replacingOccurrences(of: "\\(", with: "$")
        text = text.replacingOccurrences(of: "\\)", with: "$")
        
        // 3. Convert HTML Subscripts and Superscripts to LaTeX format so formulas render properly
        text = text.replacingOccurrences(of: "<sub>(.*?)</sub>", with: "_{$1}", options: .regularExpression, range: nil)
        text = text.replacingOccurrences(of: "<sup>(.*?)</sup>", with: "^{$1}", options: .regularExpression, range: nil)
        
        // 4. Convert basic HTML formatting to Markdown
        text = text.replacingOccurrences(of: "<i>", with: "*")
        text = text.replacingOccurrences(of: "</i>", with: "*")
        text = text.replacingOccurrences(of: "<b>", with: "**")
        text = text.replacingOccurrences(of: "</b>", with: "**")
        
        // 5. Safely strip other layout HTML WITHOUT breaking math equations (No wildcard < > strippers!)
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression, range: nil)
        text = text.replacingOccurrences(of: "</p>", with: "\n\n")
        
        let safeTagsToRemove = ["<p>", "<span>", "</span>", "<div>", "</div>", "<a>", "</a>"]
        for tag in safeTagsToRemove {
            text = text.replacingOccurrences(of: tag, with: "")
        }
        
        // Fix odd double spacing
        text = text.replacingOccurrences(of: "  ", with: " ")
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func loadJSON() {
        guard let url = Bundle.main.url(forResource: "goldbook_offline", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(GoldBookRoot.self, from: data)
            let mappedTerms = decoded.terms.list.map { key, value in
                Term(id: key, title: self.cleanText(value.title), status: value.status, definition: self.cleanText(value.definition))
            }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            DispatchQueue.main.async { self.terms = mappedTerms }
        } catch { print("Dictionary Decoding error: \(error)") }
    }
    
    var filteredTerms: [Term] {
        if searchText.isEmpty { return terms }
        return terms.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
}

class PeriodicTableViewModel: ObservableObject {
    @Published var elements: [Element] = []
    
    var maxRow: Int { elements.map { $0.row }.max() ?? 7 }
    var maxCol: Int { elements.map { $0.column }.max() ?? 18 }
    
    init() { loadMendeleevData() }
    
    func loadMendeleevData() {
        guard let url = Bundle.main.url(forResource: "elements_data", withExtension: "json") else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Element].self, from: data)
            DispatchQueue.main.async { self.elements = decoded }
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
                inSuperscript = false
                formatted.append(char)
            } else if char.isLetter {
                inSuperscript = false
                formatted.append(char)
                if "spdf".contains(char.lowercased()) {
                    inSuperscript = true
                }
            } else if char.isNumber {
                if inSuperscript {
                    formatted.append(superscripts[char] ?? char)
                } else {
                    formatted.append(char)
                }
            } else {
                formatted.append(char)
            }
        }
        return formatted
    }
}

// MARK: - Lava Lamp Background
struct LavaLampBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea()
            
            Circle()
                .fill(Color.blue.opacity(0.4))
                .blur(radius: 90)
                .frame(width: 500)
                .offset(x: animate ? 300 : -300, y: animate ? -200 : 300)
            
            Circle()
                .fill(Color.purple.opacity(0.4))
                .blur(radius: 90)
                .frame(width: 400)
                .offset(x: animate ? -300 : 300, y: animate ? 200 : -200)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var dictViewModel = DictionaryViewModel()
    @StateObject private var tableViewModel = PeriodicTableViewModel()
    
    var body: some View {
        ZStack {
            LavaLampBackground()
            
            TabView {
                // TAB 1: DICTIONARY
                NavigationView {
                    List(dictViewModel.filteredTerms) { term in
                        NavigationLink(destination: DetailView(term: term)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(term.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(term.status.capitalized)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .navigationTitle("IUPAC Gold Book")
                    .searchable(text: $dictViewModel.searchText, prompt: "Search chemistry terms...")
                }
                .tabItem { Label("Dictionary", systemImage: "book.fill") }
                
                // TAB 2: PERIODIC TABLE
                NavigationView {
                    PeriodicTableView(viewModel: tableViewModel)
                        .navigationTitle("Periodic Table")
                }
                .tabItem { Label("Elements", systemImage: "atom") }
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 1000, minHeight: 650)
    }
}

// MARK: - Dictionary Detail View
struct DetailView: View {
    let term: Term
    
    var body: some View {
        ZStack {
            Color.clear
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(term.title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Divider().background(Color.white.opacity(0.5))
                    
                    LaTeX(term.definition)
                        .parsingMode(.all)
                    
                    Spacer()
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding()
            }
        }
    }
}

// MARK: - Periodic Table View
struct PeriodicTableView: View {
    @ObservedObject var viewModel: PeriodicTableViewModel
    @State private var selectedElementID: Int? = nil
    
    var body: some View {
        ZStack {
            Color.clear
            
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                VStack(spacing: 6) {
                    ForEach(1...viewModel.maxRow, id: \.self) { r in
                        HStack(spacing: 6) {
                            ForEach(1...viewModel.maxCol, id: \.self) { c in
                                if let element = viewModel.elements.first(where: { $0.row == r && $0.column == c }) {
                                    ElementGlassTile(
                                        element: element,
                                        color: viewModel.colorFor(category: element.category),
                                        nativeConfig: viewModel.formatElectronConfig(element.electronConfigShorthand),
                                        selectedElementID: $selectedElementID
                                    )
                                    .zIndex(selectedElementID == element.id ? 1000 : 1)
                                } else {
                                    Spacer().frame(width: 64, height: 74)
                                }
                            }
                        }
                        .zIndex(selectedElementID != nil ? 1000 : 1)
                    }
                }
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }
}

// MARK: - Liquid Glass Element Tile
struct ElementGlassTile: View {
    let element: Element
    let color: Color
    let nativeConfig: String
    @Binding var selectedElementID: Int?
    
    @State private var isHovered = false
    var isSelected: Bool { selectedElementID == element.id }
    
    var body: some View {
        VStack {
            HStack {
                Text("\(element.id)")
                    .font(.system(size: isSelected ? 16 : 11, weight: .bold, design: .rounded))
                Spacer()
                if isSelected {
                    Text(String(format: "%.3f", element.mass))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .foregroundColor(.white.opacity(0.9))
            .padding([.leading, .top, .trailing], isSelected ? 12 : 6)
            
            Spacer()
            
            Text(element.symbol)
                .font(.system(size: isSelected ? 64 : 24, weight: .heavy, design: .rounded))
                .foregroundColor(color)
            
            Text(element.name)
                .font(.system(size: isSelected ? 22 : 10, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(.white.opacity(0.95))
                .padding(.bottom, isSelected ? 6 : 6)
            
            if isSelected {
                VStack(spacing: 10) {
                    Text(element.category.capitalized)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color.opacity(0.4))
                        .cornerRadius(8)
                    
                    Divider().background(Color.white.opacity(0.4)).padding(.vertical, 4)
                    
                    Text("Electron Configuration")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(nativeConfig)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    Divider().background(Color.white.opacity(0.4)).padding(.vertical, 4)
                    
                    Text(element.details)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity)
                .padding(.bottom, 16)
            }
        }
        .frame(width: isSelected ? 280 : 64, height: isSelected ? 380 : 74)
        .background(.ultraThinMaterial)
        .background(color.opacity(isHovered || isSelected ? 0.35 : 0.1))
        .cornerRadius(isSelected ? 24 : 10)
        .overlay(
            RoundedRectangle(cornerRadius: isSelected ? 24 : 10)
                .stroke(LinearGradient(colors: [color.opacity(0.9), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: color.opacity(isSelected ? 0.8 : (isHovered ? 0.6 : 0.0)), radius: isSelected ? 40 : (isHovered ? 15 : 0), y: isHovered ? 5 : 0)
        .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.25 : 1.0))
        .offset(y: isHovered && !isSelected ? -5 : 0)
        .onHover { hovering in
            if !isSelected {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isHovered = hovering
                }
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                if selectedElementID == element.id {
                    selectedElementID = nil
                } else {
                    selectedElementID = element.id
                }
            }
        }
    }
}
