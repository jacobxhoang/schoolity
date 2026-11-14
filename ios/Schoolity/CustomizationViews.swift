import SwiftUI

struct CustomizationView: View {
    var body: some View {
        List {
            Section("Customization") {
                NavigationLink { GradeColorsView() } label: { Label("Grade Colors", systemImage: "paintpalette.fill") }
                NavigationLink { ClassAliasesView() } label: { Label("Class Names and Icons", systemImage: "studentdesk") }
                NavigationLink { AccentColorsView() } label: { Label("Accent Color", systemImage: "paintbrush.fill") }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AccentColorsView: View {
    @EnvironmentObject private var customization: CustomizationStore
    var body: some View {
        List {
            Section {
                ColorPicker("Custom color", selection: Binding(
                    get: { customization.accentColor },
                    set: { color in customization.update { $0.accent = StoredColor(color) } }
                ), supportsOpacity: false)
                Button("Use Schoolity default") { customization.update { $0.accent = nil } }
            }
            Section("Colors") {
                ForEach(NamedColor.accents) { choice in
                    Button {
                        customization.update { $0.accent = choice.stored }
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(choice.stored.color).frame(width: 24, height: 24)
                            Text(choice.name).foregroundStyle(.primary)
                            Spacer()
                            if customization.settings.accent == choice.stored { Image(systemName: "checkmark") }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GradeColorsView: View {
    @EnvironmentObject private var customization: CustomizationStore
    @State private var draft = CustomizationSettings()
    @State private var loaded = false

    var body: some View {
        List {
            Section {
                Toggle("Use custom grade colors", isOn: $draft.gradeColorsEnabled)
                ColorPicker("Default / ungraded", selection: Binding(
                    get: { draft.defaultGradeColor.color }, set: { draft.defaultGradeColor = StoredColor($0) }
                ), supportsOpacity: false)
            }
            Section {
                ForEach($draft.gradeRules) { $rule in
                    VStack(alignment: .leading, spacing: 12) {
                        Stepper("Minimum score: \(Int(rule.minimum))%", value: $rule.minimum, in: 0...100, step: 1)
                        ColorPicker("Color", selection: Binding(
                            get: { rule.color.color }, set: { rule.color = StoredColor($0) }
                        ), supportsOpacity: false)
                    }.padding(.vertical, 6)
                }
                .onDelete { draft.gradeRules.remove(atOffsets: $0) }
                Button("Add score threshold", systemImage: "plus") {
                    draft.gradeRules.append(GradeColorRule(minimum: 0, color: draft.defaultGradeColor))
                }
                Button("Reset grade colors", role: .destructive) {
                    draft.gradeColorsEnabled = false
                    draft.gradeRules = GradeColorRule.defaults
                    draft.defaultGradeColor = StoredColor(hex: 0x737373)
                }
            } header: { Text("Score thresholds") } footer: {
                Text("The highest threshold at or below a score determines its color. Swipe a threshold to delete it. Colors do not change grade calculations.")
            }
        }
        .listStyle(.inset)
        .navigationTitle("Grade Colors")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded { draft = customization.settings; loaded = true }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    customization.update {
                        $0.gradeColorsEnabled = draft.gradeColorsEnabled
                        $0.gradeRules = draft.gradeRules
                        $0.defaultGradeColor = draft.defaultGradeColor
                    }
                }
                .disabled(draft.gradeColorsEnabled == customization.settings.gradeColorsEnabled &&
                          draft.gradeRules == customization.settings.gradeRules &&
                          draft.defaultGradeColor == customization.settings.defaultGradeColor)
            }
        }
    }
}
