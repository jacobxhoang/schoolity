import SwiftUI
import CoreImage.CIFilterBuiltins

enum StudentIDBarcode {
    static func image(for value: String, width: Int, height: Int) -> CGImage? {
        // Encode the exact district value, never strip leading zeros or silently
        // replace characters. Code 128 supports printable ASCII student numbers.
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              value.utf8.count <= 64,
              value.unicodeScalars.allSatisfy({ (32...126).contains($0.value) }),
              let data = value.data(using: .ascii, allowLossyConversion: false) else { return nil }
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = data
        filter.quietSpace = 10
        filter.barcodeHeight = 32
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent.integral
        let scaleX = Int(floor(CGFloat(width) / extent.width))
        let scaleY = Int(floor(CGFloat(height) / extent.height))
        guard scaleX >= 1, scaleY >= 1 else { return nil }
        let opaque = output.composited(over: CIImage(color: .white).cropped(to: extent))
            .transformed(by: CGAffineTransform(scaleX: CGFloat(scaleX), y: CGFloat(scaleY)))
        return CIContext().createCGImage(opaque, from: opaque.extent)
    }
}

private struct ScannableStudentID: View {
    @Environment(\.displayScale) private var displayScale
    let identifier: String
    var body: some View {
        GeometryReader { geometry in
            if let image = StudentIDBarcode.image(for: identifier, width: Int(geometry.size.width * displayScale), height: Int(120 * displayScale)) {
                Image(decorative: image, scale: displayScale)
                    .interpolation(.none)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Barcode unavailable").foregroundStyle(.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: 132)
        .accessibilityHidden(true)
    }
}

struct StudentIDView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let profile = store.profile, let identifier = profile.studentId, !identifier.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(profile.name).font(.title2.bold())
                        Text(profile.school).foregroundStyle(.secondary)
                    }
                    VStack(spacing: 16) {
                        ScannableStudentID(identifier: identifier)
                        Text(identifier)
                            .font(.title2.monospaced())
                            .foregroundStyle(.black)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                            .accessibilityLabel("Student ID, \(identifier)")
                            .accessibilityIdentifier("studentID.number")
                    }
                    .padding(20)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24))
                } else if store.isLoadingProfile {
                    ProgressView("Loading student ID…").frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    ContentUnavailableView {
                        Label("Student ID unavailable", systemImage: "barcode")
                    } description: {
                        Text(store.profileError ?? "Your district hasn’t provided a student ID.")
                    } actions: {
                        Button("Try again") { Task { await store.loadProfile(refresh: true) } }
                            .buttonStyle(.bordered)
                    }
                }
            }.padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Student ID")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadProfile(refresh: store.profile?.studentId == nil) }
        .refreshable { await store.loadProfile(refresh: true) }
        .privacySensitive()
    }
}
