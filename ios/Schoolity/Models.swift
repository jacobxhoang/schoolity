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

struct Category: Codable, Equatable {
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
    var categories: [Category]
    var assignments: [Assignment]
}

struct ReportingTerm: Codable, Identifiable, Equatable {
    var id: Int
    var name: String
}

struct Gradebook: Codable {
    var courses: [Course]
    var terms: [ReportingTerm]
    var currentTerm: Int
}

struct StudentProfile: Codable {
    var name: String
    var school: String
    var grade: String
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
    case schedule, mail, documents
    var title: String {
        switch self {
        case .schedule: return "Schedule"
        case .mail: return "Inbox"
        case .documents: return "Documents"
        }
    }
    var symbol: String {
        switch self {
        case .schedule: return "calendar"
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

    static func target(_ course: Course, category: String, possible: Double, goal: Double) -> Double? {
        guard possible.isFinite, possible > 0, goal.isFinite, goal >= 0 else { return nil }
        var next = course
        next.assignments.append(Assignment(id: "target", title: "Target", category: category,
                                           earned: 0, possible: possible, due: ""))
        let low = calculate(next)
        next.assignments[next.assignments.count - 1].earned = possible
        guard let low, let high = calculate(next), high != low else { return nil }
        let required = (goal - low) / (high - low) * possible
        return required.isFinite ? required : nil
    }

    struct Point: Identifiable {
        let id: Int
        let score: Double
    }

    static func trend(_ course: Course) -> [Point] {
        let ordered = course.assignments.enumerated().filter {
            $0.element.excluded != true && $0.element.earned?.isFinite == true
        }.sorted {
            let left = date($0.element.due) ?? .distantFuture
            let right = date($1.element.due) ?? .distantFuture
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
        var prefix = course
        prefix.assignments = []
        return ordered.enumerated().compactMap { index, assignment in
            prefix.assignments.append(assignment)
            return calculate(prefix).map { Point(id: index + 1, score: $0) }
        }
    }

    static func date(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for pattern in ["M/d/yyyy", "M/d/yyyy h:mm:ss a", "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "MMM d, yyyy"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    static func percent(_ score: Double?) -> String {
        guard let score, score.isFinite else { return "—" }
        return String(format: "%.1f%%", score)
    }

    static func points(_ score: Double) -> String { score.formatted(.number.precision(.fractionLength(0...2))) }

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
