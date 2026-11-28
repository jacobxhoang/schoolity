import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedTerm: Int?

    var body: some View {
        List {
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
        }
        .schoolityPageList()
        // A failed refresh keeps the last schedule on screen, so the failure is
        // pinned above the list instead of sitting below rows nobody scrolls to.
        .safeAreaInset(edge: .top, spacing: 0) {
            if let error = store.scheduleError {
                FailureCard(message: error, dismiss: { store.scheduleError = nil }) {
                    Task { await store.loadSchedule(refresh: true) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
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
        let term = Binding(get: { termID(schedule) }, set: { selectedTerm = $0 })
        return SchoolityMenu(
            title: "Term",
            options: schedule.terms.map {
                SchoolityMenuOption(value: $0.id, label: $0.name)
            },
            value: term
        ) { isOpen in
            HStack(spacing: 10) {
                Text("Term")
                    .font(.subheadline)
                    .foregroundStyle(SchoolityPalette.muted)
                HStack(spacing: 6) {
                    Text(visibleTerm(in: schedule)?.name ?? "Term")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(SchoolityPalette.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    SchoolityMenuChevron(isOpen: isOpen)
                }
                Spacer(minLength: 8)
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
                    .font(SchoolityText.cardTitle)
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
                        .font(SchoolityText.caption)
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
            // Class appearance stays reachable by press and hold, but the row
            // also shows it, so nobody has to guess the gesture.
            Button {
                customizing = true
            } label: {
                Image(systemName: "paintbrush")
                    .font(SchoolityText.body)
                    .foregroundStyle(SchoolityPalette.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SchoolityCardButtonStyle())
            .accessibilityLabel("Customize \(customization.name(for: course.title))")
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
