import SwiftUI

enum SchoolityStyle {
    static let muted = Color.primary.opacity(0.65)
    static let fieldFill = Color(uiColor: .secondarySystemBackground)
    static let controlRadius: CGFloat = 18
}

struct LoginCanvas<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let editing: Bool
    let content: Content

    init(editing: Bool, @ViewBuilder content: () -> Content) {
        self.editing = editing
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { content }
                    .padding(.horizontal, 24)
                    .padding(.top, 120)
                    .padding(.bottom, 28)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .bottom)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                GeometryReader { canvas in
                    let diameter = canvas.size.width * 1.85
                    Circle()
                        .stroke(Color.primary.opacity(0.9), lineWidth: canvas.size.width * 0.2)
                        .frame(width: diameter, height: diameter)
                        .position(x: canvas.size.width * 0.18, y: -canvas.size.width * 0.32)
                        .scaleEffect(editing && !reduceMotion ? 1.05 : 1, anchor: .topLeading)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: editing)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .clipped()
            }
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Schoolity")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct CredentialFieldStyle: ViewModifier {
    let focused: Bool
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .background(SchoolityStyle.fieldFill, in: RoundedRectangle(cornerRadius: SchoolityStyle.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: SchoolityStyle.controlRadius)
                    .stroke(Color.primary.opacity(focused ? 0.45 : 0.08), lineWidth: 1)
            }
    }
}
