import SwiftUI

/// Keep district columns and formatted values intact, including credit precision.
struct HistorySubjectTable: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let columns: [String]
    let rows: [[String]]

    private var headers: [String] {
        let count = max(columns.count, rows.map(\.count).max() ?? 0)
        return (0..<count).map { $0 < columns.count ? columns[$0] : "Column \($0 + 1)" }
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                accessibleRows
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HistoryColumnsLayout(weights: headers.map(weight)) {
                        ForEach(headers.indices, id: \.self) { index in
                            Text(headers[index])
                                .font(.caption.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 4).padding(.vertical, 10)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    Divider()
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HistoryColumnsLayout(weights: headers.map(weight)) {
                            ForEach(headers.indices, id: \.self) { index in
                                Text(value(row, at: index))
                                    .font(.caption)
                                    .monospacedDigit()
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 4).padding(.vertical, 10)
                                    .textSelection(.enabled)
                                    .accessibilityLabel("\(headers[index]): \(value(row, at: index))")
                            }
                        }
                        .background(Color(uiColor: .tertiarySystemBackground))
                        Divider()
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
        .accessibilityIdentifier("history-subject-table")
    }

    private var accessibleRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(headers.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(headers[index]).font(.caption).foregroundStyle(.secondary)
                            Text(value(row, at: index)).font(.body).textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .tertiarySystemBackground))
            }
        }
    }

    private func value(_ row: [String], at index: Int) -> String {
        index < row.count && !row[index].isEmpty ? row[index] : "—"
    }

    private func weight(_ header: String) -> CGFloat {
        let key = header.lowercased()
        if key.contains("course") || key.contains("title") { return 1.8 }
        if key.contains("credit") { return 1.3 }
        if key.contains("mark") || key == "grade" { return 0.8 }
        return 1
    }
}

/// Header and data rows share proportional widths and grow vertically as text wraps.
private struct HistoryColumnsLayout: Layout {
    let weights: [CGFloat]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let total = max(weights.reduce(0, +), 1)
        var height: CGFloat = 0
        for (index, view) in subviews.enumerated() {
            let cellWidth = width * weights[index] / total
            height = max(height, view.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let total = max(weights.reduce(0, +), 1)
        var x = bounds.minX
        for (index, view) in subviews.enumerated() {
            let width = bounds.width * weights[index] / total
            view.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                       proposal: ProposedViewSize(width: width, height: nil))
            x += width
        }
    }
}

#if DEBUG
#Preview("Course History category – dark") {
    List {
        HistorySubjectTable(
            columns: ["Term", "Course Title (ID)", "Mark", "Credit Attempted", "Credit Completed"],
            rows: [["2025 - T1", "Sample Civics (CIV101)", "A", "0.50", "0.50"]])
    }.preferredColorScheme(.dark)
}
#endif
