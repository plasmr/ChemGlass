[README.md](https://github.com/user-attachments/files/32734099/README.md)
# ChemGlass

A native macOS chemistry reference built with SwiftUI and Liquid Glass (macOS 26).

## Features

- **Dictionary** – the offline IUPAC Gold Book with sectioned A–Z list, debounced background search
  (titles or full definitions), status filter, favorites, personal notes, copy / share / open on iupac.org.
- **Periodic Table** – colour by category, block or a heat-map of electronegativity / radius / mass; click a
  legend chip to spotlight a family; filter by name, symbol or number; inspector with properties,
  oxidation states, electron configuration and a Bohr-style shell diagram.
- **Trends** – interactive Swift Charts view of electronegativity, atomic radius and atomic mass.
- **Molar Mass** – formula parser (brackets, hydrates like `CuSO4·5H2O`), percent composition donut chart,
  and gram ⇄ mole ⇄ particle conversion.
- **Quiz** – symbols, names, families and Gold Book definitions, with streaks (keys 1–4 to answer).
- **Library** – favorites, notes and recently viewed items (stored in Application Support).
- **Quick Search (⌘K)** – jump to any element, term or section. ⌘1–⌘6 switch sections.
- **Settings (⌘,)** – theme, animated mesh-gradient backdrop palettes, definition text size.

## Architecture

```
ChemGlass/
  Models/     Element, ElementCategory, Term (+ Gold Book DTOs)
  Services/   TextCleaner, DataLoader, Chemistry (formula parser, molar mass, electron shells)
  Stores/     AppModel, DictionaryModel, LibraryStore   (@Observable)
  Design/     Liquid Glass helpers, mesh-gradient Backdrop, palettes, settings keys
  Views/      Dictionary, Elements, Trends, Calculator, Quiz, Library, Palette, Settings
```

Data decoding, text cleaning and dictionary filtering run off the main actor (`@concurrent`), so the
6 MB Gold Book no longer blocks launch. Pure logic (`nonisolated`) is covered by tests in `ChemGlassTests`.

## Requirements

Xcode 26.2+, macOS 26.2+. The `LaTeXSwiftUI` package reference from the original project is no longer used
by the code and can be removed from the project's package dependencies.
