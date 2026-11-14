import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTerm: Int?

    var body: some View {
        List {
            if let schedule = store.schedule {
                if schedule.terms.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No schedule",
                            systemImage: "calendar",
                            description: Text("No schedule was returned. Refresh to try again.")
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    if schedule.terms.count > 1 {
                        Section {
                            Picker("Term", selection: termSelection(schedule)) {
                                ForEach(schedule.terms) { term in
                                    Text(term.name).tag(term.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    if let term = visibleTerm(in: schedule) {
                        Section {
                            if term.classes.isEmpty {
                                ContentUnavailableView(
                                    "No classes",
                                    systemImage: "calendar",
                                    description: Text("No classes were returned for this term.")
                                )
                                .listRowBackground(Color.clear)
                            }
                            ForEach(term.classes) { course in
                                ScheduleClassRow(course: course)
                            }
                        } header: {
                            HStack {
                                Text(term.name)
                                Spacer()
                                Text("\(term.classes.count) \(term.classes.count == 1 ? "class" : "classes")")
                                    .fontWeight(.regular)
                            }
                        }
                    }
                }
            }
            if store.isLoadingSchedule {
                Section { ProgressView("Loading schedule…") }
            }
            if let error = store.scheduleError {
                Section {
                    FailureRow(message: error) {
                        Task { await store.loadSchedule(refresh: true) }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("Schedule")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { AccountButton() } }
        .task { await store.loadSchedule() }
        .refreshable { await store.loadSchedule(refresh: true) }
        .onChange(of: store.schedule?.currentTerm) { _, value in
            guard let value, let schedule = store.schedule else { return }
            if !schedule.terms.contains(where: { $0.id == selectedTerm }) {
                selectedTerm = value
            }
        }
    }

    private func visibleTerm(in schedule: ScheduleData) -> ScheduleTerm? {
        schedule.terms.first(where: { $0.id == termID(schedule) }) ?? schedule.terms.first
    }

    private func termID(_ schedule: ScheduleData) -> Int {
        if let selectedTerm, schedule.terms.contains(where: { $0.id == selectedTerm }) {
            return selectedTerm
        }
        if schedule.terms.contains(where: { $0.id == schedule.currentTerm }) {
            return schedule.currentTerm
        }
        return schedule.terms.first?.id ?? schedule.currentTerm
    }

    private func termSelection(_ schedule: ScheduleData) -> Binding<Int> {
        Binding(
            get: { termID(schedule) },
            set: { selectedTerm = $0 }
        )
    }
}

private struct ScheduleClassRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let course: ScheduleClass

    var body: some View {
        HStack(spacing: 12) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: "studentdesk").font(.title3).frame(width: 28).accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                let people = [course.teacher, course.room.isEmpty ? "" : "Room \(course.room)"]
                    .filter { !$0.isEmpty }
                    .joined(separator: " | ")
                if !people.isEmpty {
                    Text(people).font(.footnote).foregroundStyle(.secondary)
                }
                if let meetingDays = course.meetingDays, !meetingDays.isEmpty {
                    Text(meetingDays).font(.caption).foregroundStyle(SchoolityStyle.muted)
                }
            }
            Spacer(minLength: 4)
            if !course.period.isEmpty {
                Text(course.period)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 40, minHeight: 40)
                    .background(Color.secondary.opacity(0.12), in: Circle())
                    .accessibilityLabel("Period \(course.period)")
                    .accessibilityIdentifier("schedule-period-\(course.id)")
            }
        }
        .padding(.vertical, 8)
    }
}
