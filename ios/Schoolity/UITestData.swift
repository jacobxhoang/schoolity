#if DEBUG
import Foundation

// Original synthetic records used only by DEBUG builds launched by UI tests.
// Production builds have no anonymous/demo entry point.
extension AppStore {
    func loadUITestData() {
        profile = StudentProfile(name: "Sample Student", school: "Sample School", grade: "11")
        let course = Course(id: "sample-math", name: "Algebra II", teacher: "Sample Teacher", room: "102", period: "1", official: 92.5,
                            categories: [Category(name: "Tests", weight: 70), Category(name: "Practice", weight: 30)],
                            assignments: [
                                Assignment(id: "one", title: "Functions", category: "Practice", earned: 18, possible: 20, due: "10/1/2026"),
                                Assignment(id: "two", title: "Chapter 4&5", category: "Tests", earned: 37, possible: 40, due: "10/9/2026"),
                                Assignment(id: "three", title: "Graphing review", category: "Practice", earned: 20, possible: 20, due: "10/12/2026")
                            ])
        gradebook = Gradebook(courses: [course], terms: [ReportingTerm(id: 1, name: "Quarter 1")], currentTerm: 1)
        records[.schedule] = [SchoolEvent(title: "Algebra II", detail: "Sample Teacher · Room 102", date: "Period 1")]
        records[.mail] = [SchoolEvent(id: "sample-message", author: "Sample Teacher", attachments: [], title: "Next week’s review", detail: "Bring your practice problems on Monday. We’ll review chapters 4 & 5 together.", date: "Oct 12")]
        records[.documents] = [SchoolEvent(id: "sample-document", filename: "Sample.pdf", title: "Sample report", detail: "Progress report", date: "Oct 12")]
        access = .signedIn
    }
}
#endif
