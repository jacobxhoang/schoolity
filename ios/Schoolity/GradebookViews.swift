import SwiftUI
import Charts

struct GradebookView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        GradebookContent(book: store.gradebook, isLoading: store.isLoading,
                         error: store.gradeError, updated: store.lastUpdated["grades"],
                         refresh: { await store.refreshGrades(term: $0) })
            .equatable()
    }
}

private struct GradebookContent: View, Equatable {
    let book: Gradebook?
    let isLoading: Bool
    let error: String?
    let updated: Date?
    let refresh: (Int?) async -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.book == rhs.book && lhs.isLoading == rhs.isLoading && lhs.error == rhs.error && lhs.updated == rhs.updated
    }

    var body: some View {
        List {
            if let book {
                if !book.terms.isEmpty {
                        Picker("Term", selection: Binding(get: { book.currentTerm }, set: { term in
                            Task { await refresh(term) }
                        })) {
                            ForEach(book.terms) { Text($0.name).tag($0.id) }
                        }.pickerStyle(.menu).disabled(isLoading)
                }
                Section {
                    GradebookSummaryCard(average: book.calculatedAverage, courses: book.courses.count)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                } footer: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unweighted average of Schoolity estimates.")
                        LastUpdatedText(date: updated)
                    }
                }
                Section("Courses") {
                    ForEach(book.courses) { course in
                        NavigationLink { CourseDetailView(course: course).id("\(book.currentTerm)-\(course.id)") } label: { CourseRow(course: course) }
                            .accessibilityIdentifier("course-\(course.id)")
                    }
                    if book.courses.isEmpty { ContentUnavailableView("No courses", systemImage: "books.vertical", description: Text("Try another reporting period.")) }
                }
                if !book.recentAssignments.isEmpty {
                    Section {
                        ForEach(book.recentAssignments) { item in
                            NavigationLink {
                                CourseDetailView(course: item.course).id("\(book.currentTerm)-\(item.course.id)")
                            } label: {
                                RecentAssignmentRow(item: item)
                            }
                        }
                    } header: {
                        Text("Recent assignments")
                    } footer: {
                        Text("Latest due dates in this reporting period.")
                    }
                }
            }
            if isLoading && book == nil { ProgressView("Loading grades…") }
            if let error {
                Section { FailureRow(message: error) { Task { await refresh(nil) } } }
            }
        }
        .schoolityList()
        .navigationTitle("Gradebook")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isLoading && book != nil { ProgressView().accessibilityLabel("Updating grades") }
            }
        }
        .refreshable { await refresh(nil) }
        // A successful load, including a pull to refresh, lands with a tap.
        .sensoryFeedback(.success, trigger: updated)
    }

}

