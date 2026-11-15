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
            .preferredColorScheme(preferredColorScheme)
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

    /// Sign-in keeps the website's dark surface; only the signed-in workspace
    /// follows the reader's Light, Dark, or System preference.
    private var preferredColorScheme: ColorScheme? {
        if case .signedIn = store.access { return customization.colorScheme }
        return .dark
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
        .toolbarBackground(SchoolityPalette.panel, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

struct AccountDetailsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showSettings = false

    var body: some View {
        List {
            SchoolityPageHeader(
                title: "Account",
                isRefreshing: store.isLoadingProfile,
                refresh: { Task { await store.loadProfile(refresh: true) } }
            )
            .schoolityPageRow(top: 8, bottom: 18)

            if let profile = store.profile {
                HStack(spacing: 14) {
                    IconTile(symbol: "person.fill", size: 52, background: .soft)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.system(.title3, weight: .semibold))
                            .foregroundStyle(SchoolityPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(profile.school)
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                        if !profile.grade.isEmpty {
                            Text("Grade \(profile.grade)")
                                .font(.caption)
                                .foregroundStyle(SchoolityPalette.faint)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .schoolityCardRow(bottom: 20)
            } else if store.isLoadingProfile {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(SchoolityPalette.soft)
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 9) {
                        SkeletonBlock(width: 170, height: 16)
                        SkeletonBlock(width: 130, height: 12)
                    }
                    Spacer(minLength: 0)
                }
                .schoolityCardRow(bottom: 20)
            }

            SectionHeading(title: "Student ID")
                .schoolityPageRow(bottom: 10)

            StudentIDSection()
                .schoolityPageRow(bottom: 20)

            Button {
                showSettings = true
            } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: "gearshape.fill", size: 40, background: .field)
                    Text("Settings")
                        .font(.headline)
                        .foregroundStyle(SchoolityPalette.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.faint)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 60)
                .contentShape(Rectangle())
                .schoolityCard(padding: 16)
            }
            .buttonStyle(.plain)
            .schoolityPageRow(bottom: 20)

            Button(role: .destructive) {
                Task { await store.signOut() }
            } label: {
                Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SchoolitySecondaryButtonStyle())
            .schoolityPageRow(bottom: 24)
        }
        .schoolityPageList()
        .task { await store.loadProfile(refresh: store.profile?.studentId == nil) }
        .refreshable { await store.loadProfile(refresh: true) }
        .privacySensitive()
        .navigationTitle("Account")
        .schoolityNavigationChrome()
        .navigationDestination(isPresented: $showSettings) { CustomizationView() }
    }
}
