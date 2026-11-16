import SwiftUI

struct GradeCategoryBreakdown: View {
    let course: Course

    private var categories: [GradeCategory] {
        if !course.categories.isEmpty { return course.categories }
        let names = Set(course.assignments.map(\.category)).sorted()
        return names.map { GradeCategory(name: $0, weight: 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Category breakdown")
                .font(SchoolityText.sectionTitle)
                .tracking(-0.4)
                .foregroundStyle(SchoolityPalette.ink)
                .padding(.bottom, 4)

            if categories.isEmpty {
                Text("No categories provided.")
                    .font(SchoolityText.body)
                    .foregroundStyle(SchoolityPalette.muted)
                    .padding(.vertical, 14)
            } else {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                    if index > 0 { HairlineDivider() }
                    CategoryGradeRow(category: category, assignments: course.assignments)
                }
            }
        }
    }
}

private struct CategoryGradeRow: View {
    @EnvironmentObject private var customization: CustomizationStore
    let category: GradeCategory
    let assignments: [Assignment]

    var body: some View {
        let active = assignments.filter {
            $0.category == category.name && $0.excluded != true && $0.earned?.isFinite == true && $0.possible.isFinite && $0.possible >= 0
        }
        let earned = active.reduce(0.0) { $0 + ($1.earned ?? 0) }
        let possible = active.reduce(0.0) { $0 + $1.possible }
        let score: Double? = possible > 0 ? earned / possible * 100 : nil

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(category.name.isEmpty ? "Assignments" : category.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(SchoolityPalette.ink)
                if category.weight > 0 {
                    SchoolityTag(text: "\(GradeMath.points(category.weight))% weight")
                }
                Spacer(minLength: 8)
                Text(GradeMath.percent(score))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SchoolityPalette.ink)
            }
            if let score {
                SchoolityBar(value: score / 100, tint: customization.gradeColor(score), height: 5)
            }
            Text("\(GradeMath.points(earned)) / \(GradeMath.points(possible)) points")
                .font(.caption)
                .foregroundStyle(SchoolityPalette.muted)
                .monospacedDigit()
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

struct AssignmentDetailRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let assignment: Assignment
    @Binding var isExpanded: Bool
    let edit: () -> Void
    var remove: (() -> Void)? = nil

    private var score: Double? {
        guard assignment.excluded != true, let earned = assignment.earned, assignment.possible > 0 else { return nil }
        return earned / assignment.possible * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 12) {
                    AssignmentScoreIndicator(score: score)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(assignment.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SchoolityPalette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text(points)
                                .font(.caption)
                                .foregroundStyle(SchoolityPalette.muted)
                                .monospacedDigit()
                            if !assignment.category.isEmpty {
                                SchoolityTag(text: assignment.category)
                            }
                            if assignment.hypothetical == true {
                                SchoolityTag(text: "Hypothetical", emphasis: true)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.muted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isExpanded)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            SchoolityReveal(isExpanded: isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    detail("Category", assignment.category)
                    if !assignment.due.isEmpty { detail("Due", GradeMath.shortDate(assignment.due)) }
                    if let score { detail("Score", GradeMath.percent(score)) }
                    else if assignment.earned != nil && assignment.possible <= 0 { detail("Score", "Extra credit") }
                    if assignment.excluded == true {
                        Text("Not for grading")
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                    }
                    if assignment.hypothetical == true {
                        SchoolityTag(text: "Hypothetical", emphasis: true)
                    }
                    HStack(spacing: 18) {
                        Button("Edit hypothetical score", systemImage: "pencil", action: edit)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(SchoolityPalette.ink)
                            .frame(minHeight: 44)
                        if let remove {
                            Button(role: .destructive, action: remove) {
                                Label("Remove", systemImage: "trash")
                                    .font(.subheadline.weight(.medium))
                                    .frame(minHeight: 44)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(SchoolityPalette.ink)
                .multilineTextAlignment(.trailing)
        }
    }

    private var points: String {
        guard let earned = assignment.earned else { return "Not graded" }
        if assignment.possible <= 0 { return "Extra credit · \(GradeMath.points(earned)) points" }
        return "\(GradeMath.points(earned)) / \(GradeMath.points(assignment.possible))"
    }
}

private struct AssignmentScoreIndicator: View {
    @EnvironmentObject private var customization: CustomizationStore
    let score: Double?

    var body: some View {
        ZStack {
            Circle().stroke(SchoolityPalette.soft, lineWidth: 3)
            if let score {
                Circle()
                    .trim(from: 0, to: CGFloat(min(1, max(0, score / 100))))
                    .stroke(customization.gradeColor(score), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}

#if DEBUG
private enum CoursePreviewData {
    static let course = Course(id: "preview", name: "Algebra II", teacher: "Sample Teacher", room: "102", period: "1",
                               official: 92, categories: [GradeCategory(name: "Practice", weight: 100)], assignments: [
                                Assignment(id: "one", title: "Functions and transformations", category: "Practice", earned: 18, possible: 20, due: "10/1/2026")
                               ])
}

#Preview("Course rows") {
    NavigationStack {
        List {
            CourseRow(course: CoursePreviewData.course)
                .schoolityPageRow()
            GradeCategoryBreakdown(course: CoursePreviewData.course)
                .schoolityCardRow()
            AssignmentDetailRow(assignment: CoursePreviewData.course.assignments[0],
                                isExpanded: .constant(false),
                                edit: {})
                .schoolityCardRow()
        }
        .schoolityPageList()
        .navigationTitle("Gradebook")
        .schoolityNavigationChrome()
    }
    .tint(SchoolityPalette.ink)
    .environmentObject(CustomizationStore())
}

#Preview("Course rows – large text, dark") {
    List {
        CourseRow(course: CoursePreviewData.course)
            .schoolityPageRow()
        InformationRow(title: "Home address", value: "101 Sample Road\nExample, MN 00000", symbol: "house.fill")
            .schoolityCardRow()
    }
    .schoolityPageList()
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
    .environmentObject(CustomizationStore())
}
#endif
