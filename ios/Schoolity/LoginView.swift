import SwiftUI

/// Saved sign-in and school credentials on the website's dark sign-in surface.
/// The workspace follows the chosen appearance; this screen stays dark.
struct SavedSignInView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ZStack {
                LoginBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        LoginTopBar()

                        if typeSize.isAccessibilitySize {
                            Text("Saved sign-in")
                                .font(SchoolityText.sectionTitle)
                                .foregroundStyle(SchoolityLoginPalette.ink)
                                .accessibilityAddTraits(.isHeader)
                        } else {
                            LoginIntro(
                                eyebrow: "Saved sign-in",
                                title: "Welcome back.",
                                deck: "Your school sign-in is saved on this iPhone and protected by \(store.unlockMethod)."
                            )
                        }

                        LoginPanel {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(alignment: .center, spacing: 14) {
                                    Image(systemName: store.unlockSymbol)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(SchoolityLoginPalette.ink)
                                        .frame(width: 48, height: 48)
                                        .background(SchoolityLoginPalette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(SchoolityLoginPalette.line, lineWidth: 1)
                                        }
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Sign in with \(store.unlockMethod)")
                                            .font(.headline)
                                            .foregroundStyle(SchoolityLoginPalette.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("No password needed. Your saved credentials stay in the protected Keychain.")
                                            .font(.footnote)
                                            .foregroundStyle(SchoolityLoginPalette.muted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }

                                Button {
                                    Task { await store.unlockSavedSignIn() }
                                } label: {
                                    HStack(spacing: 8) {
                                        Spacer(minLength: 0)
                                        if store.isUnlocking {
                                            ProgressView().tint(SchoolityLoginPalette.onInk)
                                        }
                                        Text("Sign in")
                                        Spacer(minLength: 0)
                                    }
                                }
                                .buttonStyle(LoginPrimaryButtonStyle())
                                .disabled(store.isUnlocking)
                                .accessibilityIdentifier("login.unlock")
                                .accessibilityLabel("Sign in")
                                .accessibilityHint("Use saved sign-in with \(store.unlockMethod)")

                                Button("Sign in again") { store.usePasswordInstead() }
                                    .buttonStyle(LoginSecondaryButtonStyle())
                                    .accessibilityIdentifier("login.usePassword")

                                if let error = store.unlockError {
                                    LoginNotice(message: error)
                                }
                            }
                        }

                        if !typeSize.isAccessibilitySize {
                            Text("Cancel leaves your saved sign-in for another try.")
                                .font(.caption)
                                .foregroundStyle(SchoolityLoginPalette.faint)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(SchoolityLoginPalette.ink)
            .accentColor(SchoolityLoginPalette.ink)
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
            ZStack {
                LoginBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        LoginTopBar()

                        LoginIntro(
                            eyebrow: "StudentVUE sign-in · Anoka-Hennepin",
                            title: "The Anoka-Hennepin student dashboard.",
                            deck: ""
                        )

                        signInPanel

                        Text("Your gradebook, schedule, attendance and records in one place. Schoolity reads the record your district already keeps, and never changes it.")
                            .font(SchoolityText.body)
                            .foregroundStyle(SchoolityLoginPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Schoolity is an independent student project. It is not affiliated with or endorsed by Anoka-Hennepin Schools or Edupoint.")
                            .font(.caption)
                            .foregroundStyle(SchoolityLoginPalette.faint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(SchoolityLoginPalette.ink)
            .accentColor(SchoolityLoginPalette.ink)
        }
    }

    private var signInPanel: some View {
        LoginPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Sign in")
                        .font(.system(.title3, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(SchoolityLoginPalette.ink)
                    Spacer(minLength: 8)
                    Text("StudentVUE")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(SchoolityLoginPalette.faint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    LoginFieldLabel(text: "Username")
                    TextField(
                        "Username",
                        text: $username,
                        prompt: Text("StudentVUE username").foregroundStyle(SchoolityLoginPalette.faint)
                    )
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focus, equals: .username)
                    .onSubmit { focus = .password }
                    .accessibilityIdentifier("login.username")
                    .modifier(LoginFieldShell())
                }

                VStack(alignment: .leading, spacing: 6) {
                    LoginFieldLabel(text: "Password")
                    HStack(spacing: 6) {
                        Group {
                            if reveal {
                                TextField(
                                    "Password",
                                    text: $password,
                                    prompt: Text("School password").foregroundStyle(SchoolityLoginPalette.faint)
                                )
                            } else {
                                SecureField(
                                    "Password",
                                    text: $password,
                                    prompt: Text("School password").foregroundStyle(SchoolityLoginPalette.faint)
                                )
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                        .accessibilityIdentifier("login.password")
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            reveal.toggle()
                        } label: {
                            Text(reveal ? "Hide" : "Show")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SchoolityLoginPalette.ink)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(reveal ? "Hide password" : "Show password")
                    }
                    .modifier(LoginFieldShell())
                }

                if let error = store.loginError {
                    LoginNotice(message: error)
                }

                Button(action: signIn) {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        if store.isLoading || store.signingOut {
                            ProgressView().tint(SchoolityLoginPalette.onInk)
                        }
                        Text(store.isLoading || store.signingOut ? "Signing in…" : "Sign in")
                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(LoginPrimaryButtonStyle())
                .disabled(
                    username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    password.isEmpty ||
                    store.isLoading ||
                    store.signingOut
                )
                .accessibilityIdentifier("login.submit")

                Text("Use the same username and password as the district portal.")
                    .font(.caption)
                    .foregroundStyle(SchoolityLoginPalette.faint)
                    .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Sign-in pieces

private struct LoginBackdrop: View {
    var body: some View {
        SchoolityLoginPalette.canvas.ignoresSafeArea()
    }
}

private struct LoginTopBar: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("S")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(SchoolityLoginPalette.onInk)
                    .frame(width: 32, height: 32)
                    .background(SchoolityLoginPalette.ink, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .accessibilityHidden(true)
                Text("Schoolity")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(SchoolityLoginPalette.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Schoolity")

            Spacer(minLength: 8)

            NavigationLink {
                PrivacyView()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 12, weight: .medium))
                    Text("Privacy")
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(SchoolityLoginPalette.muted)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct LoginIntro: View {
    let eyebrow: String
    let title: String
    let deck: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Circle()
                    .fill(SchoolityLoginPalette.ink)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.medium))
                    .tracking(0.8)
                    .foregroundStyle(SchoolityLoginPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(SchoolityLoginPalette.panel, in: Capsule())
            .overlay { Capsule().strokeBorder(SchoolityLoginPalette.line, lineWidth: 1) }
            .accessibilityElement(children: .combine)

            Text(title)
                .font(.system(.largeTitle, weight: .semibold))
                .tracking(-1.2)
                .foregroundStyle(SchoolityLoginPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if !deck.isEmpty {
                Text(deck)
                    .font(SchoolityText.body)
                    .foregroundStyle(SchoolityLoginPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct LoginPanel<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SchoolityLoginPalette.panel, in: RoundedRectangle(cornerRadius: SchoolityRadius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SchoolityRadius.large, style: .continuous)
                    .strokeBorder(SchoolityLoginPalette.line, lineWidth: 1)
            }
    }
}

private struct LoginFieldLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(SchoolityLoginPalette.muted)
    }
}

private struct LoginFieldShell: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .foregroundStyle(SchoolityLoginPalette.ink)
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(SchoolityLoginPalette.field, in: RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous)
                    .strokeBorder(SchoolityLoginPalette.line, lineWidth: 1)
            }
    }
}

private struct LoginPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SchoolityLoginPalette.onInk)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(SchoolityLoginPalette.ink, in: RoundedRectangle(cornerRadius: SchoolityRadius.chip, style: .continuous))
                .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
        }
    }
}

private struct LoginSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(SchoolityLoginPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(SchoolityLoginPalette.field, in: RoundedRectangle(cornerRadius: SchoolityRadius.chip, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SchoolityRadius.chip, style: .continuous)
                    .strokeBorder(SchoolityLoginPalette.lineStrong, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct LoginNotice: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SchoolityLoginPalette.muted)
                .accessibilityHidden(true)
            Text(message)
                .font(.footnote)
                .foregroundStyle(SchoolityLoginPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SchoolityLoginPalette.field, in: RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous)
                .strokeBorder(SchoolityLoginPalette.line, lineWidth: 1)
        }
        .accessibilityAddTraits(.updatesFrequently)
    }
}
