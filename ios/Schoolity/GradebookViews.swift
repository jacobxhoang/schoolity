import SwiftUI
import Charts

struct GradebookView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        GradebookContent(book: store.gradebook, isLoading: store.isLoading,
                         error: store.gradeError, updated: store.lastUpdated["grades"],
                         refresh: { await store.refreshGrades(term: $0) },
                         dismiss: { store.gradeError = nil })
            .equatable()
    }
}

private struct GradebookContent: View, Equatable {
    @State private var selectedCourse: Course?
    @State private var recentAssignments: [RecentAssignment] = []
    let book: Gradebook?
    let isLoading: Bool
    let error: String?
    let updated: Date?
    let refresh: (Int?) async -> Void
    let dismiss: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.book == rhs.book && lhs.isLoading == rhs.isLoading && lhs.error == rhs.error && lhs.updated == rhs.updated
    }

    var body: some View {
        List {
            if let book {
                GradebookStatsCard(average: book.calculatedAverage, courses: book.courses.count)
                    .schoolityPageRow(bottom: 22)

                SectionHeading(title: "Your courses", count: book.courses.count)
                    .schoolityPageRow(bottom: 4)

                Text("Grades here are Schoolity estimates, calculated from each course's assignments. Open a course for the district's grade and how the estimate is worked out.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .schoolityPageRow(bottom: 10)

                if !book.terms.isEmpty {
                    TermLine(book: book, isLoading: isLoading, updated: updated) { term in
                        Task { await refresh(term) }
                    }
                    .schoolityPageRow(bottom: 10)
                }

                ForEach(book.courses) { course in
                    Button {
                        selectedCourse = course
                    } label: {
                        CourseRow(course: course)
                    }
                    .buttonStyle(SchoolityCardButtonStyle())
                    .accessibilityIdentifier("course-\(course.id)")
                    .schoolityPageRow(bottom: 10)
                }

                if book.courses.isEmpty {
                    if isLoading {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonCourseCard()
                                .schoolityPageRow(bottom: 10)
                        }
                    } else {
                        SchoolityEmptyState(
                            title: "No courses yet",
                            description: "No courses are available for this reporting period. Try another period or refresh.",
                            symbol: "books.vertical"
                        )
                        .schoolityPageRow(bottom: 12)
                    }
                }

                RecentAssignmentsCard(items: recentAssignments) { course in
                    selectedCourse = course
                }
                    .schoolityPageRow(bottom: 16)
            } else if isLoading {
                VStack(alignment: .leading, spacing: 12) {
                    SkeletonBlock(width: 180, height: 18)
                    SkeletonBlock(width: 120, height: 12)
                }
                .schoolityCardRow(bottom: 14)

                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCourseCard()
                        .schoolityPageRow(bottom: 10)
                }
            }
        }
        .schoolityPageList()
        // A failed refresh keeps the last grades on screen, so the failure is
        // pinned above the list instead of below rows nobody scrolls to.
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error {
                FailureCard(message: error, dismiss: dismiss) {
                    Task { await refresh(nil) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
        .onChange(of: book, initial: true) { _, next in
            recentAssignments = next?.recentAssignments ?? []
        }
        .animation(nil, value: book)
        .navigationTitle("Gradebook")
        .schoolityNavigationChrome()
        .navigationDestination(item: $selectedCourse) { course in
            CourseDetailView(course: course)
        }
        .refreshable { await refresh(nil) }
    }
}

/// The website's term line: a bordered row holding the reporting period and
/// freshness. The choice opens the app's own popover menu, as every other list
/// of options does, so a card row can never resize under the label or clip it.
private struct TermLine: View {
    let book: Gradebook
    let isLoading: Bool
    let updated: Date?
    let select: (Int) -> Void

    private var currentName: String {
        book.terms.first { $0.id == book.currentTerm }?.name ?? "Reporting period"
    }

    /// Built outside the body so the row only reads a value and reports a choice.
    private var term: Binding<Int> {
        Binding(get: { book.currentTerm }, set: select)
    }

    var body: some View {
        SchoolityMenu(
            title: "Reporting period",
            options: book.terms.map {
                SchoolityMenuOption(value: $0.id, label: $0.name)
            },
            value: term,
            isEnabled: !isLoading
        ) { isOpen in
            HStack(spacing: 10) {
                Text("Term")
                    .font(.subheadline)
                    .foregroundStyle(SchoolityPalette.muted)
                HStack(spacing: 6) {
                    Text(currentName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SchoolityPalette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: currentName)
                    SchoolityMenuChevron(isOpen: isOpen)
                }
                Spacer(minLength: 8)
                if isLoading {
                    Text("Updating…")
                        .font(SchoolityText.meta)
                        .foregroundStyle(SchoolityPalette.faint)
                } else if let updated {
                    Text(updated.formatted(date: .omitted, time: .shortened))
                        .font(SchoolityText.meta)
                        .foregroundStyle(SchoolityPalette.faint)
                }
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                SchoolityPalette.panel,
                in: RoundedRectangle(
                    cornerRadius: SchoolityRadius.panel,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: SchoolityRadius.panel,
                    style: .continuous
                )
                .strokeBorder(SchoolityPalette.line, lineWidth: 1)
                .allowsHitTesting(false)
            }
        }
        // Choosing a reporting period is the reader's own action, so it lands
        // with a tap. A load nobody asked for stays silent.
        .sensoryFeedback(.selection, trigger: book.currentTerm)
    }
}

/// The website's summary: a panel with the course average and the course count.
/// The average keeps the ring and exact figure from the app's own summary.
struct GradebookStatsCard: View {
    @EnvironmentObject private var customization: CustomizationStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let average: Double?
    let courses: Int

    private var tint: Color { customization.gradeColor(average) }
    private var coursesText: String { courses == 1 ? "1 course" : "\(courses) courses" }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 16) {
                    averageStat
                    HairlineDivider()
                    coursesStat
                }
            } else {
                HStack(alignment: .center, spacing: 18) {
                    averageStat
                    Rectangle()
                        .fill(SchoolityPalette.line)
                        .frame(width: 1, height: 56)
                        .accessibilityHidden(true)
                    coursesStat
                        .frame(width: 72, alignment: .trailing)
                }
            }
        }
        .schoolityCard(padding: 20, radius: SchoolityRadius.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Course average \(GradeMath.percent(average)) across \(coursesText)")
    }

    private var averageStat: some View {
        HStack(spacing: 14) {
            GradeAverageRing(score: average, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Course average")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                Text(GradeMath.percent(average))
                    .font(SchoolityText.stat)
                    .tracking(-1)
                    .foregroundStyle(SchoolityPalette.ink)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: average ?? 0))
                    .animation(SchoolityMotion.calm(SchoolityMotion.value, reduceMotion: reduceMotion), value: average)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var coursesStat: some View {
        VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
            Text("Courses")
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
            Text("\(courses)")
                .font(SchoolityText.stat)
                .tracking(-1)
                .foregroundStyle(SchoolityPalette.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText(value: Double(courses)))
        }
        .animation(SchoolityMotion.calm(SchoolityMotion.value, reduceMotion: reduceMotion), value: courses)
        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .leading : .trailing)
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
                .stroke(tint.opacity(0.16), lineWidth: 6)
            if let score {
                Circle()
                    .trim(from: 0, to: max(0.03, min(1, score / 100)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(GradeMath.letter(score))
                    .font(.system(.headline, weight: .bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            } else {
                Text("—")
                    .font(SchoolityText.cardTitle)
                    .foregroundStyle(SchoolityPalette.muted)
            }
        }
        .frame(width: 56, height: 56)
        .animation(SchoolityMotion.calm(SchoolityMotion.shape, reduceMotion: reduceMotion), value: score)
        .accessibilityHidden(true)
    }
}

struct CourseRow: View {
    @EnvironmentObject private var customization: CustomizationStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var customizing = false
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
                    IconTile(symbol: customization.symbol(for: course.name), size: 44, background: .soft)
                    identity
                    Spacer(minLength: 8)
                    grade
                    Image(systemName: "chevron.right")
                        .font(SchoolityText.caption.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.faint)
                        .accessibilityHidden(true)
                }
            }
        }
        .schoolityCard(padding: 16)
        .accessibilityElement(children: .combine)
        .contextMenu { Button("Customize class", systemImage: "paintbrush") { customizing = true } }
        .sheet(isPresented: $customizing) { ClassAppearanceSheet(title: course.name) }
    }

    private var grade: some View {
        let score = GradeMath.calculate(course)
        return VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 5) {
            Text(GradeMath.percent(score))
                .font(SchoolityText.statSmall)
                .tracking(-0.5)
                .foregroundStyle(SchoolityPalette.ink)
                .contentTransition(.numericText(value: score ?? 0))
            Text(GradeMath.letter(score))
                .font(SchoolityText.caption.weight(.semibold))
                .foregroundStyle(customization.gradeColor(score))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(SchoolityPalette.field, in: Capsule())
                .overlay { Capsule().strokeBorder(SchoolityPalette.line, lineWidth: 1) }
                .contentTransition(.numericText())
        }
        .monospacedDigit()
        .animation(SchoolityMotion.calm(SchoolityMotion.value, reduceMotion: reduceMotion), value: score)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel("\(GradeMath.percent(score)), \(GradeMath.letter(score)), Schoolity estimate")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(customization.name(for: course.name))
                .font(SchoolityText.cardTitle)
                .foregroundStyle(SchoolityPalette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            let details = [course.teacher, course.room.isEmpty ? "" : "Room \(course.room)"]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !details.isEmpty {
                Text(details)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CourseDetailView: View {
    @EnvironmentObject private var customization: CustomizationStore
    @Environment(\.dynamicTypeSize) private var typeSize
    let original: Course
    @State private var course: Course
    @State private var sheet: Sheet?
    @State private var showReset = false
    @State private var detailSection: DetailSection = .assignments
    @State private var expandedAssignmentIDs: Set<String> = []

    private enum DetailSection: String, CaseIterable {
        case assignments = "Assignments"
        case breakdown = "Breakdown"
    }

    /// One sheet per course screen: the score editor and the class appearance
    /// editor never open together, so they share a state.
    private enum Sheet: Identifiable {
        case score(Assignment)
        case appearance

        var id: String {
            switch self {
            case .score(let assignment):
                return "score-\(assignment.id)"
            case .appearance:
                return "appearance"
            }
        }
    }

    init(course: Course) {
        original = course
        _course = State(initialValue: course)
    }

    private var changed: Bool { course != original }

    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 18) {
                gradeComparison
                GradeHistoryView(course: course).equatable()
            }
            .schoolityCard(padding: 20)
            .schoolityPageRow(bottom: 16)

            DisclosureGroup {
                Text("Schoolity calculates this estimate from the graded assignments in this course, weighted by the district's categories when it provides them. The school grade is reported by the district and never changes here.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } label: {
                Text("About estimates")
                    .font(SchoolityText.cardTitle)
                    .foregroundStyle(SchoolityPalette.ink)
            }
            .tint(SchoolityPalette.ink)
            .schoolityCard(padding: 16)
            .schoolityPageRow(bottom: 16)

            Picker("Section", selection: $detailSection) {
                ForEach(DetailSection.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .schoolityPageRow(bottom: 16)

            if detailSection == .assignments {
                assignmentsSection
            } else {
                breakdownSection
            }
        }
        .schoolityPageList()
        .navigationTitle(customization.name(for: course.name))
        .schoolityNavigationChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sheet = .appearance
                } label: {
                    Image(systemName: "paintbrush")
                }
                .accessibilityLabel("Customize class")
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .score(let assignment):
                ScoreEditor(
                    assignment: assignment,
                    categories: categoryNames,
                    save: saveAssignment
                )
            case .appearance:
                ClassAppearanceSheet(title: course.name)
            }
        }
        .confirmationDialog("Reset all hypothetical changes?", isPresented: $showReset, titleVisibility: .visible) {
            Button("Reset changes", role: .destructive) { course = original }
        }
    }

    @ViewBuilder private var gradeComparison: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) {
                schoolGradeFigure
                HairlineDivider()
                estimateFigure
            }
        } else {
            HStack(alignment: .top, spacing: 18) {
                schoolGradeFigure
                Rectangle()
                    .fill(SchoolityPalette.line)
                    .frame(width: 1, height: 64)
                    .accessibilityHidden(true)
                estimateFigure
            }
        }
    }

    private var schoolGradeFigure: some View {
        GradeFigure(
            label: "School grade",
            value: GradeMath.percent(original.official)
        )
    }

    private var estimateFigure: some View {
        GradeFigure(
            label: changed ? "Hypothetical estimate" : "Schoolity estimate",
            value: GradeMath.percent(GradeMath.calculate(course))
        )
        .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private var assignmentsSection: some View {
        HStack(spacing: 8) {
            SectionHeading(title: "Assignments", count: course.assignments.count)
            if changed {
                Button("Reset changes", role: .destructive) { showReset = true }
                    .font(SchoolityText.meta.weight(.medium))
                    .foregroundStyle(SchoolityPalette.muted)
                    .frame(minHeight: 44)
                    .accessibilityHint("Restore the district's assignments and scores")
            }
        }
        .schoolityPageRow(bottom: 10)

        Button {
            sheet = .score(Assignment(
                id: UUID().uuidString,
                title: "",
                category: categoryNames.first ?? "Assignments",
                earned: nil,
                possible: 0,
                due: "",
                hypothetical: true
            ))
        } label: {
            Label("Add hypothetical score", systemImage: "plus")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(SchoolityPrimaryButtonStyle())
        .schoolityPageRow(bottom: 6)
        .accessibilityHint("Try a new assignment without changing school records")

        if course.assignments.isEmpty {
            SchoolityEmptyState(
                title: "No assignments yet",
                description: "Assignments show here once the district posts them.",
                symbol: "list.bullet.rectangle"
            )
            .schoolityPageRow(bottom: 12)
        } else {
            // Separate List rows let SwiftUI defer off-screen assignment layout.
            ForEach(course.assignments) { assignment in
                AssignmentDetailRow(
                    assignment: assignment,
                    isExpanded: Binding(
                        get: { expandedAssignmentIDs.contains(assignment.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedAssignmentIDs.insert(assignment.id)
                            } else {
                                expandedAssignmentIDs.remove(assignment.id)
                            }
                        }
                    ),
                    edit: { sheet = .score(assignment) },
                    remove: removable(assignment) ? { course.assignments.removeAll { $0.id == assignment.id } } : nil
                )
                .schoolityCard(padding: 16)
                .schoolityPageRow(bottom: 8)
            }
        }
    }

    private var breakdownSection: some View {
        GradeCategoryBreakdown(course: course)
            .schoolityCard(padding: 18)
            .schoolityPageRow(bottom: 16)
    }

    private func removable(_ assignment: Assignment) -> Bool {
        assignment.hypothetical == true && !original.assignments.contains(where: { $0.id == assignment.id })
    }

    private func saveAssignment(_ edited: Assignment) {
        if let index = course.assignments.firstIndex(where: { $0.id == edited.id }) {
            course.assignments[index] = edited
        } else {
            course.assignments.insert(edited, at: 0)
        }
    }

    private var courseDetails: String {
        let value = [course.teacher,
                     course.period.isEmpty ? "" : "Period \(course.period)",
                     course.room.isEmpty ? "" : "Room \(course.room)"]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return value
    }

    private var categoryNames: [String] {
        let names = course.categories.map(\.name) + course.assignments.map(\.category)
        var seen = Set<String>()
        let unique = names.filter { !$0.isEmpty && seen.insert($0).inserted }
        return unique.isEmpty ? ["Assignments"] : unique
    }
}

private struct GradeFigure: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
            Text(value)
                .font(.system(.title, weight: .semibold))
                .tracking(-0.5)
                .foregroundStyle(SchoolityPalette.ink)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GradeHistoryView: View, Equatable {
    @EnvironmentObject private var customization: CustomizationStore
    let course: Course

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.course == rhs.course }

    var body: some View {
        let points = GradeMath.trend(course)
        VStack(alignment: .leading, spacing: 10) {
            Text("Grade history")
                .font(SchoolityText.cardTitle)
                .foregroundStyle(SchoolityPalette.ink)
            if points.isEmpty {
                Text("Your graph appears when assignments are graded.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .frame(minHeight: 100)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Graded assignment", point.id), y: .value("Grade", point.score))
                        .foregroundStyle(SchoolityPalette.ink.opacity(0.55))
                    PointMark(x: .value("Graded assignment", point.id), y: .value("Grade", point.score))
                        .foregroundStyle(customization.gradeColor(point.score))
                        .symbolSize(points.count > 30 ? 6 : 18)
                        // Each point is its own element, so VoiceOver can read
                        // the course's history one graded assignment at a time.
                        .accessibilityLabel("Graded assignment \(point.id)")
                        .accessibilityValue(GradeMath.percent(point.score))
                }
                .chartYScale(domain: min(0, points.map(\.score).min() ?? 0)...max(100, points.map(\.score).max() ?? 100))
                .chartXAxis(.hidden)
                .frame(height: 160)
                .accessibilityLabel("Calculated grade history")
                .accessibilityValue("\(points.count) graded assignments. Latest estimate \(GradeMath.percent(points.last?.score)).")
            }
        }
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
    private var possibleIsValid: Bool {
        if possible.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return possibleValue?.isFinite == true && (possibleValue ?? -1) >= 0
    }
    private var valid: Bool {
        !assignment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        earnedValue?.isFinite == true && (earnedValue ?? -1) >= 0 &&
        possibleIsValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Assignment title", text: $assignment.title)
                    Picker("Category", selection: $assignment.category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                } footer: {
                    Text("A hypothetical assignment stays on this iPhone. Your school record is not changed.")
                }
                Section {
                    TextField("Points earned", text: $earned).keyboardType(.decimalPad)
                    TextField("Points possible", text: $possible).keyboardType(.decimalPad)
                } header: {
                    Text("Hypothetical score")
                } footer: {
                    if let earnedValue, let possibleValue,
                       possibleValue > 0, earnedValue > possibleValue {
                        Text("More points than the assignment is worth. The estimate shows the result.")
                    } else {
                        Text("Schoolity recalculates the course estimate from these points. The district's score stays as it is.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(SchoolityPalette.canvas)
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
                possible = assignment.possible > 0 ? GradeMath.input(assignment.possible) : ""
            }
        }
    }
}

