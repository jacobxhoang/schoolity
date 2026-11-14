import SwiftUI

struct GradeCategoryBreakdown: View {
    let course: Course

    private var categories: [GradeCategory] {
        if !course.categories.isEmpty { return course.categories }
        let names = Set(course.assignments.map(\.category)).sorted()
        return names.map { GradeCategory(name: $0, weight: 0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category breakdown").font(.headline)
            ForEach(Array(categories.enumerated()), id: \.offset) { _, category in
                CategoryGradeRow(category: category, assignments: course.assignments)
            }
            if categories.isEmpty { Text("No categories provided.").foregroundStyle(.secondary) }
        }
        .padding(.vertical, 12)
    }
}

private struct CategoryGradeRow: View {
    let category: GradeCategory
    let assignments: [Assignment]

    var body: some View {
        let active = assignments.filter {
            $0.category == category.name && $0.excluded != true && $0.earned?.isFinite == true && $0.possible.isFinite && $0.possible >= 0
        }
        let earned = active.reduce(0.0) { $0 + ($1.earned ?? 0) }
        let possible = active.reduce(0.0) { $0 + $1.possible }
        let score: Double? = possible > 0 ? earned / possible * 100 : nil
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(category.name.isEmpty ? "Assignments" : category.name, value: GradeMath.percent(score))
                .font(.subheadline.weight(.medium))
            if let score { ProgressView(value: min(100, max(0, score)), total: 100).tint(SchoolityStyle.accent) }
            HStack {
                Text("\(GradeMath.points(earned)) / \(GradeMath.points(possible)) points")
                Spacer()
                if category.weight > 0 { Text("\(GradeMath.points(category.weight))% weight") }
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct CourseGradeHeading: View {
    let course: Course
    let districtScore: Double?
    let changed: Bool

    private var score: Double? { changed ? GradeMath.calculate(course) : districtScore ?? GradeMath.calculate(course) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(GradeMath.letter(score)).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(SchoolityStyle.accent)
                Text(GradeMath.percent(score)).font(.title2.weight(.semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .monospacedDigit()
            if let score {
                ProgressView(value: min(100, max(0, score)), total: 100)
                    .tint(SchoolityStyle.accent)
                    .accessibilityLabel(changed ? "Hypothetical grade progress" : "Course grade progress")
                    .accessibilityValue(GradeMath.percent(score))
            }
        }
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)
    }
}

struct AssignmentDetailRow: View {
    let assignment: Assignment
    let edit: () -> Void

    private var score: Double? {
        guard assignment.excluded != true, let earned = assignment.earned, assignment.possible > 0 else { return nil }
        return earned / assignment.possible * 100
    }

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Category", value: assignment.category)
                if !assignment.due.isEmpty { LabeledContent("Due", value: GradeMath.shortDate(assignment.due)) }
                if let score { LabeledContent("Score", value: GradeMath.percent(score)) }
                if assignment.excluded == true { Text("Not for grading").foregroundStyle(.secondary) }
                if assignment.hypothetical == true { Label("Hypothetical", systemImage: "pencil").foregroundStyle(.secondary) }
                Button("Edit hypothetical score", systemImage: "pencil", action: edit)
                    .frame(minHeight: 44)
            }
            .font(.subheadline)
            .padding(.vertical, 8)
        } label: {
            HStack(spacing: 12) {
                AssignmentScoreIndicator(score: score)
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.title).font(.headline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(points).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var points: String {
        guard let earned = assignment.earned else { return "Not graded" }
        return "\(GradeMath.points(earned)) / \(GradeMath.points(assignment.possible))"
    }
}

private struct AssignmentScoreIndicator: View {
    let score: Double?
    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 3)
            if let score {
                Circle().trim(from: 0, to: CGFloat(min(1, max(0, score / 100))))
                    .stroke(SchoolityStyle.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: 25, height: 25)
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
            CourseGradeHeading(course: CoursePreviewData.course, districtScore: 92, changed: false)
            AssignmentDetailRow(assignment: CoursePreviewData.course.assignments[0], edit: {})
            GradeCategoryBreakdown(course: CoursePreviewData.course)
        }.listStyle(.inset).navigationTitle("Gradebook")
    }.tint(SchoolityStyle.accent)
}

#Preview("Course rows – large text, dark") {
    List {
        CourseRow(course: CoursePreviewData.course)
        InformationRow(title: "Home address", value: "101 Sample Road\nExample, MN 00000", symbol: "house.fill")
        AssignmentDetailRow(assignment: CoursePreviewData.course.assignments[0], edit: {})
    }
    .listStyle(.inset)
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
#endif
