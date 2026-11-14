import SwiftUI

struct RecordsView: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    StudentInfoView()
                } label: {
                    RecordDestinationLabel(title: "Student Info", detail: "School, contacts, and transportation", symbol: "person.text.rectangle")
                }
                NavigationLink {
                    AttendanceView()
                } label: {
                    RecordDestinationLabel(title: "Attendance", detail: "Absences and period details", symbol: "checkmark.circle")
                }
                NavigationLink {
                    CourseHistoryView()
                } label: {
                    RecordDestinationLabel(title: "Course History", detail: "Credits and graduation progress", symbol: "clock.arrow.circlepath")
                }
            } footer: {
                Text("District-reported records. Schoolity does not change them.")
            }
        }
        .listStyle(.inset)
        .navigationTitle("Records")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
    }
}

private struct RecordDestinationLabel: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        } icon: {
            InformationIcon(symbol: symbol)
        }
        .accessibilityElement(children: .combine)
    }
}

struct StudentInfoView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                NavigationLink {
                    List { StudentIDSection() }
                        .listStyle(.inset)
                        .navigationTitle("Student ID")
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Student ID").font(.headline)
                            Text(store.profile?.studentId ?? "View your district ID")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } icon: {
                        InformationIcon(symbol: "barcode")
                    }
                    .padding(.vertical, 4)
                }
            }
            if let page = store.studentInfo {
                if let notice = page.notice, !notice.isEmpty {
                    Section {
                        Label(notice, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if page.sections.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No student information",
                            systemImage: "person.text.rectangle",
                            description: Text("Your district did not return any readable sections.")
                        )
                        .listRowBackground(Color.clear)
                    }
                }
                ForEach(Array(page.sections.enumerated()), id: \.offset) { _, section in
                    Section {
                        SectionContent(section: section)
                    } header: {
                        Text(section.title)
                    }
                }
            } else if store.loadingRecords.contains(.student) {
                Section { ProgressView("Loading student information…") }
            } else if store.recordErrors[.student] == nil {
                Section {
                    ContentUnavailableView(
                        "No student information",
                        systemImage: "person.text.rectangle",
                        description: Text("Refresh to load district student information.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            if let error = store.recordErrors[.student] {
                Section {
                    FailureRow(message: error) {
                        Task { await store.loadRecord(.student, refresh: true) }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Student Info")
        .task { await store.loadRecord(.student) }
        .refreshable { await store.loadRecord(.student, refresh: true) }
    }
}

private struct SectionContent: View {
    let section: InfoSection

    var body: some View {
        Group {
            ForEach(Array(section.fields.enumerated()), id: \.offset) { _, field in
                StudentInfoFieldRow(field: field)
            }
            ForEach(Array((section.groups ?? []).enumerated()), id: \.offset) { _, group in
                DisclosureGroup {
                    ForEach(Array(group.fields.enumerated()), id: \.offset) { _, field in
                        StudentInfoFieldRow(field: field)
                    }
                } label: {
                    Text(group.title).font(.headline)
                }
            }
            if let table = section.table {
                DisclosureGroup("\(table.rows.count) \(table.rows.count == 1 ? "row" : "rows")") {
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        StudentInfoTableRow(table: table, row: row)
                    }
                }
            }
            if let note = section.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct StudentInfoFieldRow: View {
    let field: InfoField

    var body: some View {
        InformationRow(title: field.label, value: StudentRecordFormat.value(field.value), symbol: symbol)
    }

    private var symbol: String {
        let label = field.label.lowercased()
        if label.contains("mail") { return "envelope.fill" }
        if label.contains("phone") { return "phone.fill" }
        if label.contains("address") || label.contains("stop") { return "house.fill" }
        if label.contains("birth") || label.contains("date") { return "calendar" }
        if label.contains("grade") || label.contains("school") { return "graduationcap.fill" }
        if label.contains("bus") { return "bus.fill" }
        if label.contains("room") || label.contains("locker") { return "door.left.hand.closed" }
        if label.contains("physician") || label.contains("dentist") || label.contains("hospital") { return "cross.case.fill" }
        if label.contains("id") { return "person.text.rectangle" }
        return "person.fill"
    }
}

private struct StudentInfoTableRow: View {
    let table: InfoTable
    let row: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(table.columns.indices), id: \.self) { index in
                if index < row.count {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(table.columns[index])
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(StudentRecordFormat.value(row[index]))
                            .font(.subheadline)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct AttendanceView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            if let page = store.attendance {
                if !page.totals.isEmpty {
                    Section("Totals") {
                        ForEach(page.totals) { total in
                            InformationRow(title: total.label, value: "\(total.value)", symbol: "checkmark.circle.fill")
                        }
                    }
                }
                if page.days.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No attendance records",
                            systemImage: "checkmark.circle",
                            description: Text("Your district did not return any absences or tardies.")
                        )
                        .listRowBackground(Color.clear)
                    }
                }
                ForEach(Array(page.days.enumerated()), id: \.offset) { _, day in
                    Section {
                        if !day.reason.isEmpty {
                            LabeledContent("Reason", value: day.reason)
                        }
                        if !day.note.isEmpty {
                            Text(day.note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(day.periods.enumerated()), id: \.offset) { _, period in
                            AttendancePeriodRow(period: period)
                        }
                        if day.periods.isEmpty && day.reason.isEmpty && day.note.isEmpty {
                            Text("No period details were provided.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(StudentRecordFormat.date(day.date))
                    }
                }
            } else if store.loadingRecords.contains(.attendance) {
                Section { ProgressView("Loading attendance…") }
            } else if store.recordErrors[.attendance] == nil {
                Section {
                    ContentUnavailableView(
                        "No attendance records",
                        systemImage: "checkmark.circle",
                        description: Text("Refresh to load district attendance records.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            if let error = store.recordErrors[.attendance] {
                Section {
                    FailureRow(message: error) {
                        Task { await store.loadRecord(.attendance, refresh: true) }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Attendance")
        .task { await store.loadRecord(.attendance) }
        .refreshable { await store.loadRecord(.attendance, refresh: true) }
    }
}

private struct AttendancePeriodRow: View {
    let period: AttendancePeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(period.period.isEmpty ? "Period not provided" : "Period \(period.period)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(period.status.isEmpty ? "Status not provided" : period.status)
                    .font(.subheadline.weight(.semibold))
            }
            Text(period.course.isEmpty ? "Course not provided" : period.course)
                .font(.subheadline)
            if !period.teacher.isEmpty {
                Text(period.teacher).font(.caption).foregroundStyle(.secondary)
            }
            if !period.reason.isEmpty {
                Text(period.reason).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct CourseHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var year = ""
    @State private var school = ""
    @State private var openRequirement: String?
    @State private var details: [String: SubjectDetails] = [:]
    @State private var detailLoading: Set<String> = []
    @State private var detailErrors: [String: String] = [:]
    @State private var courseRecordsExpanded: Bool?

    var body: some View {
        List {
            if let page = store.courseHistory {
                if page.requirements.isEmpty && page.courses.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No course history",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("Your district did not return graduation progress or course records.")
                        )
                        .listRowBackground(Color.clear)
                    }
                }
                if !page.requirements.isEmpty {
                    Section {
                        if page.requirements.contains(where: { ($0.required ?? 0) > 0 && $0.completed != nil }) {
                            GraduationLegend()
                        }
                        ForEach(Array(page.requirements.enumerated()), id: \.offset) { index, requirement in
                            let key = requirementKey(index, requirement)
                            DisclosureGroup(isExpanded: expansion(key, requirement)) {
                                GraduationRequirementDetail(
                                    key: key,
                                    requirement: requirement,
                                    details: details,
                                    loading: detailLoading,
                                    errors: detailErrors,
                                    retry: { Task { await loadSubject(key, requirement) } }
                                )
                            } label: {
                                GraduationRequirementSummary(requirement: requirement)
                            }
                        }
                    } header: {
                        Text("Graduation status")
                    } footer: {
                        if !page.classOf.isEmpty {
                            Text("Class of \(page.classOf)")
                        }
                    }
                } else {
                    Section {
                        Text("Your district did not return graduation progress.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Graduation status")
                    } footer: {
                        if !page.classOf.isEmpty {
                            Text("Class of \(page.classOf)")
                        }
                    }
                }
                DisclosureGroup(isExpanded: courseRecordsExpansion(page)) {
                    if page.courses.isEmpty {
                        Text("No course history was returned by your district.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Year", selection: $year) {
                            Text("All years").tag("")
                            ForEach(years(page), id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("School", selection: $school) {
                            Text("All schools").tag("")
                            ForEach(schools(page), id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        LabeledContent("Courses", value: "\(shownCourses(page).count)")
                        if shownCourses(page).isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("No courses match these filters.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Button("Clear filters") {
                                    year = ""
                                    school = ""
                                }
                                .frame(minHeight: 44)
                            }
                            .padding(.vertical, 4)
                        } else {
                            ForEach(shownCourses(page)) { course in
                                CourseHistoryRow(course: course)
                            }
                        }
                    }
                } label: {
                    Text("Course records").font(.headline)
                }
                .accessibilityIdentifier("history-course-records")
            } else if store.loadingRecords.contains(.history) {
                Section { ProgressView("Loading course history…") }
            } else if store.recordErrors[.history] == nil {
                Section {
                    ContentUnavailableView(
                        "No course history",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Refresh to load graduation progress and course records.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            if let error = store.recordErrors[.history] {
                Section {
                    FailureRow(message: error) {
                        Task { await store.loadRecord(.history, refresh: true) }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Course History")
        .task { await store.loadRecord(.history) }
        .refreshable {
            openRequirement = nil
            details = [:]
            detailErrors = [:]
            await store.loadRecord(.history, refresh: true)
        }
    }

    private func requirementKey(_ index: Int, _ requirement: GraduationRequirement) -> String {
        "\(index)-\(requirement.id)"
    }

    private func courseRecordsExpansion(_ page: CourseHistoryPage) -> Binding<Bool> {
        Binding(
            get: { courseRecordsExpanded ?? page.requirements.isEmpty },
            set: { courseRecordsExpanded = $0 }
        )
    }

    private func expansion(_ key: String, _ requirement: GraduationRequirement) -> Binding<Bool> {
        Binding(
            get: { openRequirement == key },
            set: { expanded in
                if expanded {
                    openRequirement = key
                    if details[key] == nil && !detailLoading.contains(key) {
                        if let cached = store.cachedHistorySubject(id: requirement.id) {
                            details[key] = cached
                        } else {
                            Task { await loadSubject(key, requirement) }
                        }
                    }
                } else if openRequirement == key {
                    openRequirement = nil
                }
            }
        )
    }

    @MainActor
    private func loadSubject(_ key: String, _ requirement: GraduationRequirement) async {
        guard details[key] == nil, !detailLoading.contains(key) else { return }
        guard !requirement.id.isEmpty else {
            detailErrors[key] = "Your district did not provide a subject identifier. Refresh course history and try again."
            return
        }
        detailLoading.insert(key)
        detailErrors[key] = nil
        defer { detailLoading.remove(key) }
        do {
            details[key] = try await store.historySubject(id: requirement.id)
        } catch {
            guard !PortalFailure.isCancellation(error) else { return }
            detailErrors[key] = error.localizedDescription
        }
    }

    private func years(_ page: CourseHistoryPage) -> [String] {
        Array(Set(page.courses.map(\.year).filter { !$0.isEmpty })).sorted(by: >)
    }

    private func schools(_ page: CourseHistoryPage) -> [String] {
        Array(Set(page.courses.map(\.school).filter { !$0.isEmpty })).sorted()
    }

    private func shownCourses(_ page: CourseHistoryPage) -> [HistoryCourse] {
        page.courses.filter { course in
            (year.isEmpty || course.year == year) && (school.isEmpty || course.school == school)
        }
    }
}

private struct GraduationRequirementSummary: View {
    let requirement: GraduationRequirement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(requirement.subject).font(.headline)
                .accessibilityIdentifier("history-subject-title-\(requirement.id)")
            if let required = requirement.required, required > 0, let completed = requirement.completed {
                GraduationProgressBar(
                    required: required,
                    completed: completed,
                    inProgress: requirement.inProgress
                )
                Text("\(String(format: "%.1f", max(0, completed / required * 100)))% · \(StudentRecordFormat.credit(completed)) of \(StudentRecordFormat.credit(required)) credits")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Progress not provided")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct GraduationLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { entries }
            VStack(alignment: .leading, spacing: 4) { entries }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress legend: completed, in progress, remaining")
        .accessibilityIdentifier("graduation-legend")
    }

    @ViewBuilder private var entries: some View {
        legendItem("Completed", color: SchoolityStyle.accent)
        legendItem("In progress", color: SchoolityStyle.accent.opacity(0.35))
        legendItem("Remaining", color: Color.secondary.opacity(0.16))
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private struct GraduationProgressBar: View {
    let required: Double
    let completed: Double
    let inProgress: Double?

    var body: some View {
        let done = min(max(completed / required, 0), 1)
        let active = min(max((inProgress ?? 0) / required, 0), 1 - done)
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.16))
                Capsule()
                    .fill(SchoolityStyle.accent)
                    .frame(width: geometry.size.width * done)
                Capsule()
                    .fill(SchoolityStyle.accent.opacity(0.35))
                    .frame(width: geometry.size.width * active)
                    .offset(x: geometry.size.width * done)
            }
        }
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Credits completed")
        .accessibilityValue(
            "\(StudentRecordFormat.credit(completed)) of \(StudentRecordFormat.credit(required)) credits, \(StudentRecordFormat.credit(inProgress)) in progress"
        )
    }
}

private struct GraduationRequirementDetail: View {
    let key: String
    let requirement: GraduationRequirement
    let details: [String: SubjectDetails]
    let loading: Set<String>
    let errors: [String: String]
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Required").foregroundStyle(.secondary)
                    Text(StudentRecordFormat.credit(requirement.required))
                }
                GridRow {
                    Text("Completed").foregroundStyle(.secondary)
                    Text(StudentRecordFormat.credit(requirement.completed))
                }
                GridRow {
                    Text("In progress").foregroundStyle(.secondary)
                    Text(StudentRecordFormat.credit(requirement.inProgress))
                }
                GridRow {
                    Text("Remaining").foregroundStyle(.secondary)
                    Text(StudentRecordFormat.credit(requirement.remaining))
                }
            }
            .font(.caption)

            if loading.contains(key) {
                ProgressView("Loading classes…")
            }
            if let error = errors[key] {
                FailureRow(message: error, retry: retry)
            }
            if let detail = details[key] {
                SubjectDetailGroup(label: "Completed", detail: detail, rows: detail.completed)
                if !detail.inProgress.isEmpty {
                    SubjectDetailGroup(label: "In progress", detail: detail, rows: detail.inProgress)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct SubjectDetailGroup: View {
    let label: String
    let detail: SubjectDetails
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.headline)
            if rows.isEmpty {
                Text("No \(label.lowercased()) classes were returned for this subject.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HistorySubjectTable(columns: detail.columns, rows: rows)
            }
        }
    }
}

private struct CourseHistoryRow: View {
    let course: HistoryCourse

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(course.title.isEmpty ? "Untitled course" : course.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(course.mark.isEmpty ? "—" : course.mark)
                    .font(.headline)
                    .foregroundStyle(SchoolityStyle.accent)
            }
            if !course.code.isEmpty {
                Text(course.code).font(.caption).foregroundStyle(.secondary)
            }
            let place = [course.school, [course.year, course.term].filter { !$0.isEmpty }.joined(separator: " · ")]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !place.isEmpty {
                Text(place).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                if !course.grade.isEmpty {
                    Text("Grade level \(course.grade)")
                }
                Spacer()
                Text("\(StudentRecordFormat.credit(course.attempted)) attempted · \(StudentRecordFormat.credit(course.completed)) completed")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}