struct CourseRow: View {
    @EnvironmentObject private var customization: CustomizationStore
    @State private var customizing = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let course: Course
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    identity
                    grade
                }
            } else {
                HStack(spacing: 14) {
                    Image(systemName: customization.symbol(for: course.name))
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, height: 44)
                        .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    identity
                    Spacer(minLength: 8)
                    grade
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .contextMenu { Button("Customize class", systemImage: "paintbrush") { customizing = true } }
        .sheet(isPresented: $customizing) { ClassAppearanceSheet(title: course.name) }
    }

    private var grade: some View {
        let score = course.official ?? GradeMath.calculate(course)
        return VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
            Text(GradeMath.percent(score))
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: score ?? 0))
            Text(GradeMath.letter(score))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(customization.gradeColor(score))
                .contentTransition(.numericText())
        }
        .monospacedDigit()
        .animation(SchoolityMotion.calm(SchoolityMotion.value, reduceMotion: reduceMotion), value: score)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("\(GradeMath.percent(score)), \(GradeMath.letter(score)), \(course.official == nil ? "calculated grade" : "school grade")")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(customization.name(for: course.name)).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            let details = [course.teacher, course.room.isEmpty ? "" : "Room \(course.room)"].filter { !$0.isEmpty }.joined(separator: " | ")
            if !details.isEmpty { Text(details).font(.caption).foregroundStyle(.secondary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CourseDetailView: View {
    @EnvironmentObject private var customization: CustomizationStore
    let original: Course
    @State private var course: Course
    @State private var presentedSheet: Assignment?
    @State private var showReset = false
    @State private var detailSection: DetailSection = .assignments
    private enum DetailSection: String, CaseIterable {
        case assignments = "Assignments"
        case breakdown = "Breakdown"
    }
    init(course: Course) { original = course; _course = State(initialValue: course) }
    private var changed: Bool { course != original }

    var body: some View {
        List {
            Section {
                CourseGradeHeading(course: course, districtScore: original.official, changed: changed)
                if !courseDetails.isEmpty {
                    Text(courseDetails)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                LabeledContent("School grade", value: GradeMath.percent(original.official)).font(.headline)
                LabeledContent(changed ? "Hypothetical estimate" : "Schoolity estimate", value: GradeMath.percent(GradeMath.calculate(course)))
                    .accessibilityAddTraits(.updatesFrequently)
                Picker("Section", selection: $detailSection) {
                    ForEach(DetailSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }.pickerStyle(.segmented)
                if detailSection == .assignments {
                    GradeHistoryView(course: course).equatable()
                } else {
                    GradeCategoryBreakdown(course: course)
                }
            }
            if detailSection == .assignments || changed {
                Section {
                    if detailSection == .assignments {
                        HypotheticalAddButton {
                            presentedSheet = Assignment(id: UUID().uuidString, title: "", category: categoryNames.first ?? "Assignments", earned: nil, possible: 10, due: "", hypothetical: true)
                        }
                    }
                    if changed { Button("Reset changes", role: .destructive) { showReset = true }.frame(minHeight: 44) }
                }
            }
            if detailSection == .assignments {
                Section("Assignments") {
                    if course.assignments.isEmpty { Text("No assignments yet.").foregroundStyle(.secondary) }
                    ForEach(course.assignments) { assignment in
                        AssignmentDetailRow(assignment: assignment) { presentedSheet = assignment }
                        .swipeActions {
                            if assignment.hypothetical == true && !original.assignments.contains(where: { $0.id == assignment.id }) {
                                Button("Delete", role: .destructive) { course.assignments.removeAll { $0.id == assignment.id } }
                            }
                        }
                    }
                }
            }
        }
        .schoolityList()
        .navigationTitle(customization.name(for: course.name))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedSheet) { assignment in
            ScoreEditor(assignment: assignment, categories: categoryNames, save: saveAssignment)
        }
        .confirmationDialog("Reset all hypothetical changes?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Reset changes", role: .destructive) { course = original }
        }
    }

    private func saveAssignment(_ edited: Assignment) {
        if let index = course.assignments.firstIndex(where: { $0.id == edited.id }) {
            course.assignments[index] = edited
        } else {
            course.assignments.insert(edited, at: 0)
        }
    }

    private var courseDetails: String {
        [course.teacher,
         course.period.isEmpty ? "" : "Period \(course.period)",
         course.room.isEmpty ? "" : "Room \(course.room)"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private var categoryNames: [String] {
        let names = course.categories.map(\.name) + course.assignments.map(\.category)
        var seen = Set<String>()
        let unique = names.filter { !$0.isEmpty && seen.insert($0).inserted }
        return unique.isEmpty ? ["Assignments"] : unique
    }
}

private struct HypotheticalAddButton: View {
    let add: () -> Void

    var body: some View {
        Button(action: add) {
            Label("Add hypothetical score", systemImage: "plus")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowBackground(Color.clear)
        .accessibilityHint("Try a new assignment without changing school records")
    }

}

struct GradeHistoryView: View, Equatable {
    @EnvironmentObject private var customization: CustomizationStore
    let course: Course
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.course == rhs.course }
    var body: some View {
        let points = GradeMath.trend(course)
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade history").font(.headline)
            if points.isEmpty {
                Text("Your graph appears when assignments are graded.").font(.subheadline).foregroundStyle(.secondary).frame(minHeight: 100)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Graded assignment", point.id), y: .value("Grade", point.score))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                    PointMark(x: .value("Graded assignment", point.id), y: .value("Grade", point.score))
                        .foregroundStyle(customization.gradeColor(point.score)).symbolSize(points.count > 30 ? 6 : 18)
                }
                .chartYScale(domain: min(0, points.map(\.score).min() ?? 0)...max(100, points.map(\.score).max() ?? 100))
                .chartXAxis(.hidden)
                .frame(height: 160)
                .accessibilityLabel("Calculated grade history")
                .accessibilityValue("\(points.count) graded assignments. Latest estimate \(GradeMath.percent(points.last?.score)).")
            }
        }.padding(.vertical, 12)
    }
}

struct ScoreEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var assignment: Assignment
    let categories: [String]
    let save: (Assignment) -> Void
    @State private var earned = ""
    @State private var possible = ""
    private var earnedValue: Double? { Double(earned.replacingOccurrences(of: ",", with: ".")) }
    private var possibleValue: Double? { Double(possible.replacingOccurrences(of: ",", with: ".")) }
    private var valid: Bool { !assignment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && earnedValue?.isFinite == true && (earnedValue ?? -1) >= 0 && possibleValue?.isFinite == true && (possibleValue ?? -1) >= 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Assignment title", text: $assignment.title)
                    Picker("Category", selection: $assignment.category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                }
                Section("Hypothetical score") {
                    TextField("Points earned", text: $earned).keyboardType(.decimalPad)
                    TextField("Points possible", text: $possible).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Hypothetical score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        assignment.earned = earnedValue
                        assignment.possible = possibleValue ?? 0
                        assignment.hypothetical = true
                        save(assignment)
                        dismiss()
                    }.disabled(!valid)
                }
            }
            .onAppear {
                earned = assignment.earned.map(GradeMath.input) ?? ""
                possible = GradeMath.input(assignment.possible)
            }
        }
    }
}

