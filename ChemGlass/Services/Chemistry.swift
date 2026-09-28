import Foundation

// MARK: - Formula parsing

nonisolated enum FormulaError: LocalizedError, Equatable {
    case empty
    case unexpectedCharacter(Character, position: Int)
    case unknownElement(String)
    case unbalancedParenthesis
    case invalidCount

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Enter a chemical formula."
        case .unexpectedCharacter(let character, let position):
            return "Unexpected “\(character)” at position \(position + 1)."
        case .unknownElement(let symbol):
            return "“\(symbol)” is not a known element symbol."
        case .unbalancedParenthesis:
            return "The brackets in this formula don’t match."
        case .invalidCount:
            return "Counts must be whole numbers greater than zero."
        }
    }
}

/// Parses formulas such as `Ca(OH)2`, `Al2(SO4)3` or `CuSO4·5H2O` into element counts.
nonisolated struct FormulaParser: Sendable {
    let knownSymbols: Set<String>

    private static let maximumCount = 1_000_000_000
    private static let maximumDepth = 64

    nonisolated private struct Cursor {
        let characters: [Character]
        var index = 0

        var peek: Character? { index < characters.count ? characters[index] : nil }
        mutating func advance() { index += 1 }
    }

    func parse(_ input: String) throws -> [String: Int] {
        let normalized = Self.normalize(input)
        guard !normalized.isEmpty else { throw FormulaError.empty }

        var cursor = Cursor(characters: Array(normalized))
        var totals: [String: Int] = [:]

        while true {
            let coefficient = try readCount(&cursor)
            let part = try parseSequence(&cursor, closing: nil, depth: 0)
            guard !part.isEmpty else {
                if let next = cursor.peek {
                    throw FormulaError.unexpectedCharacter(next, position: cursor.index)
                }
                throw FormulaError.empty
            }
            for (symbol, count) in part {
                totals[symbol] = try Self.add(totals[symbol, default: 0], Self.multiply(count, coefficient))
            }

            guard let next = cursor.peek else { break }
            if next == "·" {
                cursor.advance()
                continue
            }
            throw FormulaError.unexpectedCharacter(next, position: cursor.index)
        }
        return totals
    }

    private func parseSequence(_ cursor: inout Cursor, closing: Character?, depth: Int) throws -> [String: Int] {
        guard depth <= Self.maximumDepth else { throw FormulaError.unbalancedParenthesis }
        var result: [String: Int] = [:]

        while let character = cursor.peek {
            if character == "(" || character == "[" {
                let closer: Character = character == "(" ? ")" : "]"
                cursor.advance()
                let inner = try parseSequence(&cursor, closing: closer, depth: depth + 1)
                guard cursor.peek == closer else { throw FormulaError.unbalancedParenthesis }
                cursor.advance()
                let multiplier = try readCount(&cursor)
                for (symbol, count) in inner {
                    result[symbol] = try Self.add(result[symbol, default: 0], Self.multiply(count, multiplier))
                }
            } else if character == ")" || character == "]" {
                if closing == character { break }
                throw FormulaError.unbalancedParenthesis
            } else if character == "·" {
                break
            } else if character.isASCII && character.isUppercase {
                let symbol = try readSymbol(&cursor)
                let count = try readCount(&cursor)
                result[symbol] = try Self.add(result[symbol, default: 0], count)
            } else {
                throw FormulaError.unexpectedCharacter(character, position: cursor.index)
            }
        }
        return result
    }

    private func readSymbol(_ cursor: inout Cursor) throws -> String {
        guard let upper = cursor.peek else { throw FormulaError.empty }
        cursor.advance()

        var lowercase = ""
        var probe = cursor.index
        while probe < cursor.characters.count,
              cursor.characters[probe].isASCII,
              cursor.characters[probe].isLowercase {
            lowercase.append(cursor.characters[probe])
            probe += 1
        }

        var take = min(lowercase.count, 2)
        while take >= 0 {
            let candidate = String(upper) + String(lowercase.prefix(take))
            if knownSymbols.contains(candidate) {
                cursor.index += take
                return candidate
            }
            take -= 1
        }
        throw FormulaError.unknownElement(String(upper) + String(lowercase.prefix(1)))
    }

    /// Reads an optional whole number; returns 1 when there is none.
    private func readCount(_ cursor: inout Cursor) throws -> Int {
        var digits = ""
        while let character = cursor.peek, character.isASCII, character.isNumber {
            digits.append(character)
            cursor.advance()
        }
        guard !digits.isEmpty else { return 1 }
        guard let value = Int(digits), value > 0, value <= Self.maximumCount else {
            throw FormulaError.invalidCount
        }
        return value
    }

    private static func multiply(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        guard !overflow, value <= maximumCount else { throw FormulaError.invalidCount }
        return value
    }

    private static func add(_ lhs: Int, _ rhs: Int) throws -> Int {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        guard !overflow, value <= maximumCount else { throw FormulaError.invalidCount }
        return value
    }

    private static let subscriptDigits: [Character: Character] = [
        "₀": "0", "₁": "1", "₂": "2", "₃": "3", "₄": "4", "₅": "5", "₆": "6", "₇": "7", "₈": "8", "₉": "9",
    ]

    /// Removes whitespace, converts subscript digits and unifies hydrate separators to "·".
    private static func normalize(_ input: String) -> String {
        var output = ""
        for character in input {
            if character.isWhitespace { continue }
            if let digit = subscriptDigits[character] {
                output.append(digit)
                continue
            }
            switch character {
            case ".", "*", "•", "∙", "⋅", "·":
                output.append("·")
            default:
                output.append(character)
            }
        }
        return output
    }
}

