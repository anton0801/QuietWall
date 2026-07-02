import Foundation
import Combine
import AppsFlyerLib

@MainActor
final class Damper {

    private let rack: Rack
    private let reel: Reel
    private var capped = false
    private var damping = false

    private let toneSubject = PassthroughSubject<Tone, Never>()
    var toneStream: AnyPublisher<Tone, Never> {
        toneSubject.eraseToAnyPublisher()
    }

    init(rack: Rack) {
        self.rack = rack
        self.reel = Reel(vault: rack.vault)
    }

    func ensureLaced() {
        reel.lace()
    }

    func takePads(_ data: [String: Any]) {
        ensureLaced()
        reel.amend { draft in
            for (key, value) in data { draft.pads[key] = "\(value)" }
        }
    }

    func takeTaps(_ data: [String: Any]) {
        ensureLaced()
        reel.amend { draft in
            for (key, value) in data { draft.taps[key] = "\(value)" }
        }
    }

    func absorb() async {
        ensureLaced()
        guard !capped, !damping else { return }
        damping = true
        defer { damping = false }

        if let stash = pushStash() {
            let tone = hush(stash)
            if cork() { toneSubject.send(tone) }
            return
        }

        guard reel.current.hasPads else {
            toneSubject.send(.murmur)
            return
        }

        await soak()

        do {
            let url = try await rack.board.relay(load: reel.current.pads.mapValues { $0 as Any })
            let tone = hush(url)
            if cork() { toneSubject.send(tone) }
        } catch {
            if cork() { toneSubject.send(.feedback) }
        }
    }

    func acceptMute(then shut: @escaping () -> Void) {
//        ensureLaced()
//        guard !capped else { shut(); return }
        Task { [weak self] in
            guard let self = self else { return }
            let granted = await self.rack.mute.press()
            let now = Date()
            self.reel.amend { draft in
                draft.muteGranted = granted
                draft.muteBarred = !granted
                draft.muteAt = now
            }
            self.toneSubject.send(.air)
            shut()
        }
    }

    func skipMute() {
        ensureLaced()
        reel.amend { $0.muteAt = Date() }
        self.toneSubject.send(.air)
    }

    func reportSilence() -> Bool {
        ensureLaced()
        return cork()
    }

    private func pushStash() -> String? {
        let stash = UserDefaults.standard.string(forKey: PadKey.pushURL)
        return (stash?.isEmpty == false) ? stash : nil
    }

    private func soak() async {
        let snap = reel.current
        guard snap.organicHiss, snap.boxed, !snap.damped else { return }

        reel.amend { $0.damped = true }

        try? await Task.sleep(nanoseconds: 5_000_000_000)

        guard !reel.current.hushed else { return }

        let deviceID = AppsFlyerLib.shared().getAppsFlyerUID()
        do {
            let caught = try await rack.baffle.sample(deviceID: deviceID).mapValues { "\($0)" }
            guard !caught.isEmpty else { return }

            reel.amend { draft in
                let extras = draft.taps.filter { caught[$0.key] == nil }
                draft.pads = caught.merging(extras) { lhs, _ in lhs }
            }

            if reel.current.pads.isEmpty {
                reel.revert()
            }
        } catch {
            print("\(Pad.logWall) soak soft fail: \(error)")
        }
    }

    private func hush(_ url: String) -> Tone {
        let needsCue = reel.current.muteDue

        reel.amend { draft in
            draft.routeURL = url
            draft.routeMode = "Active"
            draft.boxed = false
            draft.hushed = true
        }

        rack.vault.brandRoute(url: url, mode: "Active")
        rack.vault.raisePrimedFlag()
        UserDefaults.standard.removeObject(forKey: PadKey.pushURL)

        return needsCue ? .cue : .air
    }

    @discardableResult
    private func cork() -> Bool {
        guard !capped else { return false }
        capped = true
        return true
    }
}
