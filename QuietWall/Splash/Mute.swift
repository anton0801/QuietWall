import Foundation
import UserNotifications
import UIKit

protocol Mute {
    func press() async -> Bool
    func wireDing()
}

final class PanelMute: Mute {

    private let center = UNUserNotificationCenter.current()

    func press() async -> Bool {
        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            center.requestAuthorization(options: [.alert, .badge, .sound]) { ok, _ in
                cont.resume(returning: ok)
            }
        }
        if granted { wireDing() }
        return granted
    }

    func wireDing() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
