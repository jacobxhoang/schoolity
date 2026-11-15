import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTerm: Int?

    var body: some View {
        List {
            SchoolityPageHeader(
                title: "Schedule",
                updated: store.lastUpdated["schedule"],
                isRefreshing: store.isLoadingSchedule,
                refresh: { Task { await store.loadSchedule(refresh: true) } }
            )
            .schoolityPageRow(top: 8, bottom: 18)

            if let schedule = store.schedule {
                if schedule.terms.isEmpty {
                    SchoolityEmptyState(
                        title: "No schedule",
                        description: "No schedule was returned. Refresh to try again.",
                        symbol: "calendar"
                    )
                    .schoolityPageRow(bottom: 12)
                } else {
                    if schedule.terms.count > 1 {
                        termLine(schedule)
                            .schoolityPageRow(bottom: 12)
                    }
                    if let term = visibleTerm(in: schedule) {
                        SectionHeading(title: term.name, count: term.classes.count)
                            .schoolityPageRow(bottom: 10)

                        if term.classes.isEmpty {
                            SchoolityEmptyState(
                                title: "No classes",
                                description: "No classes were returned for this term.",
                                symbol: "calendar"
                            )
                            .schoolityPageRow(bottom: 12)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(term.classes.enumerated()), id: \.element.id) { index, course in
                                    if index > 0 { HairlineDivider() }
                                    ScheduleClassRow(course: course)
                                }
                            }
                            .schoolityCard(padding: 16)
                            .schoolityPageRow(bottom: 12)
                        }
                    }
                }
            } else if store.isLoadingSchedule {
                ForEach(0..<3, id: \.self) { _ in
                    ScheduleSkeletonRow()
                        .schoolityPageRow(bottom: 10)
                }
            }

            if let error = store.scheduleError {
                FailureCard(message: error, dismiss: { store.scheduleError = nil }) {
                    Task { await store.loadSchedule(refresh: true) }
                }
                .schoolityPageRow(top: 4, bottom: 16)
            }
        }
        .schoolityPageList()
        .navigationTitle("Schedule")
        .schoolityNavigationChrome()
        .task { await store.loadSchedule() }
        .refreshable { await store.loadSchedule(refresh: true) }
        .onChange(of: store.schedule?.currentTerm) { _, value in
            guard let value, let schedule = store.schedule else { return }
            if !schedule.terms.contains(where: { $0.id == selectedTerm }) {
                selectedTerm = value
            }
        }
    }

    private func termLine(_ schedule: ScheduleData) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(SchoolityPalette.ink)
                .frame(width: 6, height: 6)
                .accessibilityHidden(true)
            Menu {
                ForEach(schedule.terms) { term in
                    Button {
                        selectedTerm = term.id
                    } label: {
                        if term.id == termID(schedule) {
                            Label(term.name, systemImage: "checkmark")
                        } else {
                            Text(term.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(visibleTerm(in: schedule)?.name ?? "Term")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SchoolityPalette.ink)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(SchoolityPalette.muted)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Term, \(visibleTerm(in: schedule)?.name ?? "Term")")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(SchoolityPalette.panel, in: RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SchoolityRadius.panel, style: .continuous)
                .strokeBorder(SchoolityPalette.line, lineWidth: 1)
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
}

private struct ScheduleClassRow: View {
    @EnvironmentObject private var customization: CustomizationStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var customizing = false
    let course: ScheduleClass

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                IconTile(symbol: customization.symbol(for: course.title), size: 40, background: .soft)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(customization.name(for: course.title))
                    .font(.headline)
                    .foregroundStyle(SchoolityPalette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                let people = [course.teacher, course.room.isEmpty ? "" : "Room \(course.room)"]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !people.isEmpty {
                    Text(people)
                        .font(SchoolityText.meta)
                        .foregroundStyle(SchoolityPalette.muted)
                        .multilineTextAlignment(.leading)
                }
                if let meetingDays = course.meetingDays, !meetingDays.isEmpty {
                    Text(meetingDays)
                        .font(.caption)
                        .foregroundStyle(SchoolityPalette.faint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 4)
            if !course.period.isEmpty {
                Text(course.period)
                    .font(.system(.subheadline, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(SchoolityPalette.ink)
                    .frame(minWidth: 36, minHeight: 36)
                    .background(SchoolityPalette.field, in: Circle())
                    .overlay { Circle().strokeBorder(SchoolityPalette.line, lineWidth: 1) }
                    .accessibilityLabel("Period \(course.period)")
                    .accessibilityIdentifier("schedule-period-\(course.id)")
            }
        }
        .frame(minHeight: 56)
        .padding(.vertical, 8)
        .contextMenu { Button("Customize class", systemImage: "paintbrush") { customizing = true } }
        .sheet(isPresented: $customizing) { ClassAppearanceSheet(title: course.title) }
    }
}

private struct ScheduleSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(SchoolityPalette.soft)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 9) {
                SkeletonBlock(width: 168, height: 14)
                SkeletonBlock(width: 120, height: 11)
            }
            Spacer(minLength: 0)
        }
        .schoolityCard(padding: 16)
        .accessibilityHidden(true)
    }
}
