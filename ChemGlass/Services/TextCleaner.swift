import Foundation

/// Turns the HTML / LaTeX flavoured text of the IUPAC Gold Book into plain Unicode.
///
/// Everything here is pure and `nonisolated`, so it can run on a background thread while
/// the ~6 MB dictionary is being prepared.
nonisolated enum TextCleaner {

    // MARK: - Public API

    static func clean(_ input: String) -> String {
        guard !input.isEmpty else { return input }
        var text = decodeNumericEntities(in: input)
        text = normalizeHTML(text)
        text = normalizeLaTeX(text)
        text = convertScripts(in: text)
        text = decodeNamedEntities(in: text)
        return tidyWhitespace(text)
    }

    /// Case-, diacritic- and width-insensitive form used for searching.
    static func fold(_ input: String) -> String {
        input.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    static func subscripted(_ text: String) -> String {
        String(text.map { subscriptMap[$0] ?? $0 })
    }

    static func superscripted(_ text: String) -> String {
        String(text.map { superscriptMap[$0] ?? $0 })
    }

    // MARK: - Regular expressions (compiled once)

    private static func regex(_ pattern: String, _ options: NSRegularExpression.Options = []) -> NSRegularExpression {
        // Patterns are compile-time constants, so a failure here is a programmer error.
        try! NSRegularExpression(pattern: pattern, options: options)
    }

    private nonisolated(unsafe) static let decimalEntity = regex(#"&#([0-9]{1,7});"#)
    private nonisolated(unsafe) static let hexEntity = regex(#"&#[xX]([0-9A-Fa-f]{1,6});"#)
    private nonisolated(unsafe) static let unicodeNotation = regex(#"U\+([0-9A-Fa-f]{4,6})"#)
    private nonisolated(unsafe) static let lineBreakTag = regex(#"<br\s*/?>"#, .caseInsensitive)
    private nonisolated(unsafe) static let paragraphClose = regex(#"</p\s*>"#, .caseInsensitive)
    private nonisolated(unsafe) static let otherTag = regex(#"</?(?!sub\b|sup\b)[A-Za-z][^>]*>"#, .caseInsensitive)
    private nonisolated(unsafe) static let mathWrapper = regex(
        #"\\(?:mathrm|mathit|mathbf|mathsf|mathtt|mathcal|mathbb|mathfrak|text|textit|textbf|textrm|textsf|texttt|ce|boldsymbol|operatorname|mbox|hbox|rm|it|bf)\s*\{([^{}]*)\}"#
    )
    private nonisolated(unsafe) static let fraction = regex(#"\\[dt]?frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}"#)
    private nonisolated(unsafe) static let squareRoot = regex(#"\\sqrt\s*\{([^{}]*)\}"#)
    private nonisolated(unsafe) static let spacingCommand = regex(#"\\[,;:! ]"#)
    private nonisolated(unsafe) static let namedCommand = regex(#"\\([A-Za-z]+)"#)
    private nonisolated(unsafe) static let escapedCharacter = regex(#"\\([%_$&#{}])"#)
    private nonisolated(unsafe) static let subscriptPattern = regex(
        #"<sub>(.*?)</sub>|_\{([^{}]*)\}"#, [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private nonisolated(unsafe) static let superscriptPattern = regex(
        #"<sup>(.*?)</sup>|\^\{([^{}]*)\}"#, [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private nonisolated(unsafe) static let namedEntity = regex(#"&([A-Za-z][A-Za-z0-9]{1,9});"#)
    private nonisolated(unsafe) static let inlineSpaces = regex(#"[ \t]{2,}"#)
    private nonisolated(unsafe) static let blankLines = regex(#"\n{3,}"#)

    // MARK: - Steps

    private static func decodeNumericEntities(in text: String) -> String {
        guard text.contains("&#") || text.contains("U+") else { return text }
        var result = replace(decimalEntity, in: text) { match, source in
            scalarString(Int(source.substring(with: match.range(at: 1)))) ?? source.substring(with: match.range)
        }
        result = replace(hexEntity, in: result) { match, source in
            scalarString(Int(source.substring(with: match.range(at: 1)), radix: 16)) ?? source.substring(with: match.range)
        }
        result = replace(unicodeNotation, in: result) { match, source in
            scalarString(Int(source.substring(with: match.range(at: 1)), radix: 16)) ?? source.substring(with: match.range)
        }
        return result
    }

    private static func normalizeHTML(_ text: String) -> String {
        guard text.contains("<") else { return text }
        var result = replace(lineBreakTag, in: text) { _, _ in "\n" }
        result = replace(paragraphClose, in: result) { _, _ in "\n\n" }
        result = replace(otherTag, in: result) { _, _ in "" }
        return result
    }

    private static func normalizeLaTeX(_ text: String) -> String {
        guard text.contains("\\") || text.contains("$") else { return text }

        // Strip math delimiters (keeping escaped dollar signs).
        var result = text.replacingOccurrences(of: "\\$", with: "\u{E000}")
        for delimiter in ["$$", "$", "\\(", "\\)", "\\[", "\\]"] {
            result = result.replacingOccurrences(of: delimiter, with: "")
        }
        result = result.replacingOccurrences(of: "\u{E000}", with: "$")

        // Unwrap \mathrm{…}, \text{…} and friends (a few passes handle nesting).
        for _ in 0..<3 {
            let unwrapped = replace(mathWrapper, in: result) { match, source in
                source.substring(with: match.range(at: 1))
            }
            if unwrapped == result { break }
            result = unwrapped
        }

        result = replace(fraction, in: result) { match, source in
            source.substring(with: match.range(at: 1)) + "/" + source.substring(with: match.range(at: 2))
        }
        result = replace(squareRoot, in: result) { match, source in
            "√" + source.substring(with: match.range(at: 1))
        }
        result = result.replacingOccurrences(of: "\\\\", with: "\n")
        result = replace(spacingCommand, in: result) { _, _ in " " }
        result = replace(namedCommand, in: result) { match, source in
            latexSymbols[source.substring(with: match.range(at: 1))] ?? ""
        }
        result = replace(escapedCharacter, in: result) { match, source in
            source.substring(with: match.range(at: 1))
        }
        return result
    }

    private static func convertScripts(in text: String) -> String {
        guard text.contains("_{") || text.contains("^{") || text.localizedCaseInsensitiveContains("<su") else { return text }
        var result = replace(subscriptPattern, in: text) { match, source in
            script(capturedIn: match, of: source, map: subscriptMap, marker: "_")
        }
        result = replace(superscriptPattern, in: result) { match, source in
            script(capturedIn: match, of: source, map: superscriptMap, marker: "^")
        }
        return result
    }

    private static func decodeNamedEntities(in text: String) -> String {
        guard text.contains("&") else { return text }
        return replace(namedEntity, in: text) { match, source in
            namedEntities[source.substring(with: match.range(at: 1))] ?? source.substring(with: match.range)
        }
    }

    private static func tidyWhitespace(_ text: String) -> String {
        var result = replace(inlineSpaces, in: text) { _, _ in " " }
        result = result.replacingOccurrences(of: " \n", with: "\n").replacingOccurrences(of: "\n ", with: "\n")
        result = replace(blankLines, in: result) { _, _ in "\n\n" }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    /// Forward-building regex replacement (much cheaper than mutating a String in place).
    private static func replace(
        _ expression: NSRegularExpression,
        in text: String,
        _ transform: (NSTextCheckingResult, NSString) -> String
    ) -> String {
        let source = text as NSString
        let matches = expression.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return text }

        var result = ""
        var cursor = 0
        for match in matches {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += transform(match, source)
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }

    private static func scalarString(_ value: Int?) -> String? {
        guard let value, let raw = UInt32(exactly: value), let scalar = Unicode.Scalar(raw) else { return nil }
        return String(Character(scalar))
    }

    private static func script(
        capturedIn match: NSTextCheckingResult,
        of source: NSString,
        map: [Character: Character],
        marker: String
    ) -> String {
        let html = match.range(at: 1)
        let latex = match.range(at: 2)
        let range = html.location != NSNotFound ? html : latex
        guard range.location != NSNotFound else { return "" }

        let inner = source.substring(with: range).trimmingCharacters(in: .whitespaces)
        guard !inner.isEmpty else { return "" }

        var converted = ""
        for character in inner {
            guard let mapped = map[character] else {
                // Not every character has a Unicode script form; fall back to a readable marker.
                return inner.count == 1 ? marker + inner : "\(marker)(\(inner))"
            }
            converted.append(mapped)
        }
        return converted
    }

    // MARK: - Tables

    private static let subscriptMap: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋", "\u{2212}": "₋", "=": "₌", "(": "₍", ")": "₎",
        "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ",
        "o": "ₒ", "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "v": "ᵥ", "x": "ₓ",
    ]

    private static let superscriptMap: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "\u{2212}": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
        "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ", "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ",
        "j": "ʲ", "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ", "p": "ᵖ", "r": "ʳ", "s": "ˢ",
        "t": "ᵗ", "u": "ᵘ", "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ",
        "°": "°", "′": "′", "*": "*",
    ]

    private static let latexSymbols: [String: String] = [
        // Greek
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "varepsilon": "ε",
        "zeta": "ζ", "eta": "η", "theta": "θ", "vartheta": "ϑ", "iota": "ι", "kappa": "κ", "lambda": "λ",
        "mu": "μ", "nu": "ν", "xi": "ξ", "pi": "π", "varpi": "ϖ", "rho": "ρ", "varrho": "ϱ", "sigma": "σ",
        "varsigma": "ς", "tau": "τ", "upsilon": "υ", "phi": "φ", "varphi": "φ", "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ",
        "Upsilon": "Υ", "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        // Operators & relations
        "pm": "±", "mp": "∓", "times": "×", "div": "÷", "cdot": "·", "circ": "°",
        "leq": "≤", "le": "≤", "geq": "≥", "ge": "≥", "neq": "≠", "ne": "≠", "approx": "≈", "equiv": "≡",
        "sim": "∼", "propto": "∝", "infty": "∞", "ll": "≪", "gg": "≫", "in": "∈", "cap": "∩", "cup": "∪",
        // Arrows
        "rightarrow": "→", "to": "→", "leftarrow": "←", "leftrightarrow": "↔", "Rightarrow": "⇒",
        "Leftarrow": "⇐", "Leftrightarrow": "⇔", "rightleftharpoons": "⇌",
        // Misc
        "sum": "∑", "prod": "∏", "int": "∫", "partial": "∂", "nabla": "∇", "degree": "°", "prime": "′",
        "AA": "Å", "angstrom": "Å", "ldots": "…", "cdots": "⋯", "dots": "…", "ell": "ℓ", "hbar": "ℏ",
        "langle": "⟨", "rangle": "⟩", "quad": " ", "qquad": " ", "left": "", "right": "",
    ]

    private static let namedEntities: [String: String] = [
        "lt": "<", "gt": ">", "amp": "&", "quot": "\"", "apos": "'", "nbsp": " ",
        "mdash": "—", "ndash": "–", "minus": "−", "deg": "°", "plusmn": "±", "micro": "µ",
        "times": "×", "divide": "÷", "middot": "·", "hellip": "…", "lsquo": "‘", "rsquo": "’",
        "ldquo": "“", "rdquo": "”", "prime": "′", "Prime": "″", "rarr": "→", "larr": "←", "harr": "↔",
        "le": "≤", "ge": "≥", "ne": "≠", "asymp": "≈", "infin": "∞", "radic": "√", "sum": "∑",
        "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε", "zeta": "ζ", "eta": "η",
        "theta": "θ", "iota": "ι", "kappa": "κ", "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ",
        "omicron": "ο", "pi": "π", "rho": "ρ", "sigma": "σ", "tau": "τ", "upsilon": "υ", "phi": "φ",
        "chi": "χ", "psi": "ψ", "omega": "ω",
        "Gamma": "Γ", "Delta": "Δ", "Theta": "Θ", "Lambda": "Λ", "Xi": "Ξ", "Pi": "Π", "Sigma": "Σ",
        "Phi": "Φ", "Psi": "Ψ", "Omega": "Ω",
        "Aring": "Å", "aring": "å", "eacute": "é", "egrave": "è", "ouml": "ö", "uuml": "ü", "auml": "ä",
        "szlig": "ß", "sup2": "²", "sup3": "³", "frac12": "½",
    ]
}
