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
                let recent = recentAssignments(book)
                if !book.terms.isEmpty {
                        Picker("Term", selection: Binding(get: { book.currentTerm }, set: { term in
                            Task { await refresh(term) }
                        })) {
                            ForEach(book.terms) { Text($0.name).tag($0.id) }
                        }.pickerStyle(.menu).disabled(isLoading)
                }
                Section {
                    LabeledContent("Course average", value: GradeMath.percent(courseAverage(book)))
                    LabeledContent("Courses", value: "\(book.courses.count)")
                } header: {
                    Text("Overview")
                } footer: {
                    Text("Unweighted average of current course grades.")
                }
                Section("Courses") {
                    ForEach(book.courses) { course in
                        NavigationLink { CourseDetailView(course: course).id("\(book.currentTerm)-\(course.id)") } label: { CourseRow(course: course) }
                            .accessibilityIdentifier("course-\(course.id)")
                    }
                    if book.courses.isEmpty { ContentUnavailableView("No courses", systemImage: "books.vertical", description: Text("Try another reporting period.")) }
                }
                if !recent.isEmpty {
                    Section("Recent assignments") {
                        ForEach(recent) { item in
                            NavigationLink {
                                CourseDetailView(course: item.course)
                                    .id("\(book.currentTerm)-\(item.course.id)")
                            } label: {
                                RecentAssignmentRow(item: item)
                            }
                            .accessibilityIdentifier("recent-\(item.course.id)-\(item.assignment.id)")
                        }
                    }
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

    private func courseAverage(_ book: Gradebook) -> Double? {
        let scores = book.courses.compactMap { $0.official ?? GradeMath.calculate($0) }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private func recentAssignments(_ book: Gradebook) -> [RecentAssignment] {
        var items: [(item: RecentAssignment, date: Date, index: Int)] = []
        for course in book.courses {
            for (index, assignment) in course.assignments.enumerated() {
                let item = RecentAssignment(course: course, assignment: assignment)
                let due = GradeMath.date(assignment.due) ?? Date.distantPast
                items.append((item: item, date: due, index: index))
            }
        }
        items.sort {
            if $0.date != $1.date { return $0.date > $1.date }
            if $0.item.course.id != $1.item.course.id { return $0.item.course.id < $1.item.course.id }
            return $0.index < $1.index
        }
        return items.prefix(8).map(\.item)
    }
}

private struct RecentAssignment: Identifiable {
    let course: Course
    let assignment: Assignment
    var id: String { "\(course.id)-\(assignment.id)" }
}

private struct RecentAssignmentRow: View {
    let item: RecentAssignment
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.assignment.title.isEmpty ? "Untitled assignment" : item.assignment.title)
                .font(.headline)
            Text(item.course.name).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(item.assignment.due.isEmpty ? "No due date" : GradeMath.shortDate(item.assignment.due))
                Spacer()
                Text(score).font(.caption.weight(.semibold))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var score: String {
        if item.assignment.excluded == true { return "Not for grading" }
        guard let earned = item.assignment.earned else { return "Not graded" }
        return "\(GradeMath.points(earned)) / \(GradeMath.points(item.assignment.possible))"
    }
}

struct CourseRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let course: Course
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: "studentdesk")
                        .font(.title2).frame(width: 30)
                        .accessibilityHidden(true)
                }
                identity
            }
            grade
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var grade: some View {
        let score = course.official ?? GradeMath.calculate(course)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(GradeMath.letter(score)).foregroundStyle(SchoolityStyle.accent)
            Text(GradeMath.percent(score))
            Text(course.official == nil ? "Calculated" : "District grade")
                .foregroundStyle(.secondary)
        }
        .font(.callout.weight(.semibold))
        .monospacedDigit()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("\(GradeMath.percent(score)), \(GradeMath.letter(score)), \(course.official == nil ? "calculated grade" : "district grade")")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(course.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            let details = [course.teacher, course.room.isEmpty ? "" : "Room \(course.room)"].filter { !$0.isEmpty }.joined(separator: " | ")
            if !details.isEmpty { Text(details).font(.footnote).foregroundStyle(SchoolityStyle.muted) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CourseDetailView: View {
    let original: Course
    @State private var course: Course
    @State private var presentedSheet: CourseSheet?
    @State private var showReset = false
    @State private var detailSection: DetailSection = .assignments
    private enum DetailSection: String, CaseIterable {
        case assignments = "Assignments"
        case breakdown = "Breakdown"
    }
    private enum CourseSheet: Identifiable {
        case score(Assignment)
        case target

        var id: String {
            switch self {
            case .score(let assignment): return "score-\(assignment.id)"
            case .target: return "target"
            }
        }
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
                HypotheticalActions(
                    add: { presentedSheet = .score(Assignment(id: UUID().uuidString, title: "", category: categoryNames.first ?? "Assignments", earned: nil, possible: 10, due: "", hypothetical: true)) },
                    target: { presentedSheet = .target }
                )
                if changed { Button("Reset changes", role: .destructive) { showReset = true }.frame(minHeight: 44) }
            }
            if detailSection == .assignments {
                Section("Assignments") {
                    if course.assignments.isEmpty { Text("No assignments yet.").foregroundStyle(.secondary) }
                    ForEach(course.assignments) { assignment in
                        AssignmentDetailRow(assignment: assignment) { presentedSheet = .score(assignment) }
                        .swipeActions {
                            if assignment.hypothetical == true && !original.assignments.contains(where: { $0.id == assignment.id }) {
                                Button("Delete", role: .destructive) { course.assignments.removeAll { $0.id == assignment.id } }
                            }
                        }
                    }
                }
            }
            Section("Info") {
                if !course.teacher.isEmpty { InformationRow(title: "Teacher", value: course.teacher, symbol: "person.fill") }
                if !course.room.isEmpty { InformationRow(title: "Room", value: course.room, symbol: "door.left.hand.closed") }
                if !course.period.isEmpty { InformationRow(title: "Period", value: course.period, symbol: "clock.fill") }
            }
            Section {
                DisclosureGroup("About estimates") {
                    Text("Hypothetical changes stay on this screen and never change school records. Estimates may differ from district grading policies.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .score(let assignment):
                ScoreEditor(assignment: assignment, categories: categoryNames, save: saveAssignment)
            case .target:
                TargetScoreView(course: course, categories: categoryNames)
            }
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

private struct HypotheticalActions: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let add: () -> Void
    let target: () -> Void

    var body: some View {
        // Availability handles older devices; the compiler guard also keeps
        // builds using a pre-iOS-26 SDK compatible with the existing CI setup.
        #if compiler(>=6.2)
        if #available(iOS 26, *), !reduceTransparency {
            GlassEffectContainer(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    addButton.buttonStyle(.glassProminent)
                    targetButton.buttonStyle(.glass)
                }
                .buttonBorderShape(.roundedRectangle(radius: 12))
            }
            .padding(.vertical, 4)
        } else {
            standardControls
        }
        #else
        standardControls
        #endif
    }

    private var standardControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            addButton.buttonStyle(.borderedProminent)
            targetButton.buttonStyle(.bordered)
        }
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

    private var targetButton: some View {
        Button(action: target) {
            Label("Find a target score", systemImage: "scope")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct GradeHistoryView: View, Equatable {
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
                        .foregroundStyle(SchoolityStyle.accent)
                    PointMark(x: .value("Graded assignment", point.id), y: .value("Grade", point.score))
                        .foregroundStyle(SchoolityStyle.accent).symbolSize(points.count > 30 ? 6 : 18)
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
