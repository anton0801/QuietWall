import UIKit
import FirebaseCore
import FirebaseMessaging
import AppTrackingTransparency
import UserNotifications
import AppsFlyerLib
import Combine

final class AppDelegate: UIResponder, UIApplicationDelegate {

    private let seam = Seam()
    private let buzz = Buzz()

    private enum BootStage {
        case heat, track, signal, watch
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        boot(.heat)

        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            buzz.buzz(remote)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onActivation),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        return true
    }

    private func boot(_ stage: BootStage) {
        switch stage {
        case .heat:
            FirebaseApp.configure()
            boot(.track)
        case .track:
            let sdk = AppsFlyerLib.shared()
            sdk.appsFlyerDevKey = Pad.gaugeKey
            sdk.appleAppID = Pad.appCode
            sdk.delegate = self
            sdk.deepLinkDelegate = self
            sdk.isDebug = false
            boot(.signal)
        case .signal:
            Messaging.messaging().delegate = self
            UIApplication.shared.registerForRemoteNotifications()
            boot(.watch)
        case .watch:
            UNUserNotificationCenter.current().delegate = self
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    @objc private func onActivation() {
        if #available(iOS 14, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { status in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                    UserDefaults.standard.set(status.rawValue, forKey: PadKey.attStatus)
                }
            }
        } else {
            AppsFlyerLib.shared().start()
        }
    }

    fileprivate func relayPads(_ data: [AnyHashable: Any]) { seam.takePads(data) }
    fileprivate func relayTaps(_ data: [AnyHashable: Any]) { seam.takeTaps(data) }
    fileprivate func relayPush(_ data: [AnyHashable: Any]) { buzz.buzz(data) }
}

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        messaging.token { token, err in
            guard err == nil, let t = token else { return }
            UserDefaults.standard.set(t, forKey: PadKey.fcm)
            UserDefaults.standard.set(t, forKey: PadKey.push)
            UserDefaults(suiteName: Pad.suiteBooth)?.set(t, forKey: PadKey.sharedFcm)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        relayPush(notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        relayPush(response.notification.request.content.userInfo)
        completionHandler()
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        relayPush(userInfo)
        completionHandler(.newData)
    }
}

extension AppDelegate: AppsFlyerLibDelegate, DeepLinkDelegate {
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        relayPads(data)
    }

    func onConversionDataFail(_ error: Error) {
        relayPads([
            "error": true,
            "error_desc": error.localizedDescription
        ])
    }

    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status, let link = result.deepLink else { return }
        relayTaps(link.clickEvent)
    }
}
