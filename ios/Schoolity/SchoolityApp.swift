import SwiftUI

@main
struct SchoolityApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            Group {
                switch store.access {
                case .checking:
                    ProgressView("Opening Schoolity…")
                case .unavailable:
                    ContentUnavailableView {
                        Label("Can’t connect", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(store.startupError ?? "Check your connection and try again.")
                    } actions: {
                        Button("Try again") { Task { await store.restore() } }
                            .buttonStyle(.borderedProminent)
                    }
                case .signedOut: LoginView()
                case .locked: SavedSignInView()
                case .signedIn: WorkspaceView()
                }
            }
            .tint(.primary)
            .environmentObject(store)
            .task { if scenePhase == .active { await store.start() } }
            .privacySensitive()
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { store.enterBackground() }
                if phase == .active { Task { await store.enterForeground(); await store.start() } }
            }
            .overlay {
                if scenePhase != .active {
                    ZStack {
                        Color(uiColor: .systemBackground).ignoresSafeArea()
                        Text("Schoolity").font(.largeTitle.bold())
                    }.accessibilityHidden(true)
                }
            }
        }
    }
}

struct SavedSignInView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: store.unlockSymbol).font(.largeTitle).accessibilityHidden(true)
                        Text("Schoolity").font(.largeTitle.bold())
                    }
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
                Section {
                    Button { Task { await store.unlockSavedSignIn() } } label: {
                        HStack {
                            Spacer()
                            if store.isUnlocking { ProgressView().tint(Color(uiColor: .systemBackground)) }
                            else { Text("Unlock with \(store.unlockMethod)").fontWeight(.semibold) }
                            Spacer()
                        }.frame(minHeight: 44)
                    }
                    .listRowBackground(Color.primary)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .disabled(store.isUnlocking)
                    .accessibilityIdentifier("login.unlock")
                    Button("Sign in again") { store.usePasswordInstead() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("login.usePassword")
                }
                if let error = store.unlockError {
                    Section { Label(error, systemImage: "exclamationmark.circle").accessibilityAddTraits(.updatesFrequently) }
                }
            }
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var store: AppStore
    @State private var username = ""
    @State private var password = ""
    @State private var reveal = false
    @FocusState private var focus: Field?
    private enum Field { case username, password }
    private var canSubmit: Bool { !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty && !store.isLoading && !store.signingOut }

    var body: some View {
        NavigationStack {
            LoginCanvas(editing: focus != nil) {
                if let error = store.loginError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.subheadline).accessibilityAddTraits(.updatesFrequently)
                }
                VStack(spacing: 12) {
                    TextField("Username", text: $username, prompt: Text("Username").foregroundStyle(Color.primary.opacity(0.65)))
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .username)
                        .onSubmit { focus = .password }
                        .accessibilityIdentifier("login.username")
                        .modifier(CredentialFieldStyle(focused: focus == .username))
                    HStack {
                        Group {
                            if reveal { TextField("Password", text: $password, prompt: Text("Password").foregroundStyle(Color.primary.opacity(0.65))) }
                            else { SecureField("Password", text: $password, prompt: Text("Password").foregroundStyle(Color.primary.opacity(0.65))) }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                        .accessibilityIdentifier("login.password")
                        Button { reveal.toggle() } label: {
                            Image(systemName: reveal ? "eye.slash" : "eye").frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(reveal ? "Hide password" : "Show password")
                    }
                    .modifier(CredentialFieldStyle(focused: focus == .password))
                }
                .disabled(store.isLoading || store.signingOut)
                    Button(action: signIn) {
                        HStack {
                            Spacer()
                            if store.isLoading || store.signingOut { ProgressView().tint(Color(uiColor: .systemBackground)) }
                            else { Text("Sign in").fontWeight(.semibold) }
                            Spacer()
                        }.frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                    .background(canSubmit || store.isLoading ? Color.primary : SchoolityStyle.fieldFill, in: RoundedRectangle(cornerRadius: SchoolityStyle.controlRadius))
                    .foregroundStyle(canSubmit || store.isLoading ? Color(uiColor: .systemBackground) : SchoolityStyle.muted)
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("login.submit")
            }
        }
    }

    private func signIn() {
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty, !store.isLoading, !store.signingOut else { return }
        focus = nil
        let submitted = password
        password = ""
        Task { await store.signIn(username: username, password: submitted) }
    }
}

struct WorkspaceView: View {
    @State private var selectedTab = 1
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { OverviewView() }.tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack { GradebookView() }.tabItem { Label("Grades", systemImage: "book.closed.fill") }.tag(1)
            NavigationStack { ResourceView(resource: .schedule) }.tabItem { Label("Schedule", systemImage: "calendar") }.tag(2)
            NavigationStack { ResourceView(resource: .mail) }.tabItem { Label("Inbox", systemImage: "tray") }.tag(3)
            NavigationStack { ResourceView(resource: .documents) }.tabItem { Label("Documents", systemImage: "doc") }.tag(4)
        }
    }
}

struct AccountButton: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAccount = false
    @State private var accountSize: PresentationDetent = .large
    var body: some View {
        Button { accountSize = .large; showAccount = true } label: { Image(systemName: "person.crop.circle").frame(minWidth: 44, minHeight: 44) }
            .accessibilityLabel("Account")
            .sheet(isPresented: $showAccount) {
                NavigationStack {
                    List {
                        if let profile = store.profile {
                            Section {
                                Text(profile.name).font(.headline)
                                Text(profile.school).foregroundStyle(.secondary)
                                if !profile.grade.isEmpty { LabeledContent("Grade", value: profile.grade) }
                            }
                        }
                        Section {
                            NavigationLink {
                                StudentIDView().onAppear { accountSize = .large }
                            } label: { Label("Student ID", systemImage: "barcode") }
                            .accessibilityIdentifier("account.studentID")
                        }
                        Section {
                            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
                        }
                    }
                    .navigationTitle("Account")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAccount = false } } }
                }
                .presentationDetents([.medium, .large], selection: $accountSize)
            }
    }
}

struct FailureRow: View {
    let message: String
    var retry: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.circle")
            Button("Try again", action: retry).frame(minHeight: 44)
        }.padding(.vertical, 4)
    }
}
