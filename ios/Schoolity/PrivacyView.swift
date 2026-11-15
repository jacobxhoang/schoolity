import SwiftUI

/// Mirrors the website's privacy panel for the standalone app, which talks to
/// the district directly and never to a Schoolity server.
struct PrivacyView: View {
    var body: some View {
        List {
            section(
                title: "Connection",
                paragraphs: [
                    "Schoolity connects directly to Anoka-Hennepin StudentVUE from this iPhone. No Schoolity server, account, or analytics service receives your school information."
                ]
            )

            section(
                title: "Sign-in",
                paragraphs: [
                    "Your school username and password sign you in to the district. When this iPhone has a passcode, they are saved in a device-only Keychain entry protected by Face ID, Touch ID, or your passcode so an expired session can renew itself. Cancelling keeps the saved entry for another try. Signing out deletes the saved sign-in and its credentials.",
                    "A separate Keychain item holds only discovery flags and an expiry date, never your username, password, or session token."
                ]
            )

            section(
                title: "School data",
                paragraphs: [
                    "Grades, assignments, messages, documents, and records stay in memory while you are signed in. Schoolity does not save them to the app, and they are cleared when the app locks or when you sign out.",
                    "Downloaded files are written to temporary storage with complete file protection and are removed on sign out."
                ]
            )

            section(
                title: "On this iPhone",
                paragraphs: [
                    "Graded-assignment alerts keep only hashed identifiers and whether an assignment was graded. Course names, assignment names, and scores are not written to that baseline.",
                    "Grade colors, class names and icons, the accent color, and the appearance setting are stored in this device's app preferences."
                ]
            )

            VStack(alignment: .leading, spacing: 0) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        HairlineDivider().padding(.vertical, 8)
                        detail("When you connect", "Schoolity signs in to the district from this iPhone. The district's session cookies stay in memory for the current session only.")
                        detail("Where your information lives", "Nothing is sent to a Schoolity server. Grades, records, messages, and documents are read from the district and held in memory.")
                        detail("About this version", "This build reads the same district records the StudentVUE website shows, including course history through your signed-in district session.")
                    }
                    .padding(.bottom, 4)
                } label: {
                    Text("Connection details")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.ink)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .tint(SchoolityPalette.muted)
            }
            .schoolityCardRow(bottom: 16)

            section(
                title: "Estimates",
                paragraphs: [
                    "Grade estimates come from your assignments. District-reported grades are shown separately and Schoolity never changes them.",
                    "Schoolity is an independent student project. It is not affiliated with or endorsed by Anoka-Hennepin Schools or Edupoint."
                ],
                footer: "Schoolity reads the record your district already keeps."
            )
        }
        .schoolityPageList()
        .navigationTitle("Privacy & Connection")
        .schoolityNavigationChrome()
    }

    private func section(title: String, paragraphs: [String], footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SchoolityText.sectionTitle)
                .tracking(-0.4)
                .foregroundStyle(SchoolityPalette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(SchoolityText.body)
                    .foregroundStyle(SchoolityPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let footer {
                Text(footer)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .padding(.top, 2)
            }
        }
        .schoolityCardRow(bottom: 12)
    }

    private func detail(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SchoolityPalette.ink)
            Text(body)
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