private struct RecentAssignmentsCard: View {
    let items: [RecentAssignment]
    let openCourse: (Course) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent assignments")
                .font(SchoolityText.sectionTitle)
                .tracking(-0.4)
                .foregroundStyle(SchoolityPalette.ink)

            if items.isEmpty {
                Text("No assignments in this reporting period.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { HairlineDivider() }
                        Button {
                            openCourse(item.course)
                        } label: {
                            RecentAssignmentRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
            }
        }
        .schoolityCard(padding: 18)
    }
}

private struct RecentAssignmentRow: View {
    let item: RecentAssignment

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.assignment.title.isEmpty ? "Untitled assignment" : item.assignment.title)
                .font(SchoolityText.meta.weight(.semibold))
                .foregroundStyle(SchoolityPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.course.name)
                .font(SchoolityText.caption)
                .foregroundStyle(SchoolityPalette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(dueLabel)
                    .font(SchoolityText.caption)
                    .foregroundStyle(SchoolityPalette.muted)
                Spacer(minLength: 8)
                Text(scoreLabel)
                    .font(SchoolityText.caption.weight(.medium))
                    .foregroundStyle(SchoolityPalette.ink)
                    .monospacedDigit()
            }
            .padding(.top, 3)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var dueLabel: String {
        item.assignment.due.isEmpty ? "No due date" : GradeMath.shortDate(item.assignment.due)
    }

    private var scoreLabel: String {
        let assignment = item.assignment
        if assignment.excluded == true { return "Not for grading" }
        guard let earned = assignment.earned else {
            let possible = assignment.possible
            guard possible.isFinite, possible > 0 else { return "Not graded" }
            return "\(GradeMath.points(possible)) \(possible == 1 ? "point" : "points") possible"
        }
        if assignment.possible <= 0 { return "Extra credit" }
        return "\(GradeMath.points(earned)) / \(GradeMath.points(assignment.possible))"
    }
}

/// The website's loading cards: quiet placeholders instead of a spinner while the
/// first gradebook loads. Static on purpose, so the UI tests never wait on motion.
struct SkeletonCourseCard: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SchoolityPalette.soft)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 9) {
                SkeletonBlock(width: 150, height: 14)
                SkeletonBlock(width: 190, height: 11)
            }
            Spacer(minLength: 0)
        }
        .schoolityCard(padding: 16)
        .accessibilityHidden(true)
    }
}
