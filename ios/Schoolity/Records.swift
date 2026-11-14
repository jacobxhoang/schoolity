import Foundation

enum StudentRecordFeature: String, CaseIterable, Identifiable {
    case student, history, attendance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .student: return "Student Info"
        case .history: return "Course History"
        case .attendance: return "Attendance"
        }
    }

    var symbol: String {
        switch self {
        case .student: return "person.text.rectangle"
        case .history: return "clock.arrow.circlepath"
        case .attendance: return "checkmark.circle"
        }
    }
}

struct ScheduleClass: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var teacher: String
    var room: String
    var period: String
    var meetingDays: String?
}

struct ScheduleTerm: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
    var beginDate: String?
    var endDate: String?
    var classes: [ScheduleClass]
}

struct ScheduleData: Codable, Equatable {
    var terms: [ScheduleTerm]
    var currentTerm: Int
}

struct InfoField: Codable, Equatable {
    var label: String
    var value: String
}

struct InfoGroup: Codable, Equatable {
    var title: String
    var fields: [InfoField]
}

struct InfoTable: Codable, Equatable {
    var columns: [String]
    var rows: [[String]]
}

struct InfoSection: Codable, Equatable {
    var title: String
    var fields: [InfoField]
    var groups: [InfoGroup]?
    var table: InfoTable?
    var note: String?
}

struct StudentInfoPage: Codable, Equatable {
    var kind: String
    var sections: [InfoSection]
    var notice: String?
}

struct HistoryCourse: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var code: String
    var school: String
    var year: String
    var term: String
    var grade: String
    var mark: String
    var attempted: Double?
    var completed: Double?
}

struct GraduationRequirement: Codable, Identifiable, Equatable {
    var id: String
    var subject: String
    var required: Double?
    var completed: Double?
    var inProgress: Double?
    var remaining: Double?
}

struct CourseHistoryPage: Codable, Equatable {
    var kind: String
    var courses: [HistoryCourse]
    var requirements: [GraduationRequirement]
    var classOf: String
}

struct SubjectDetails: Codable, Equatable {
    var columns: [String]
    var completed: [[String]]
    var inProgress: [[String]]
}

struct AttendancePeriod: Codable, Equatable {
    var period: String
    var status: String
    var reason: String
    var course: String
    var teacher: String
}

struct AttendanceDay: Codable, Equatable {
    var date: String
    var reason: String
    var note: String
    var periods: [AttendancePeriod]
}

struct AttendanceTotal: Codable, Identifiable, Equatable {
    var label: String
    var value: Int
    var id: String { label }
}

struct AttendancePage: Codable, Equatable {
    var kind: String
    var days: [AttendanceDay]
    var totals: [AttendanceTotal]
}

enum StudentRecordFormat {
    static func date(_ value: String) -> String {
        guard let parsed = GradeMath.date(value) else { return value.isEmpty ? "Date not provided" : value }
        return parsed.formatted(date: .abbreviated, time: .omitted)
    }

    static func credit(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return String(format: "%.2f", value)
    }

    static func value(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not provided" : value
    }
}
