import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system
    @AppStorage(SettingsKey.palette) private var palette: BackdropPalette = .aurora
    @AppStorage(SettingsKey.animateBackdrop) private var animateBackdrop = true
    @AppStorage(SettingsKey.definitionFontSize) private var fontSize = 20.0

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Backdrop") {
                    HStack(spacing: 12) {
                        ForEach(BackdropPalette.allCases) { option in
                            Button {
                                palette = option
                            } label: {
                                Circle()
                                    .fill(option.swatch)
                                    .frame(width: 26, height: 26)
                                    .overlay {
                                        if palette == option {
                                            Circle().strokeBorder(Color.white, lineWidth: 2.5)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .help(option.title)
                            .accessibilityLabel(option.title)
                        }
                    }
                }

                Toggle("Animate backdrop", isOn: $animateBackdrop)
            }

            Section("Reading") {
                LabeledContent("Definition text size") {
                    HStack {
                        Slider(value: $fontSize, in: 14...40, step: 1)
                            .frame(width: 180)
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
                Text("Sodium chloride: an ionic compound of formula NaCl.")
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Data", value: "IUPAC Gold Book (offline) · 118 elements")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .preferredColorScheme(appearance.colorScheme)
    }
}
