import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            if let error = store.gradeError {
                Section { FailureRow(message: error) { Task { await store.refreshGrades() } } }
            }
            if let book = store.gradebook {
                Section("Grades") {
                    if book.courses.isEmpty { Text("No courses in this reporting period.").foregroundStyle(.secondary) }
                    ForEach(book.courses) { course in
                        NavigationLink { CourseDetailView(course: course).id("\(book.currentTerm)-\(course.id)") } label: { CourseRow(course: course) }
                    }
                }
                Section {
                    NavigationLink { ResourceView(resource: .mail) } label: { Label("Inbox", systemImage: "tray") }
                    NavigationLink { ResourceView(resource: .documents) } label: { Label("Documents", systemImage: "doc") }
                }
            } else if store.isLoading { ProgressView("Loading grades…") }
        }
        .navigationTitle("Schoolity")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
        .refreshable { await store.refreshGrades() }
    }
}

struct GradebookView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            if let book = store.gradebook {
                if !book.terms.isEmpty {
                    Section {
                        Picker("Reporting period", selection: Binding(get: { book.currentTerm }, set: { term in
                            Task { await store.refreshGrades(term: term) }
                        })) {
                            ForEach(book.terms) { Text($0.name).tag($0.id) }
                        }.disabled(store.isLoading)
                    }
                }
                Section {
                    ForEach(book.courses) { course in
                        NavigationLink { CourseDetailView(course: course).id("\(book.currentTerm)-\(course.id)") } label: { CourseRow(course: course) }
                    }
                    if book.courses.isEmpty { ContentUnavailableView("No courses", systemImage: "books.vertical", description: Text("Try another reporting period.")) }
                }
            }
            if store.isLoading { ProgressView("Loading grades…") }
            if let error = store.gradeError {
                Section { FailureRow(message: error) { Task { await store.refreshGrades() } } }
            }
        }
        .navigationTitle("Grades")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
        .refreshable { await store.refreshGrades() }
    }
}

struct CourseRow: View {
    let course: Course
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(course.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                if !course.teacher.isEmpty { Text(course.teacher).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 5) {
                Text(GradeMath.letter(course.official)).font(.title2.bold())
                Text(GradeMath.percent(course.official)).font(.subheadline).foregroundStyle(.secondary)
            }.monospacedDigit().fixedSize()
        }.padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

struct CourseDetailView: View {
    let original: Course
    @State private var course: Course
    @State private var editor: Assignment?
    @State private var showTarget = false
    @State private var showReset = false
    init(course: Course) { original = course; _course = State(initialValue: course) }
    private var changed: Bool { course != original }

