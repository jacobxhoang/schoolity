import SwiftUI
import BackgroundTasks

@main
struct SchoolityApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = AppStore()
    @StateObject private var customization = CustomizationStore()
    @ObservedObject private var gradeNotifications = GradeNotifications.shared
    var body: some Scene {
        WindowGroup {
            ZStack {
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
            .tint(SchoolityStyle.accent)
            .environmentObject(store)
            .environmentObject(customization)
            .accentColor(Color("ActionAccent"))
            .task { if scenePhase == .active { await store.start() } }
            .task(id: gradeNotifications.enabled && scenePhase == .active && store.access == .signedIn) {
                guard gradeNotifications.enabled, scenePhase == .active, store.access == .signedIn else { return }
                await gradeNotifications.refreshPermission()
                while !Task.isCancelled {
                    await store.checkForGradedAssignments()
                    do { try await Task.sleep(for: .seconds(120)) }
                    catch { return }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    store.enterBackground()
                    if store.access == .signedIn { gradeNotifications.scheduleRefresh() }
                }
                if phase == .active { Task { await store.enterForeground(); await store.start() } }
            }
        }
        .backgroundTask(.appRefresh(GradeNotifications.refreshID)) {
            await gradeNotifications.scheduleRefresh()
            await store.checkForGradedAssignments()
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
                        Image(systemName: store.unlockSymbol).font(.largeTitle).foregroundStyle(SchoolityStyle.accent).accessibilityHidden(true)
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
                            else { Text("Sign in").fontWeight(.semibold) }
                            Spacer()
                        }.frame(minHeight: 44)
                    }
                    .listRowBackground(SchoolityStyle.accent)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .disabled(store.isUnlocking)
                    .accessibilityIdentifier("login.unlock")
                    .accessibilityHint("Use saved sign-in with \(store.unlockMethod)")
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "graduationcap.fill").font(.largeTitle).foregroundStyle(SchoolityStyle.accent).accessibilityHidden(true)
                        Text("Schoolity").font(.largeTitle.bold())
                    }
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
                Section {
                    TextField("Username", text: $username, prompt: Text("Username").foregroundStyle(Color.primary.opacity(0.65)))
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .username)
                        .onSubmit { focus = .password }
                        .accessibilityIdentifier("login.username")
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
                }
                .disabled(store.isLoading || store.signingOut)
                Section {
                    Button(action: signIn) {
                        HStack {
                            Spacer()
                            if store.isLoading || store.signingOut { ProgressView().tint(Color(uiColor: .systemBackground)) }
                            else { Text("Sign in").fontWeight(.semibold) }
                            Spacer()
                        }.frame(minHeight: 44)
                    }
                    .listRowBackground(SchoolityStyle.accent)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || store.isLoading || store.signingOut)
                    .accessibilityIdentifier("login.submit")
                }
                if let error = store.loginError {
                    Section { Label(error, systemImage: "exclamationmark.circle").accessibilityAddTraits(.updatesFrequently) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var customization: CustomizationStore
    private enum WorkspaceTab: Hashable {
        case grades, schedule, inbox, records, account
    }
    @State private var selectedTab: WorkspaceTab = .grades
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { GradebookView() }.tabItem { Label("Grades", systemImage: "menucard.fill") }.tag(WorkspaceTab.grades)
            NavigationStack { ScheduleView() }.tabItem { Label("Schedule", systemImage: "list.bullet.rectangle.portrait.fill") }.tag(WorkspaceTab.schedule)
            NavigationStack { ResourceView(resource: .mail) }.tabItem { Label("Inbox", systemImage: "tray") }.tag(WorkspaceTab.inbox)
            NavigationStack { RecordsView() }.tabItem { Label("Records", systemImage: "list.bullet.rectangle") }.tag(WorkspaceTab.records)
            NavigationStack { AccountDetailsView() }.tabItem { Label("Account", systemImage: "person.crop.circle") }.tag(WorkspaceTab.account)
        }
        .task { await store.preloadWorkspace() }
        .tint(customization.accentColor)
        .accentColor(customization.accentColor)
    }
}

struct AccountDetailsView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            if let profile = store.profile {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48)).foregroundStyle(SchoolityStyle.accent)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name).font(.title3.weight(.semibold))
                            Text(profile.school).font(.footnote).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                    if !profile.grade.isEmpty { InformationRow(title: "Grade", value: profile.grade, symbol: "graduationcap.fill") }
                }
            }
            Section("Student ID") { StudentIDSection() }
            Section {
                NavigationLink {
                    CustomizationView()
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
            }
            Section {
                Button("Sign out", role: .destructive) { Task { await store.signOut() } }
            }
        }
        .schoolityList()
        .task { await store.loadProfile(refresh: store.profile?.studentId == nil) }
        .refreshable { await store.loadProfile(refresh: true) }
        .privacySensitive()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
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
