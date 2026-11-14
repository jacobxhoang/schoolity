import Foundation
import Combine
import UserNotifications
import BackgroundTasks
import CryptoKit

struct GradedAssignment {
    let id: String
    let course: String
    let assignment: String
    let earned: Double
    let possible: Double
}

// Persist only hashed identifiers and grading flags, never names or scores.
struct GradingSnapshot: Codable {
    var terms: [String: [String: Bool]] = [:]

    static func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    mutating func observe(_ book: Gradebook, account: String) -> [GradedAssignment] {
        let term = Self.hash("\(account)|\(book.currentTerm)")
        let previous = terms[term]
        // Keep missing IDs so a temporary omission cannot create duplicate alerts.
        var next = previous ?? [:]
        var changes: [GradedAssignment] = []
        for course in book.courses {
            for assignment in course.assignments where assignment.hypothetical != true && assignment.excluded != true {
                let id = Self.hash("\(term)|\(course.id)|\(assignment.id)")
                let graded = assignment.earned?.isFinite == true
                if previous != nil, graded, previous?[id] != true, let earned = assignment.earned {
                    changes.append(GradedAssignment(id: id, course: course.name, assignment: assignment.title,
                                                    earned: earned, possible: assignment.possible))
                }
                // Once announced, removal of a score does not announce it again.
                next[id] = graded || next[id] == true
            }
        }
        terms[term] = next
        return changes
    }
}

private final class GradeNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

@MainActor
final class GradeNotifications: ObservableObject {
    static let shared = GradeNotifications()
    static let refreshID = "com.schoolity.app.grades"
    @Published private(set) var enabled: Bool
    @Published private(set) var permissionDenied = false
    @Published private(set) var error: String?
    private let center = UNUserNotificationCenter.current()
    private let presenter = GradeNotificationPresenter()
    private var snapshot: GradingSnapshot?
    private var revision = UUID()
    private let preferences = UserDefaults.standard
    private let key = "schoolity.gradedNotifications.v1"
    private var file: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GradingFlags.json")
    }

    private init() {
        enabled = UserDefaults.standard.bool(forKey: "schoolity.gradedNotifications.v1")
        center.delegate = presenter
    }

    func refreshPermission() async {
        let settings = await center.notificationSettings()
        permissionDenied = settings.authorizationStatus == .denied
    }

    func setEnabled(_ value: Bool) async {
        error = nil
        revision = UUID()
        let ticket = revision
        if !value {
            enabled = false
            preferences.set(false, forKey: key)
            snapshot = GradingSnapshot()
            try? FileManager.default.removeItem(at: file)
            cancelPending()
            return
        }
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound])
            guard ticket == revision else { return }
            permissionDenied = !allowed
            enabled = allowed
            preferences.set(allowed, forKey: key)
            if allowed { scheduleRefresh() }
        } catch {
            guard ticket == revision else { return }
            self.error = "Notification permission couldn’t be requested. Try again."
        }
    }

    func scheduleRefresh() {
        guard enabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { /* iOS can disable background refresh; foreground checks still run. */ }
    }

    func cancelPending() {
        revision = UUID()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshID)
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func observe(_ book: Gradebook, account: String) async {
        guard enabled else { return }
        let ticket = revision
        if snapshot == nil {
            snapshot = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(GradingSnapshot.self, from: $0) } ?? GradingSnapshot()
        }
        var next = snapshot ?? GradingSnapshot()
        let changes = next.observe(book, account: account)
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(next).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            snapshot = next
        } catch {
            self.error = "Grade alerts couldn’t save their last check. Try again after unlocking your phone."
            return
        }
        for change in changes {
            // Once the baseline is committed, finish its alerts even if the
            // foreground polling task is cancelled by an ordinary app switch.
            guard enabled, ticket == revision else { return }
            let content = UNMutableNotificationContent()
            content.title = "Assignment graded"
            content.subtitle = change.course
            content.body = "\(change.assignment): \(GradeMath.points(change.earned)) / \(GradeMath.points(change.possible))"
            content.sound = .default
            content.threadIdentifier = "schoolity.grades.\(account)"
            let request = UNNotificationRequest(identifier: "graded-\(change.id)", content: content, trigger: nil)
            do { try await center.add(request) }
            catch { self.error = "A grade notification couldn’t be delivered. Check notification settings." }
            // Sign-out or disabling during an awaited add must also remove it.
            if ticket != revision || !enabled {
                center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
                center.removeDeliveredNotifications(withIdentifiers: [request.identifier])
            }
        }
    }
}
