import SwiftUI

private enum SettingsRoute: Hashable {
    case gradeColors, classAliases, accentColors, appearance, privacy
}

struct CustomizationView: View {
    @State private var route: SettingsRoute?

    var body: some View {
        List {
            SectionHeading(title: "Customization")
                .schoolityPageRow(top: 8, bottom: 10)
            SettingsLinkRow(title: "Grade Colors", symbol: "paintpalette.fill") { route = .gradeColors }
                .schoolityPageRow(bottom: 8)
            SettingsLinkRow(title: "Class Names and Icons", symbol: "studentdesk") { route = .classAliases }
                .schoolityPageRow(bottom: 8)
            SettingsLinkRow(title: "Accent Color", symbol: "paintbrush.fill") { route = .accentColors }
                .schoolityPageRow(bottom: 20)

            SectionHeading(title: "App")
                .schoolityPageRow(bottom: 10)
            SettingsLinkRow(title: "Appearance", symbol: "circle.lefthalf.filled") { route = .appearance }
                .schoolityPageRow(bottom: 8)
            SettingsLinkRow(title: "Privacy & Connection", symbol: "hand.raised.fill") { route = .privacy }
                .schoolityPageRow(bottom: 20)

            SectionHeading(title: "Notifications")
                .schoolityPageRow(bottom: 10)
            GradeNotificationSettings()
                .schoolityCardRow(bottom: 6, padding: 18)
            Text("Get alerts for newly graded assignments. Checks run while Schoolity is open and when iOS allows background refresh. Reopen and unlock Schoolity after a restart to resume checks.")
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .schoolityPageRow(bottom: 24)
        }
        .schoolityPageList()
        .navigationTitle("Settings")
        .schoolityNavigationChrome()
        .navigationDestination(item: $route) { route in
            switch route {
            case .gradeColors: GradeColorsView()
            case .classAliases: ClassAliasesView()
            case .accentColors: AccentColorsView()
            case .appearance: AppearanceView()
            case .privacy: PrivacyView()
            }
        }
    }
}

private struct SettingsLinkRow: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, size: 36, background: .field)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SchoolityPalette.ink)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(SchoolityText.caption.weight(.semibold))
                    .foregroundStyle(SchoolityPalette.faint)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 56)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .schoolityCard(padding: 4)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

private struct GradeNotificationSettings: View {
    @ObservedObject private var notifications = GradeNotifications.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var requesting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Graded assignments", isOn: Binding(
                get: { notifications.enabled },
                set: { value in
                    requesting = true
                    Task { await notifications.setEnabled(value); requesting = false }
                }
            ))
            .tint(SchoolityPalette.ink)
            .disabled(requesting)
            .accessibilityIdentifier("settings.gradeNotifications")

            if requesting {
                ProgressView("Requesting permission…")
                    .font(SchoolityText.meta)
            }
            if notifications.permissionDenied {
                Text("Notifications are blocked in iOS Settings.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                Button("Open notification settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(SchoolityPalette.ink)
                .frame(minHeight: 44)
            }
            if let error = notifications.error {
                Text(error)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
            }
        }
        .task(id: scenePhase) { await notifications.refreshPermission() }
    }
}

private struct AppearanceView: View {
    @EnvironmentObject private var customization: CustomizationStore

    var body: some View {
        List {
            Section {
                Picker("Appearance", selection: Binding(
                    get: { customization.settings.appearance ?? .system },
                    set: { value in customization.update { $0.appearance = value } }
                )) {
                    ForEach(AppearancePreference.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("System follows the iPhone’s Light or Dark Mode. The sign-in screen keeps its original palette.")
            }
        }
        .schoolityList()
        .navigationTitle("Appearance")
        .schoolityNavigationChrome()
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
            } footer: {
                Text("The default follows the website: black in Light Mode and near-white in Dark Mode. A chosen accent replaces it in the signed-in workspace.")
            }
            Section("Colors") {
                ForEach(NamedColor.accents) { choice in
                    Button {
                        customization.update { $0.accent = choice.stored }
                    } label: {
                        HStack(spacing: 12) {
                            Circle().fill(choice.stored.color).frame(width: 24, height: 24)
                            Text(choice.name).foregroundStyle(SchoolityPalette.ink)
                            Spacer()
                            if customization.settings.accent == choice.stored {
                                Image(systemName: "checkmark").foregroundStyle(SchoolityPalette.ink)
                            }
                        }
                    }
                }
            }
        }
        .schoolityList()
        .navigationTitle("Accent Color")
        .schoolityNavigationChrome()
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
                Text("The highest threshold at or below a score determines its color. Swipe a threshold to delete it.")
            }
        }
        .schoolityList()
        .navigationTitle("Grade Colors")
        .schoolityNavigationChrome()
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
