import SwiftUI
import Charts

struct GradebookView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        GradebookContent(book: store.gradebook, isLoading: store.isLoading,
                         error: store.gradeError, refresh: { await store.refreshGrades(term: $0) })
            .equatable()
    }
}

private struct GradebookContent: View, Equatable {
    let book: Gradebook?
    let isLoading: Bool
    let error: String?
    let refresh: (Int?) async -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.book == rhs.book && lhs.isLoading == rhs.isLoading && lhs.error == rhs.error
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
                Section("Courses") {
                    ForEach(book.courses) { course in
                        NavigationLink { CourseDetailView(course: course).id("\(book.currentTerm)-\(course.id)") } label: { CourseRow(course: course) }
                            .accessibilityIdentifier("course-\(course.id)")
                    }
                    if book.courses.isEmpty { ContentUnavailableView("No courses", systemImage: "books.vertical", description: Text("Try another reporting period.")) }
                }
            }
            if isLoading && book == nil { ProgressView("Loading grades…") }
            if let error {
                Section { FailureRow(message: error) { Task { await refresh(nil) } } }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Gradebook")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if isLoading && book != nil { ProgressView().accessibilityLabel("Updating grades") }
                    AccountButton()
                }
            }
        }
        .refreshable { await refresh(nil) }
    }

}

struct CourseRow: View {
    @EnvironmentObject private var customization: CustomizationStore
    @State private var customizing = false
    @Environment(\.dynamicTypeSize) private var typeSize
    let course: Course
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: customization.symbol(for: course.name))
                        .font(.title2).frame(width: 30)
                        .accessibilityHidden(true)
                }
                identity
            }
            grade
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .contextMenu { Button("Customize class", systemImage: "paintbrush") { customizing = true } }
        .sheet(isPresented: $customizing) { ClassAppearanceSheet(title: course.name) }
    }

    private var grade: some View {
        let score = course.official ?? GradeMath.calculate(course)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(GradeMath.letter(score)).foregroundStyle(customization.gradeColor(score))
            Text(GradeMath.percent(score))
        }
        .font(.callout.weight(.semibold))
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("\(GradeMath.percent(score)), \(GradeMath.letter(score)), \(course.official == nil ? "calculated grade" : "district grade")")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(customization.name(for: course.name)).font(.headline).fixedSize(horizontal: false, vertical: true)
            let details = [course.teacher, course.room.isEmpty ? "" : "Room \(course.room)"].filter { !$0.isEmpty }.joined(separator: " | ")
            if !details.isEmpty { Text(details).font(.footnote).foregroundStyle(SchoolityStyle.muted) }
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
                LabeledContent("District grade", value: GradeMath.percent(original.official)).font(.headline)
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
            Section {
                HypotheticalAddButton {
                    presentedSheet = Assignment(id: UUID().uuidString, title: "", category: categoryNames.first ?? "Assignments", earned: nil, possible: 10, due: "", hypothetical: true)
                }
                if changed { Button("Reset changes", role: .destructive) { showReset = true }.frame(minHeight: 44) }
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
        .listStyle(.inset)
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
            course.assignments.append(edited)
        }
    }

    private var categoryNames: [String] {
        let names = course.categories.map(\.name) + course.assignments.map(\.category)
        var seen = Set<String>()
        let unique = names.filter { !$0.isEmpty && seen.insert($0).inserted }
        return unique.isEmpty ? ["Assignments"] : unique
    }
}

private struct HypotheticalAddButton: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let add: () -> Void

    var body: some View {
        // Availability handles older devices; the compiler guard also keeps
        // builds using a pre-iOS-26 SDK compatible with the existing CI setup.
        #if compiler(>=6.2)
        if #available(iOS 26, *), !reduceTransparency {
            addButton.buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .padding(.vertical, 4)
        } else {
            standardControls
        }
        #else
        standardControls
        #endif
    }

    private var standardControls: some View {
        addButton.buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .padding(.vertical, 4)
    }

    private var addButton: some View {
        Button(action: add) {
            Label("Add hypothetical score", systemImage: "plus")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
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
                        .foregroundStyle(SchoolityStyle.accent)
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