// MARK: - Molar mass

nonisolated struct MolarMassResult: Sendable {
    nonisolated struct Line: Identifiable, Sendable {
        let symbol: String
        let name: String
        let count: Int
        let atomicMass: Double
        let fraction: Double

        var id: String { symbol }
        var subtotal: Double { atomicMass * Double(count) }
    }

    let lines: [Line]
    let total: Double
}

nonisolated enum MolarMass {
    static func compute(counts: [String: Int], elements: [String: Element]) -> MolarMassResult {
        let hasCarbon = counts["C"] != nil
        let symbols = counts.keys.sorted { lhs, rhs in
            let left = rank(lhs, hasCarbon: hasCarbon)
            let right = rank(rhs, hasCarbon: hasCarbon)
            return left != right ? left < right : lhs < rhs
        }

        var total = 0.0
        var raw: [(element: Element, count: Int)] = []
        for symbol in symbols {
            guard let element = elements[symbol], let count = counts[symbol] else { continue }
            total += element.mass * Double(count)
            raw.append((element, count))
        }

        let lines = raw.map { entry in
            MolarMassResult.Line(
                symbol: entry.element.symbol,
                name: entry.element.name,
                count: entry.count,
                atomicMass: entry.element.mass,
                fraction: total > 0 ? entry.element.mass * Double(entry.count) / total : 0
            )
        }
        return MolarMassResult(lines: lines, total: total)
    }

    /// Hill order: carbon, then hydrogen, then alphabetical (fully alphabetical without carbon).
    private static func rank(_ symbol: String, hasCarbon: Bool) -> Int {
        guard hasCarbon else { return 2 }
        if symbol == "C" { return 0 }
        if symbol == "H" { return 1 }
        return 2
    }
}

/// Renders `C6H12O6` as `C₆H₁₂O₆` for display.
nonisolated enum FormulaFormatter {
    static func pretty(_ input: String) -> String {
        var output = ""
        var previous: Character?
        var inSubscript = false

        for character in input where !character.isWhitespace {
            if character.isASCII, character.isNumber {
                let followsSymbol = previous.map { $0.isLetter || $0 == ")" || $0 == "]" } ?? false
                if inSubscript || followsSymbol {
                    output += TextCleaner.subscripted(String(character))
                    inSubscript = true
                } else {
                    output.append(character)
                }
            } else {
                inSubscript = false
                output.append(character == "." || character == "*" ? "·" : character)
            }
            previous = character
        }
        return output
    }
}

// MARK: - Electron configuration

nonisolated enum ElectronConfiguration {
    private static let superscriptDigits: [Character] = ["⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]
    private nonisolated(unsafe) static let token = try! NSRegularExpression(pattern: #"([1-9])([spdf])([0-9]{1,2})"#)

    /// `1s2 2s2 2p6` → `1s² 2s² 2p⁶`
    static func superscripted(_ configuration: String) -> String {
        var output = ""
        var afterOrbital = false
        for character in configuration {
            if "spdf".contains(character) {
                afterOrbital = true
                output.append(character)
            } else if afterOrbital, character.isASCII, let digit = character.wholeNumberValue {
                output.append(superscriptDigits[digit])
            } else {
                afterOrbital = false
                output.append(character)
            }
        }
        return output
    }

    /// Electrons per principal shell, or `nil` when the configuration doesn't add up to `atomicNumber`.
    static func shells(from configuration: String, atomicNumber: Int) -> [Int]? {
        let source = configuration as NSString
        let matches = token.matches(in: configuration, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return nil }

        var shells: [Int] = []
        for match in matches {
            guard let shell = Int(source.substring(with: match.range(at: 1))),
                  let count = Int(source.substring(with: match.range(at: 3))) else { return nil }
            while shells.count < shell { shells.append(0) }
            shells[shell - 1] += count
        }
        return shells.reduce(0, +) == atomicNumber ? shells : nil
    }
}