private struct RecentAssignmentRow: View {
    let item: RecentAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.assignment.title.isEmpty ? "Untitled assignment" : item.assignment.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(item.course.name).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(dueLabel).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(scoreLabel).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private var dueLabel: String {
        item.assignment.due.isEmpty ? "No due date" : GradeMath.shortDate(item.assignment.due)
    }

    private var scoreLabel: String {
        let assignment = item.assignment
        if assignment.excluded == true { return "Not for grading" }
        guard let earned = assignment.earned else { return "Not graded" }
        if assignment.possible <= 0 { return "Extra credit" }
        return "\(GradeMath.points(earned)) / \(GradeMath.points(assignment.possible))"
    }
}

/// The gradebook summary as a card: the average reads as a ringed letter grade
/// beside the exact figure, tinted by the reader's own grade colors.
struct GradebookSummaryCard: View {
    @EnvironmentObject private var customization: CustomizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let average: Double?
    let courses: Int

    private var tint: Color { customization.gradeColor(average) }
    private var coursesText: String { courses == 1 ? "1 course" : "\(courses) courses" }

    var body: some View {
        HStack(spacing: 18) {
            GradeAverageRing(score: average, tint: tint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Course average")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(GradeMath.percent(average))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: average ?? 0))
                    .animation(SchoolityMotion.calm(SchoolityMotion.value, reduceMotion: reduceMotion), value: average)
                Text(coursesText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(LinearGradient(colors: [tint.opacity(0.18), tint.opacity(0.03)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Course average \(GradeMath.percent(average)) across \(coursesText)")
    }
}

/// A ring that fills to the average, with the letter grade resting in the middle.
private struct GradeAverageRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let score: Double?
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 7)
            if let score {
                Circle()
                    .trim(from: 0, to: max(0.03, min(1, score / 100)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(SchoolityMotion.calm(SchoolityMotion.shape, reduceMotion: reduceMotion), value: score)
                Text(GradeMath.letter(score))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            } else {
                Text("—").font(.headline).foregroundStyle(.secondary)
            }
        }
        .frame(width: 62, height: 62)
        .accessibilityHidden(true)
    }
}
