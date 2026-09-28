import Testing
@testable import ChemGlass

struct FormulaParserTests {
    let parser = FormulaParser(knownSymbols: ["H", "O", "C", "N", "Na", "Cl", "Ca", "Cu", "S", "Al"])

    @Test func parsesSimpleFormula() throws {
        #expect(try parser.parse("H2O") == ["H": 2, "O": 1])
    }

    @Test func parsesTwoLetterSymbols() throws {
        #expect(try parser.parse("NaCl") == ["Na": 1, "Cl": 1])
    }

    @Test func parsesGroups() throws {
        #expect(try parser.parse("Ca(OH)2") == ["Ca": 1, "O": 2, "H": 2])
        #expect(try parser.parse("Al2(SO4)3") == ["Al": 2, "S": 3, "O": 12])
    }

    @Test func parsesHydrates() throws {
        #expect(try parser.parse("CuSO4·5H2O") == ["Cu": 1, "S": 1, "O": 9, "H": 10])
        #expect(try parser.parse("CuSO4.5H2O") == ["Cu": 1, "S": 1, "O": 9, "H": 10])
    }

    @Test func acceptsSubscriptDigits() throws {
        #expect(try parser.parse("H₂O") == ["H": 2, "O": 1])
    }

    @Test func rejectsBadInput() {
        #expect(throws: FormulaError.empty) { try parser.parse("  ") }
        #expect(throws: FormulaError.unknownElement("Xx")) { try parser.parse("Xx") }
        #expect(throws: FormulaError.unbalancedParenthesis) { try parser.parse("(H2O") }
        #expect(throws: FormulaError.unbalancedParenthesis) { try parser.parse("H2O)") }
    }

    @Test func prettyPrintsSubscripts() {
        #expect(FormulaFormatter.pretty("C6H12O6") == "C₆H₁₂O₆")
        #expect(FormulaFormatter.pretty("CuSO4·5H2O") == "CuSO₄·5H₂O")
    }
}

struct TextCleanerTests {
    @Test func convertsHTMLScripts() {
        #expect(TextCleaner.clean("H<sub>2</sub>O") == "H₂O")
        #expect(TextCleaner.clean("10<sup>-3</sup>") == "10⁻³")
    }

    @Test func decodesEntities() {
        #expect(TextCleaner.clean("&#945;-helix") == "α-helix")
        #expect(TextCleaner.clean("a &lt; b &amp; c") == "a < b & c")
    }

    @Test func convertsLaTeX() {
        #expect(TextCleaner.clean("\\alpha \\beta") == "α β")
        #expect(TextCleaner.clean("$E_{\\mathrm{a}}$") == "Eₐ")
        #expect(TextCleaner.clean("$k_{\\mathrm{B}}T$") == "k_BT")
    }

    @Test func foldsForSearching() {
        #expect(TextCleaner.fold("Étoile") == "etoile")
    }
}

struct ElectronConfigurationTests {
    @Test func formatsSuperscripts() {
        #expect(ElectronConfiguration.superscripted("1s2 2s2 2p6") == "1s² 2s² 2p⁶")
    }

    @Test func countsShells() {
        let lead = "1s2 2s2 2p6 3s2 3p6 4s2 3d10 4p6 5s2 4d10 5p6 4f14 5d10 6s2 6p2"
        #expect(ElectronConfiguration.shells(from: lead, atomicNumber: 82) == [2, 8, 18, 32, 18, 4])
        #expect(ElectronConfiguration.shells(from: "1s1", atomicNumber: 1) == [1])
    }

    @Test func rejectsInconsistentData() {
        #expect(ElectronConfiguration.shells(from: "1s2 2s1", atomicNumber: 5) == nil)
        #expect(ElectronConfiguration.shells(from: "", atomicNumber: 1) == nil)
    }
}
