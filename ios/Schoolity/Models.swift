import Foundation

struct Assignment: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var category: String
    var earned: Double?
    var possible: Double
    var due: String
    var excluded: Bool?
    var hypothetical: Bool?
}

struct GradeCategory: Codable, Equatable {
    var name: String
    var weight: Double
}

struct Course: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var teacher: String
    var room: String
    var period: String
    var official: Double?
    var categories: [GradeCategory]
    var assignments: [Assignment]
}

struct ReportingTerm: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
}

struct Gradebook: Codable, Equatable {
    var courses: [Course]
    var terms: [ReportingTerm]
    var currentTerm: Int
}

struct StudentProfile: Codable {
    var name: String
    var school: String
    var grade: String
    var studentId: String?
}

struct MailAttachment: Codable, Identifiable {
    var id: String
    var filename: String
}

struct SchoolEvent: Codable {
    var id: String?
    var filename: String?
    var author: String?
    var attachments: [MailAttachment]?
    var title: String
    var detail: String
    var date: String
}

enum SchoolResource: String, CaseIterable {
    case mail, documents
    var title: String {
        switch self {
        case .mail: return "Inbox"
        case .documents: return "Documents"
        }
    }
    var symbol: String {
        switch self {
        case .mail: return "tray"
        case .documents: return "doc"
        }
    }
}

enum GradeMath {
    static func calculate(_ course: Course) -> Double? {
        let active = course.assignments.filter {
            $0.excluded != true && $0.earned?.isFinite == true && $0.possible.isFinite && $0.possible >= 0
        }
        guard !active.isEmpty else { return nil }
        if !course.categories.contains(where: { $0.weight > 0 }) {
            let possible = active.reduce(0) { $0 + $1.possible }
            return possible > 0 ? active.reduce(0) { $0 + ($1.earned ?? 0) } / possible * 100 : nil
        }
        var result = 0.0
        var weight = 0.0
        for category in course.categories where category.weight > 0 && category.weight.isFinite {
            let tasks = active.filter { $0.category == category.name }
            let possible = tasks.reduce(0) { $0 + $1.possible }
            if possible > 0 {
                result += tasks.reduce(0) { $0 + ($1.earned ?? 0) } / possible * category.weight
                weight += category.weight
            }
        }
        return weight > 0 ? result / weight * 100 : nil
    }

    struct Point: Identifiable {
        let id: Int
        let score: Double
    }

    static func trend(_ course: Course) -> [Point] {
        // Keep formatters local to this calculation, but reuse them across rows.
        // Creating Foundation formatters per assignment stalls course navigation.
        let iso = ISO8601DateFormatter()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var ordered: [(assignment: Assignment, index: Int, date: Date)] = []
        for (index, assignment) in course.assignments.enumerated() {
            guard assignment.excluded != true, assignment.earned?.isFinite == true else { continue }
            let due = date(assignment.due, iso: iso, formatter: formatter) ?? Date.distantFuture
            ordered.append((assignment: assignment, index: index, date: due))
        }
        ordered.sort { left, right in
            if left.date == right.date { return left.index < right.index }
            return left.date < right.date
        }
        let weighted = course.categories.contains { $0.weight > 0 }
        var totals: [String: (earned: Double, possible: Double)] = [:]
        var earned = 0.0
        var possible = 0.0
        return ordered.enumerated().compactMap { index, assignment -> Point? in
            let task = assignment.assignment
            if task.possible.isFinite && task.possible >= 0 {
                earned += task.earned ?? 0
                possible += task.possible
                let old = totals[task.category] ?? (0, 0)
                totals[task.category] = (old.earned + (task.earned ?? 0), old.possible + task.possible)
            }
            if !weighted {
                return possible > 0 ? Point(id: index + 1, score: earned / possible * 100) : nil
            }
            var result = 0.0
            var weight = 0.0
            for category in course.categories where category.weight > 0 && category.weight.isFinite {
                if let total = totals[category.name], total.possible > 0 {
                    result += total.earned / total.possible * category.weight
                    weight += category.weight
                }
            }
            return weight > 0 ? Point(id: index + 1, score: result / weight * 100) : nil
        }
    }

    static func date(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return date(value, iso: ISO8601DateFormatter(), formatter: formatter)
    }

    fileprivate static func date(_ value: String, iso: ISO8601DateFormatter, formatter: DateFormatter) -> Date? {
        if let date = iso.date(from: value) { return date }
        for pattern in ["M/d/yyyy", "M/d/yyyy h:mm:ss a", "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "MMM d, yyyy"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    static func percent(_ score: Double?) -> String {
        guard let score, score.isFinite else { return "—" }
        // Two decimals, matching the website's grade labels.
        return String(format: "%.2f%%", score)
    }

    static func shortDate(_ value: String) -> String {
        guard let parsed = date(value) else { return value }
        return parsed.formatted(.dateTime.month(.abbreviated).day())
    }

    static func points(_ score: Double) -> String { score.formatted(.number.precision(.fractionLength(0...2))) }

    static func input(_ score: Double) -> String {
        score.formatted(.number.grouping(.never).precision(.fractionLength(0...8)).locale(Locale(identifier: "en_US_POSIX")))
    }

    static func letter(_ score: Double?) -> String {
        guard let score, score.isFinite else { return "—" }
        switch score {
        case 90...: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 60..<70: return "D"
        default: return "F"
        }
    }
}

/// One assignment in the gradebook-wide recent list, tied to its course so the
/// row can open the same course screen the gradebook uses.
struct RecentAssignment: Identifiable, Equatable {
    let id: String
    let course: Course
    let assignment: Assignment
}

extension Gradebook {
    /// The gradebook summary shown above the courses, matching the website's
    /// unweighted average of Schoolity estimates. District grades stay separate.
    var calculatedAverage: Double? {
        let scores = courses.compactMap { GradeMath.calculate($0) }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// Latest due dates across every course in the selected reporting period.
    /// Ties keep the district's course and assignment order.
    var recentAssignments: [RecentAssignment] {
        let iso = ISO8601DateFormatter()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var dates: [String: TimeInterval] = [:]
        var entries: [(index: Int, due: TimeInterval, item: RecentAssignment)] = []
        for course in courses {
            for assignment in course.assignments {
                let due: TimeInterval
                if let cached = dates[assignment.due] { due = cached }
                else {
                    due = GradeMath.date(assignment.due, iso: iso, formatter: formatter)?.timeIntervalSince1970 ?? 0
                    dates[assignment.due] = due
                }
                entries.append((entries.count, due, RecentAssignment(
                    id: "\(course.id)|\(assignment.id)", course: course, assignment: assignment)))
            }
        }
        entries.sort { left, right in
            if left.due == right.due { return left.index < right.index }
            return left.due > right.due
        }
        return entries.prefix(8).map { $0.item }
    }
}
