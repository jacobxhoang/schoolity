import SwiftUI
import UIKit

struct ClassAliasesView: View {
    @EnvironmentObject private var customization: CustomizationStore
    @EnvironmentObject private var store: AppStore
    @State private var editing: ClassAlias?
    @State private var confirmClear = false

    private var classes: [String] {
        var names = Set(store.gradebook?.courses.map(\.name) ?? [])
        for term in store.schedule?.terms ?? [] { names.formUnion(term.classes.map(\.title)) }
        names.formUnion(customization.settings.classLinks.keys)
        return names.filter { !$0.isEmpty }.sorted()
    }

    var body: some View {
        List {
            Section {
                ForEach(customization.settings.aliases) { alias in
                    Button { editing = alias } label: {
                        Label(alias.name, systemImage: alias.symbol).foregroundStyle(.primary)
                    }
                }
                .onDelete { indices in
                    let ids = indices.map { customization.settings.aliases[$0].id }
                    customization.update { settings in for id in ids { settings.removeAlias(id) } }
                }
                Button("Add name and icon", systemImage: "plus") { editing = ClassAlias(name: "", symbol: "studentdesk") }
            } header: { Text("Saved names and icons") } footer: {
                Text("Create a name and icon, then assign it to one or more classes below. Your district’s class names stay unchanged.")
            }
            Section("Assign to classes") {
                ForEach(classes, id: \.self) { title in
                    NavigationLink { ClassLinkPicker(title: title) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                            if let alias = customization.settings.alias(for: title) {
                                Label(alias.name, systemImage: alias.symbol).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if classes.isEmpty { Text("Your classes will appear after grades or schedule finish loading.").foregroundStyle(.secondary) }
            }
        }
        .schoolityList()
        .navigationTitle("Class Names and Icons")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { alias in ClassAliasEditor(alias: alias) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear All", role: .destructive) { confirmClear = true }
                    .disabled(customization.settings.aliases.isEmpty)
            }
        }
        .confirmationDialog("Clear all class customizations?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) { customization.update { $0.aliases = []; $0.classLinks = [:] } }
        }
    }
}

struct ClassLinkPicker: View {
    @EnvironmentObject private var customization: CustomizationStore
    @State private var adding: ClassAlias?
    let title: String
    var body: some View {
        List {
            Section { Text(title).foregroundStyle(.secondary) }
            Section("Display as") {
                Button {
                    customization.update { $0.classLinks[title] = nil }
                } label: {
                    HStack {
                        Label("Original class name", systemImage: "studentdesk")
                        Spacer()
                        if customization.settings.alias(for: title) == nil { Image(systemName: "checkmark") }
                    }
                }
                ForEach(customization.settings.aliases) { alias in
                    Button {
                        customization.update { $0.classLinks[title] = alias.id }
                    } label: {
                        HStack {
                            Label(alias.name, systemImage: alias.symbol)
                            Spacer()
                            if customization.settings.classLinks[title] == alias.id { Image(systemName: "checkmark") }
                        }
                    }
                }
                if customization.settings.aliases.isEmpty {
                    Text("Create a name and icon to customize this class.").foregroundStyle(.secondary)
                }
                Button("Create name and icon", systemImage: "plus") { adding = ClassAlias(name: title, symbol: "studentdesk") }
            }
        }
        .schoolityList()
        .navigationTitle("Class Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $adding) { alias in ClassAliasEditor(alias: alias, linkTo: title) }
    }
}

struct ClassAppearanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var body: some View {
        NavigationStack {
            ClassLinkPicker(title: title)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct ClassAliasEditor: View {
    @EnvironmentObject private var customization: CustomizationStore
    @Environment(\.dismiss) private var dismiss
    @State var alias: ClassAlias
    var linkTo: String? = nil
    private var validSymbol: Bool { UIImage(systemName: alias.symbol) != nil }
    private let symbols = ["studentdesk", "book.fill", "books.vertical.fill", "pencil", "pencil.and.ruler.fill",
                           "function", "number", "x.squareroot", "chart.xyaxis.line", "atom", "flask.fill",
                           "leaf.fill", "globe.americas.fill", "globe", "clock.fill", "building.columns.fill",
                           "text.book.closed.fill", "character.book.closed.fill", "quote.bubble.fill", "theatermasks.fill",
                           "paintpalette.fill", "music.note", "pianokeys", "guitars.fill", "camera.fill",
                           "desktopcomputer", "chevron.left.forwardslash.chevron.right", "cpu", "wrench.and.screwdriver.fill",
                           "hammer.fill", "figure.run", "sportscourt.fill", "basketball.fill", "soccerball",
                           "heart.fill", "cross.case.fill", "fork.knife", "graduationcap.fill", "star.fill", "sparkles"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Class display name", text: $alias.name)
                        .accessibilityIdentifier("alias.name")
                    Label(alias.name.isEmpty ? "Preview" : alias.name, systemImage: validSymbol ? alias.symbol : "questionmark")
                        .font(.headline)
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
                        ForEach(symbols, id: \.self) { symbol in
                            Button { alias.symbol = symbol } label: {
                                Image(systemName: symbol).font(.system(size: 24))
                                    .frame(minWidth: 44, minHeight: 44)
                                    .background(alias.symbol == symbol ? Color.accentColor.opacity(0.15) : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(symbol.replacingOccurrences(of: ".", with: " "))
                            .accessibilityAddTraits(alias.symbol == symbol ? .isSelected : [])
                        }
                    }
                }
                Section {
                    TextField("SF Symbol name", text: $alias.symbol)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    if !validSymbol { Text("Choose an icon supported on this iPhone.").foregroundStyle(.secondary) }
                } header: { Text("Custom symbol") } footer: {
                    Text("You can also enter the name of any SF Symbol available on this device.")
                }
            }
            .navigationTitle("Name and Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        alias.name = alias.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        customization.saveAlias(alias)
                        if let linkTo { customization.update { $0.classLinks[linkTo] = alias.id } }
                        dismiss()
                    }.disabled(alias.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !validSymbol)
                }
            }
        }
    }
}
