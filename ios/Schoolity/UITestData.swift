#if DEBUG
import Foundation

// Original synthetic records used only by DEBUG builds launched by UI tests.
// Production builds have no anonymous/demo entry point.
extension AppStore {
    func loadUITestData() {
        usingUITestData = true
        profile = StudentProfile(name: "Sample Student", school: "Sample School", grade: "11", studentId: ProcessInfo.processInfo.arguments.contains("--ui-no-student-id") ? nil : "00012345")
        let course = Course(id: "sample-math", name: "Algebra II", teacher: "Sample Teacher", room: "102", period: "1", official: 92.5,
                            categories: [GradeCategory(name: "Tests", weight: 70), GradeCategory(name: "Practice", weight: 30)],
                            assignments: [
                                Assignment(id: "one", title: "Functions", category: "Practice", earned: 18, possible: 20, due: "10/1/2026"),
                                Assignment(id: "two", title: "Chapter 4&5", category: "Tests", earned: 37, possible: 40, due: "10/9/2026"),
                                Assignment(id: "three", title: "Graphing review", category: "Practice", earned: 20, possible: 20, due: "10/12/2026")
                            ])
        gradebook = Gradebook(courses: [course], terms: [ReportingTerm(id: 1, name: "Quarter 1")], currentTerm: 1)
        schedule = ScheduleData(
            terms: [
                ScheduleTerm(id: 1, name: "Quarter 1", beginDate: nil, endDate: nil, classes: [
                    ScheduleClass(id: "sample-math", title: "Algebra II", teacher: "Sample Teacher", room: "102", period: "1", meetingDays: "M,T,W,Th,F")
                ])
            ],
            currentTerm: 1
        )
        studentInfo = StudentInfoPage(
            kind: "student",
            sections: [
                InfoSection(title: "Student", fields: [
                    InfoField(label: "Name", value: "Sample Student"),
                    InfoField(label: "Student ID", value: "00012345"),
                    InfoField(label: "Grade", value: "11")
                ], groups: nil, table: nil, note: nil),
                InfoSection(title: "School", fields: [
                    InfoField(label: "School", value: "Sample School"),
                    InfoField(label: "Counselor", value: "Sample Counselor")
                ], groups: nil, table: nil, note: nil)
            ],
            notice: nil
        )
        courseHistory = CourseHistoryPage(
            kind: "history",
            courses: [
                HistoryCourse(id: "sample-history", title: "Algebra I", code: "MATH101", school: "Sample School", year: "2025", term: "Semester 1", grade: "10", mark: "A", attempted: 1, completed: 1)
            ],
            requirements: [
                GraduationRequirement(id: "math", subject: "Mathematics", required: 3, completed: 2, inProgress: 0.5, remaining: 0.5)
            ],
            classOf: "2027"
        )
        attendance = AttendancePage(
            kind: "attendance",
            days: [
                AttendanceDay(date: "2026-10-01", reason: "Excused", note: "", periods: [
                    AttendancePeriod(period: "1", status: "Excused", reason: "Appointment", course: "Algebra II", teacher: "Sample Teacher")
                ])
            ],
            totals: [AttendanceTotal(label: "Excused periods", value: 1)]
        )
        records[.mail] = [SchoolEvent(id: "sample-message", author: "Sample Teacher", attachments: [], title: "Next week’s review", detail: "Bring your practice problems on Monday. We’ll review chapters 4 & 5 together.", date: "Oct 12")]
        records[.documents] = [SchoolEvent(id: "sample-document", filename: "Sample.pdf", title: "Sample report", detail: "Progress report", date: "Oct 12")]
        access = .signedIn
    }
}
#endif