    var body: some View {
        List {
            Section {
                LabeledContent("District grade", value: GradeMath.percent(original.official)).font(.headline)
                LabeledContent(changed ? "What-if estimate" : "Schoolity estimate", value: GradeMath.percent(GradeMath.calculate(course)))
                    .accessibilityAddTraits(.updatesFrequently)
                GradeHistoryView(course: course)
            }
            Section {
                Button { editor = Assignment(id: UUID().uuidString, title: "", category: categoryNames.first ?? "Assignments", earned: nil, possible: 10, due: "", hypothetical: true) } label: {
                    Label("Add what-if score", systemImage: "plus")
                }.frame(minHeight: 44)
                Button { showTarget = true } label: { Label("Find a target score", systemImage: "scope") }.frame(minHeight: 44)
                if changed { Button("Reset changes", role: .destructive) { showReset = true }.frame(minHeight: 44) }
            }
            Section("Assignments") {
                if course.assignments.isEmpty { Text("No assignments yet.").foregroundStyle(.secondary) }
                ForEach(course.assignments) { assignment in
                    Button { editor = assignment } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(assignment.title).font(.headline).foregroundStyle(.primary)
                            HStack(alignment: .firstTextBaseline) {
                                Text(assignment.category).foregroundStyle(.secondary)
                                Spacer()
                                Text(assignment.earned.map { "\(GradeMath.points($0)) / \(GradeMath.points(assignment.possible))" } ?? "Not graded")
                                    .foregroundStyle(.primary).monospacedDigit()
                            }.font(.subheadline)
                            if !assignment.due.isEmpty { Text(assignment.due).font(.caption).foregroundStyle(.secondary) }
                            if assignment.excluded == true { Text("Not for grading").font(.caption).foregroundStyle(.secondary) }
                            if assignment.hypothetical == true { Label("What-if", systemImage: "pencil").font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Edit a hypothetical score")
                    .swipeActions {
                        if assignment.hypothetical == true && !original.assignments.contains(where: { $0.id == assignment.id }) {
                            Button("Delete", role: .destructive) { course.assignments.removeAll { $0.id == assignment.id } }
                        }
                    }
                }
            }
            Section {
                DisclosureGroup("About estimates") {
                    Text("What-if changes stay on this screen and never change school records. Estimates may differ from district grading policies.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if !course.teacher.isEmpty { LabeledContent("Teacher", value: course.teacher) }
                    if !course.room.isEmpty { LabeledContent("Room", value: course.room) }
                    if !course.period.isEmpty { LabeledContent("Period", value: course.period) }
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { assignment in
            ScoreEditor(assignment: assignment, categories: categoryNames) { edited in
                if let index = course.assignments.firstIndex(where: { $0.id == edited.id }) { course.assignments[index] = edited }
                else { course.assignments.append(edited) }
            }
        }
        .sheet(isPresented: $showTarget) { TargetScoreView(course: course, categories: categoryNames) }
        .confirmationDialog("Reset all what-if changes?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Reset changes", role: .destructive) { course = original }
        }
    }

    private var categoryNames: [String] {
        let names = course.categories.map(\.name) + course.assignments.map(\.category)
        var seen = Set<String>()
        let unique = names.filter { !$0.isEmpty && seen.insert($0).inserted }
        return unique.isEmpty ? ["Assignments"] : unique
    }
}

struct GradeHistoryView: View {
    let course: Course
    var body: some View {
        let points = GradeMath.trend(course)
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade history").font(.headline)
            if points.isEmpty {
                Text("Your graph appears when assignments are graded.").font(.subheadline).foregroundStyle(.secondary).frame(minHeight: 100)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Graded assignment", point.id), y: .value("Grade", point.score))
                        .foregroundStyle(Color.primary)
                    PointMark(x: .value("Graded assignment", point.id), y: .value("Grade", point.score))
                        .foregroundStyle(Color.primary).symbolSize(points.count > 30 ? 6 : 18)
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
                Section("What-if score") {
                    TextField("Points earned", text: $earned).keyboardType(.decimalPad)
                    TextField("Points possible", text: $possible).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("What-if score")
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

struct TargetScoreView: View {
    @Environment(\.dismiss) private var dismiss
    let course: Course
    let categories: [String]
    @State private var category = ""
    @State private var possible = "50"
    @State private var goal = "90"
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0).tag($0) } }
                    LabeledContent("Points possible") { TextField("50", text: $possible).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    LabeledContent("Target grade (%)") { TextField("90", text: $goal).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                }
                Section("Score needed") {
                    if let possible = Double(possible.replacingOccurrences(of: ",", with: ".")),
                       let goal = Double(goal.replacingOccurrences(of: ",", with: ".")),
                       let required = GradeMath.target(course, category: category, possible: possible, goal: goal) {
                        Text("\(GradeMath.points(max(0, required))) / \(GradeMath.points(possible))").font(.title2.bold()).monospacedDigit()
                        if required > possible { Text("This target needs extra credit.").foregroundStyle(.secondary) }
                        if required <= 0 { Text("This target is already covered, even with a zero.").foregroundStyle(.secondary) }
                    } else { Text("Enter valid points and a target for a graded category.").foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("Target score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear { category = categories.first ?? "Assignments" }
        }
    }
}
