import SwiftUI

/// Mirrors the website's privacy panel for the standalone app, which talks to
/// the district directly and never to a Schoolity server.
struct PrivacyView: View {
    var body: some View {
        List {
            Section {
                Text("Schoolity connects directly to Anoka-Hennepin StudentVUE from this iPhone. No Schoolity server, account, or analytics service receives your school information.")
            } header: {
                Text("Connection")
            }

            Section {
                Text("Your school username and password sign you in to the district. When this iPhone has a passcode, they are saved in a device-only Keychain entry protected by Face ID, Touch ID, or your passcode so an expired session can renew itself. Cancelling keeps the saved entry for another try. Signing out deletes the saved sign-in and its credentials.")
                Text("A separate Keychain item holds only discovery flags and an expiry date, never your username, password, or session token.")
            } header: {
                Text("Sign-in")
            }

            Section {
                Text("Grades, assignments, messages, documents, and records stay in memory while you are signed in. Schoolity does not save them to the app, and they are cleared when the app locks or when you sign out.")
                Text("Downloaded files are written to temporary storage with complete file protection and are removed on sign out.")
            } header: {
                Text("School data")
            }

            Section {
                Text("Graded-assignment alerts keep only hashed identifiers and whether an assignment was graded. Course names, assignment names, and scores are not written to that baseline.")
                Text("Grade colors, class names and icons, the accent color, and the appearance setting are stored in this device's app preferences.")
            } header: {
                Text("On this iPhone")
            }

            Section {
                DisclosureGroup("Connection details") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("When you connect").font(.subheadline.weight(.semibold))
                        Text("Schoolity signs in to the district from this iPhone. The district's session cookies stay in memory for the current session only.")
                        Text("Where your information lives").font(.subheadline.weight(.semibold))
                        Text("Nothing is sent to a Schoolity server. Grades, records, messages, and documents are read from the district and held in memory.")
                        Text("About this version").font(.subheadline.weight(.semibold))
                        Text("This build reads the same district records the StudentVUE website shows, including course history through your signed-in district session.")
                    }
                    .padding(.vertical, 6)
                }
            }

            Section {
                Text("Grade estimates come from your assignments. District-reported grades are shown separately and Schoolity never changes them.")
                Text("Schoolity is an independent student project. It is not affiliated with or endorsed by Anoka-Hennepin Schools or Edupoint.")
            } footer: {
                Text("Schoolity reads the record your district already keeps.")
            }
        }
        .schoolityList()
        .navigationTitle("Privacy & Connection")
        .navigationBarTitleDisplayMode(.inline)
    }
}
