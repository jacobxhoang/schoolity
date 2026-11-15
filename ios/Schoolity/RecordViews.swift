import SwiftUI

struct RecordsView: View {
    var body: some View {
        List {
            SchoolityPageHeader(title: "Records")
                .schoolityPageRow(top: 8, bottom: 18)

            VStack(spacing: 0) {
                NavigationLink {
                    StudentInfoView()
                } label: {
                    RecordDestinationRow(title: "Student Info", detail: "School, contacts, and transportation", symbol: "person.text.rectangle")
                }
                .buttonStyle(.plain)
                HairlineDivider()
                NavigationLink {
                    AttendanceView()
                } label: {
                    RecordDestinationRow(title: "Attendance", detail: "Absences and period details", symbol: "checkmark.circle")
                }
                .buttonStyle(.plain)
                HairlineDivider()
                NavigationLink {
                    CourseHistoryView()
                } label: {
                    RecordDestinationRow(title: "Course History", detail: "Credits and graduation progress", symbol: "clock.arrow.circlepath")
                }
                .buttonStyle(.plain)
                HairlineDivider()
                NavigationLink {
                    ResourceView(resource: .documents)
                } label: {
                    RecordDestinationRow(title: "Documents", detail: "Reports and school files", symbol: "doc")
                }
                .buttonStyle(.plain)
            }
            .schoolityCard(padding: 4)
            .schoolityPageRow(bottom: 14)

            Text("District-reported records. Schoolity does not change them.")
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
                .schoolityPageRow(bottom: 20)
        }
        .schoolityPageList()
        .navigationTitle("Records")
        .schoolityNavigationChrome()
    }
}

private struct RecordDestinationRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, size: 40, background: .field)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(SchoolityPalette.ink)
                Text(detail)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(SchoolityPalette.faint)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 60)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct StudentInfoView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            SchoolityPageHeader(
                title: "Student Info",
                updated: store.lastUpdated[StudentRecordFeature.student.rawValue],
                isRefreshing: store.loadingRecords.contains(.student),
                refresh: { Task { await store.loadRecord(.student, refresh: true) } }
            )
            .schoolityPageRow(top: 8, bottom: 18)

            NavigationLink {
                StudentIDPage()
            } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: "barcode", size: 40, background: .field)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Student ID")
                            .font(.headline)
                            .foregroundStyle(SchoolityPalette.ink)
                        Text(store.profile?.studentId ?? "View your district ID")
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.faint)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .schoolityCardRow(bottom: 12, padding: 16)

            if let page = store.studentInfo {
                if let notice = page.notice, !notice.isEmpty {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(SchoolityPalette.muted)
                            .accessibilityHidden(true)
                        Text(notice)
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .schoolityCardRow(bottom: 12, padding: 14)
                }

                if page.sections.isEmpty {
                    SchoolityEmptyState(
                        title: "No student information",
                        description: "Your district did not return any readable sections.",
                        symbol: "person.text.rectangle"
                    )
                    .schoolityPageRow(bottom: 12)
                }

                ForEach(Array(page.sections.enumerated()), id: \.offset) { _, section in
                    SectionContent(section: section)
                        .schoolityCardRow(bottom: 12)
                }
            } else if store.loadingRecords.contains(.student) {
                ForEach(0..<2, id: \.self) { _ in
                    StudentInfoSkeleton()
                        .schoolityPageRow(bottom: 10)
                }
            } else if store.recordErrors[.student] == nil {
                SchoolityEmptyState(
                    title: "No student information",
                    description: "Refresh to load district student information.",
                    symbol: "person.text.rectangle"
                )
                .schoolityPageRow(bottom: 12)
            }

            if let error = store.recordErrors[.student] {
                FailureCard(message: error, dismiss: { store.recordErrors[.student] = nil }) {
                    Task { await store.loadRecord(.student, refresh: true) }
                }
                .schoolityPageRow(top: 4, bottom: 16)
            }
        }
        .schoolityPageList()
        .navigationTitle("Student Info")
        .schoolityNavigationChrome()
        .task { await store.loadRecord(.student) }
        .refreshable { await store.loadRecord(.student, refresh: true) }
    }
}

private struct StudentIDPage: View {
    var body: some View {
        List {
            StudentIDSection()
                .schoolityCardRow(top: 8, bottom: 16)
        }
        .schoolityPageList()
        .navigationTitle("Student ID")
        .schoolityNavigationChrome()
    }
}

private struct StudentInfoSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(width: 150, height: 16)
            SkeletonBlock(width: 220, height: 12)
            SkeletonBlock(width: 180, height: 12)
        }
        .schoolityCard(padding: 18)
        .accessibilityHidden(true)
    }
}

