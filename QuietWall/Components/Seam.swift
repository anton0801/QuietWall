import Foundation
import Combine

final class Seam {

    private var pads: [AnyHashable: Any] = [:]
    private var taps: [AnyHashable: Any] = [:]
    private var fuse: AnyCancellable?

    func takePads(_ data: [AnyHashable: Any]) {
        pads = data
        arm()
        if !taps.isEmpty { weave() }
    }

    func takeTaps(_ data: [AnyHashable: Any]) {
        guard !UserDefaults.standard.bool(forKey: PadKey.primed) else { return }
        taps = data
        NotificationCenter.default.post(
            name: .tapsIn,
            object: nil,
            userInfo: ["deeplinksData": data]
        )
        fuse?.cancel()
        fuse = nil
        if !pads.isEmpty { weave() }
    }

    private func arm() {
        fuse?.cancel()
        fuse = Future<Void, Never> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                promise(.success(()))
            }
        }
        .sink { [weak self] _ in
            self?.weave()
        }
    }

    private func weave() {
        fuse?.cancel()
        fuse = nil

        var merged = pads
        for (key, value) in taps {
            let tag = "deep_\(key)"
            if merged[tag] == nil { merged[tag] = value }
        }

        NotificationCenter.default.post(
            name: .padsIn,
            object: nil,
            userInfo: ["conversionData": merged]
        )
    }
}
