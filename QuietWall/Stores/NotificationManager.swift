//
//  NotificationManager.swift
//  QuietWall
//
//  Real local-notification scheduling for material/seal reminders. Uses
//  UNUserNotificationCenter (iOS 10+, fully iOS 14 safe). No remote push.
//

import UserNotifications

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    init() { refreshStatus() }

    func refreshStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = (settings.authorizationStatus == .authorized
                                     || settings.authorizationStatus == .provisional)
            }
        }
    }

    /// Requests permission; calls back with the granted flag on the main queue.
    func requestAuthorization(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
            }
        }
    }

    /// Schedules (or reschedules) a single reminder at its fire date.
    func schedule(_ reminder: Reminder) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        guard reminder.isEnabled, reminder.fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Quiet Wall — \(reminder.kind.displayName)"
        content.body = reminder.title
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    func cancel(_ reminder: Reminder) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
    }

    /// Reconciles all scheduled notifications with the current reminder list.
    func sync(_ reminders: [Reminder]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let wanted = Set(reminders.filter { $0.isEnabled && $0.fireDate > Date() }.map { $0.id.uuidString })
            let existing = Set(pending.map { $0.identifier })
            // remove stale
            let stale = existing.subtracting(wanted)
            if !stale.isEmpty { center.removePendingNotificationRequests(withIdentifiers: Array(stale)) }
            // (re)add wanted
            for r in reminders where r.isEnabled && r.fireDate > Date() { self.schedule(r) }
        }
    }

    /// Fires a one-off confirmation so the user immediately sees it working.
    func sendTestNotification(body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Quiet Wall"
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