private struct SectionContent: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let section: InfoSection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(section.title)
                .font(.system(.headline, weight: .semibold))
                .foregroundStyle(SchoolityPalette.ink)
                .accessibilityAddTraits(.isHeader)

            if !section.fields.isEmpty {
                fields(section.fields)
            }

            ForEach(Array((section.groups ?? []).enumerated()), id: \.offset) { _, group in
                DisclosureGroup {
                    fields(group.fields)
                        .padding(.top, 10)
                } label: {
                    Text(group.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.ink)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .tint(SchoolityPalette.muted)
            }

            if let table = section.table {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(table.rows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { HairlineDivider() }
                            StudentInfoTableRow(table: table, row: row)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("\(table.rows.count) \(table.rows.count == 1 ? "row" : "rows")")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.ink)
                        .frame(minHeight: 44, alignment: .leading)
                }
                .tint(SchoolityPalette.muted)
            }

            if let note = section.note, !note.isEmpty {
                Text(note)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private func fields(_ fields: [InfoField]) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    StudentInfoFieldRow(field: field)
                }
            }
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)],
                alignment: .leading,
                spacing: 16
            ) {
                ForEach(Array(fields.enumerated()), id: \.offset) { _, field in
                    StudentInfoFieldRow(field: field)
                }
            }
        }
    }
}

private struct StudentInfoFieldRow: View {
    let field: InfoField

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(field.label)
                .font(SchoolityText.meta)
                .foregroundStyle(SchoolityPalette.muted)
            Text(StudentRecordFormat.value(field.value))
                .font(.subheadline)
                .foregroundStyle(SchoolityPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct StudentInfoTableRow: View {
    let table: InfoTable
    let row: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(table.columns.indices), id: \.self) { index in
                if index < row.count {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(table.columns[index])
                            .font(.caption)
                            .foregroundStyle(SchoolityPalette.muted)
                        Text(StudentRecordFormat.value(row[index]))
                            .font(.subheadline)
                            .foregroundStyle(SchoolityPalette.ink)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}

struct AttendanceView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            SchoolityPageHeader(
                title: "Attendance",
                updated: store.lastUpdated[StudentRecordFeature.attendance.rawValue],
                isRefreshing: store.loadingRecords.contains(.attendance),
                refresh: { Task { await store.loadRecord(.attendance, refresh: true) } }
            )
            .schoolityPageRow(top: 8, bottom: 18)

            if let page = store.attendance {
                if !page.totals.isEmpty {
                    AttendanceTotalsCard(totals: page.totals)
                        .schoolityPageRow(bottom: 14)
                }

                if page.days.isEmpty {
                    SchoolityEmptyState(
                        title: "No attendance records",
                        description: "Your district did not return any absences or tardies.",
                        symbol: "checkmark.circle"
                    )
                    .schoolityPageRow(bottom: 12)
                }

                ForEach(Array(page.days.enumerated()), id: \.offset) { _, day in
                    AttendanceDayCard(day: day)
                        .schoolityPageRow(bottom: 12)
                }
            } else if store.loadingRecords.contains(.attendance) {
                ForEach(0..<2, id: \.self) { _ in
                    StudentInfoSkeleton()
                        .schoolityPageRow(bottom: 10)
                }
            } else if store.recordErrors[.attendance] == nil {
                SchoolityEmptyState(
                    title: "No attendance records",
                    description: "Refresh to load district attendance records.",
                    symbol: "checkmark.circle"
                )
                .schoolityPageRow(bottom: 12)
            }

            if let error = store.recordErrors[.attendance] {
                FailureCard(message: error, dismiss: { store.recordErrors[.attendance] = nil }) {
                    Task { await store.loadRecord(.attendance, refresh: true) }
                }
                .schoolityPageRow(top: 4, bottom: 16)
            }
        }
        .schoolityPageList()
        .navigationTitle("Attendance")
        .schoolityNavigationChrome()
        .task { await store.loadRecord(.attendance) }
        .refreshable { await store.loadRecord(.attendance, refresh: true) }
    }
}

private struct AttendanceTotalsCard: View {
    let totals: [AttendanceTotal]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 28) {
                ForEach(totals) { total in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(total.label)
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                        Text("\(total.value)")
                            .font(.system(.title2, weight: .semibold))
                            .tracking(-0.5)
                            .foregroundStyle(SchoolityPalette.ink)
                            .monospacedDigit()
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.vertical, 2)
        }
        .schoolityCard(padding: 18)
    }
}

private struct AttendanceDayCard: View {
    let day: AttendanceDay

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(StudentRecordFormat.date(day.date))
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(SchoolityPalette.ink)
                Spacer(minLength: 8)
                if !day.reason.isEmpty {
                    SchoolityTag(text: day.reason, emphasis: true)
                }
            }

            if !day.note.isEmpty {
                Text(day.note)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            if day.periods.isEmpty && day.reason.isEmpty && day.note.isEmpty {
                Text("No period details were provided.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .padding(.top, 8)
            }

            ForEach(Array(day.periods.enumerated()), id: \.offset) { _, period in
                HairlineDivider().padding(.top, 12)
                AttendancePeriodRow(period: period)
            }
        }
        .schoolityCard(padding: 18)
    }
}

private struct AttendancePeriodRow: View {
    let period: AttendancePeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(period.period.isEmpty ? "Period not provided" : "Period \(period.period)")
                    .font(.caption)
                    .foregroundStyle(SchoolityPalette.muted)
                Spacer(minLength: 8)
                Text(period.status.isEmpty ? "Status not provided" : period.status)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SchoolityPalette.ink)
                    .multilineTextAlignment(.trailing)
            }
            Text(period.course.isEmpty ? "Course not provided" : period.course)
                .font(.subheadline)
                .foregroundStyle(SchoolityPalette.ink)
            let detail = [period.teacher, period.reason].filter { !$0.isEmpty }.joined(separator: " · ")
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(SchoolityPalette.muted)
            }
        }
        .padding(.vertical, 10)
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
            SchoolityPageHeader(
                title: "Course History",
                updated: store.lastUpdated[StudentRecordFeature.history.rawValue],
                isRefreshing: store.loadingRecords.contains(.history),
                refresh: { Task { await store.loadRecord(.history, refresh: true) } }
            )
            .schoolityPageRow(top: 8, bottom: 18)

            if let page = store.courseHistory {
                if page.requirements.isEmpty && page.courses.isEmpty {
                    SchoolityEmptyState(
                        title: "No course history",
                        description: "Your district did not return graduation progress or course records.",
                        symbol: "clock.arrow.circlepath"
                    )
                    .schoolityPageRow(bottom: 12)
                }

                graduationCard(page)
                    .schoolityPageRow(bottom: 14)

                courseRecordsCard(page)
                    .schoolityPageRow(bottom: 14)
            } else if store.loadingRecords.contains(.history) {
                ForEach(0..<2, id: \.self) { _ in
                    StudentInfoSkeleton()
                        .schoolityPageRow(bottom: 10)
                }
            } else if store.recordErrors[.history] == nil {
                SchoolityEmptyState(
                    title: "No course history",
                    description: "Refresh to load graduation progress and course records.",
                    symbol: "clock.arrow.circlepath"
                )
                .schoolityPageRow(bottom: 12)
            }

            if let error = store.recordErrors[.history] {
                FailureCard(message: error, dismiss: { store.recordErrors[.history] = nil }) {
                    Task { await store.loadRecord(.history, refresh: true) }
                }
                .schoolityPageRow(top: 4, bottom: 16)
            }
        }
        .schoolityPageList()
        .navigationTitle("Course History")
        .schoolityNavigationChrome()
        .task { await store.loadRecord(.history) }
        .refreshable {
            openRequirement = nil
            details = [:]
            detailErrors = [:]
            await store.loadRecord(.history, refresh: true)
        }
    }

    private func graduationCard(_ page: CourseHistoryPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Graduation status")
                    .font(SchoolityText.sectionTitle)
                    .tracking(-0.4)
                    .foregroundStyle(SchoolityPalette.ink)
                if !page.classOf.isEmpty {
                    Text("Class of \(page.classOf)")
                        .font(SchoolityText.meta)
                        .foregroundStyle(SchoolityPalette.muted)
                }
                Spacer(minLength: 0)
            }

            if page.requirements.isEmpty {
                Text("Your district did not return graduation progress.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
                    .padding(.top, 12)
            } else {
                if page.requirements.contains(where: { ($0.required ?? 0) > 0 && $0.completed != nil }) {
                    GraduationLegend()
                        .padding(.top, 12)
                }
                ForEach(Array(page.requirements.enumerated()), id: \.offset) { index, requirement in
                    let key = requirementKey(index, requirement)
                    HairlineDivider().padding(.top, 12)
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
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .tint(SchoolityPalette.muted)
                }
            }
        }
        .schoolityCard(padding: 18)
    }

    private func courseRecordsCard(_ page: CourseHistoryPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: courseRecordsExpansion(page)) {
                VStack(alignment: .leading, spacing: 12) {
                    HairlineDivider().padding(.top, 12)
                    if page.courses.isEmpty {
                        Text("No course history was returned by your district.")
                            .font(SchoolityText.meta)
                            .foregroundStyle(SchoolityPalette.muted)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
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
                        }
                        .font(.subheadline)

                        Text("\(shownCourses(page).count) \(shownCourses(page).count == 1 ? "course" : "courses")")
                            .font(.caption)
                            .foregroundStyle(SchoolityPalette.faint)

                        if shownCourses(page).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("No courses match these filters.")
                                    .font(SchoolityText.meta)
                                    .foregroundStyle(SchoolityPalette.muted)
                                Button("Clear filters") {
                                    year = ""
                                    school = ""
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(SchoolityPalette.ink)
                                .frame(minHeight: 44)
                            }
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(shownCourses(page).enumerated()), id: \.element.id) { index, course in
                                    if index > 0 { HairlineDivider() }
                                    CourseHistoryRow(course: course)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            } label: {
                Text("Course records")
                    .font(SchoolityText.sectionTitle)
                    .tracking(-0.4)
                    .foregroundStyle(SchoolityPalette.ink)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .tint(SchoolityPalette.muted)
            .accessibilityIdentifier("history-course-records")
        }
        .schoolityCard(padding: 18)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(requirement.subject)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SchoolityPalette.ink)
                .multilineTextAlignment(.leading)
                .accessibilityIdentifier("history-subject-title-\(requirement.id)")
            if let required = requirement.required, required > 0, let completed = requirement.completed {
                GraduationProgressBar(
                    required: required,
                    completed: completed,
                    inProgress: requirement.inProgress
                )
                Text("\(String(format: "%.1f", max(0, completed / required * 100)))% · \(StudentRecordFormat.credit(completed)) of \(StudentRecordFormat.credit(required)) credits")
                    .font(.caption)
                    .foregroundStyle(SchoolityPalette.muted)
                    .monospacedDigit()
            } else {
                Text("Progress not provided")
                    .font(.caption)
                    .foregroundStyle(SchoolityPalette.muted)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct GraduationLegend: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { entries }
            VStack(alignment: .leading, spacing: 4) { entries }
        }
        .font(.caption)
        .foregroundStyle(SchoolityPalette.muted)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress legend: completed, in progress, remaining")
        .accessibilityIdentifier("graduation-legend")
    }

    @ViewBuilder private var entries: some View {
        legendItem("Completed", color: SchoolityPalette.ink)
        legendItem("In progress", color: SchoolityPalette.muted.opacity(0.55))
        legendItem("Remaining", color: SchoolityPalette.field)
    }

    private func legendItem(_ label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(SchoolityPalette.lineStrong, lineWidth: 1)
                }
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
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(SchoolityPalette.field)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(SchoolityPalette.muted.opacity(0.55))
                    .frame(width: geometry.size.width * active)
                    .offset(x: geometry.size.width * done)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(SchoolityPalette.ink)
                    .frame(width: geometry.size.width * done)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(SchoolityPalette.lineStrong, lineWidth: 1)
            }
        }
        .frame(height: 12)
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
        VStack(alignment: .leading, spacing: 14) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 5) {
                GridRow {
                    Text("Required").foregroundStyle(SchoolityPalette.muted)
                    Text(StudentRecordFormat.credit(requirement.required))
                }
                GridRow {
                    Text("Completed").foregroundStyle(SchoolityPalette.muted)
                    Text(StudentRecordFormat.credit(requirement.completed))
                }
                GridRow {
                    Text("In progress").foregroundStyle(SchoolityPalette.muted)
                    Text(StudentRecordFormat.credit(requirement.inProgress))
                }
                GridRow {
                    Text("Remaining").foregroundStyle(SchoolityPalette.muted)
                    Text(StudentRecordFormat.credit(requirement.remaining))
                }
            }
            .font(.caption)
            .monospacedDigit()

            if loading.contains(key) {
                ProgressView("Loading classes…")
                    .font(SchoolityText.meta)
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
        .padding(.vertical, 10)
    }
}

private struct SubjectDetailGroup: View {
    let label: String
    let detail: SubjectDetails
    let rows: [[String]]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SchoolityPalette.ink)
            if rows.isEmpty {
                Text("No \(label.lowercased()) classes were returned for this subject.")
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SchoolityPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(course.mark.isEmpty ? "—" : course.mark)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SchoolityPalette.ink)
                    .monospacedDigit()
            }
            if !course.code.isEmpty {
                Text(course.code)
                    .font(.caption)
                    .foregroundStyle(SchoolityPalette.faint)
            }
            let place = [course.school, [course.year, course.term].filter { !$0.isEmpty }.joined(separator: " · ")]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !place.isEmpty {
                Text(place)
                    .font(SchoolityText.meta)
                    .foregroundStyle(SchoolityPalette.muted)
            }
            VStack(alignment: .leading, spacing: 2) {
                if !course.grade.isEmpty {
                    Text("Grade level \(course.grade)")
                }
                Text("\(StudentRecordFormat.credit(course.attempted)) attempted · \(StudentRecordFormat.credit(course.completed)) completed")
            }
            .font(.caption)
            .foregroundStyle(SchoolityPalette.muted)
            .monospacedDigit()
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
