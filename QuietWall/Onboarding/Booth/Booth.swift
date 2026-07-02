import Foundation

final class Rack {
    let vault: Vault
    let baffle: Baffle
    let board: Board
    let mute: Mute

    init(vault: Vault, baffle: Baffle, board: Board, mute: Mute) {
        self.vault = vault
        self.baffle = baffle
        self.board = board
        self.mute = mute
    }

    static func loaded() -> Rack {
        Rack(
            vault: FoamVault(),
            baffle: FoamBaffle(),
            board: HouseBoard(),
            mute: PanelMute()
        )
    }
}

@MainActor
final class Booth {

    static let shared = Booth()

    private var racks: [String: Any] = [:]

    private init() {}

    func stash<T>(_ instance: T, as type: T.Type) {
        racks[String(describing: type)] = instance
    }

    func patch<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        if let instance = racks[key] as? T {
            return instance
        }
        let built = mount(type)
        racks[key] = built
        return built
    }

    private func mount<T>(_ type: T.Type) -> T {
        switch String(describing: type) {
        case String(describing: Rack.self):
            return Rack.loaded() as! T
        case String(describing: Damper.self):
            return Damper(rack: patch(Rack.self)) as! T
        default:
            fatalError("Booth: no builder for \(type)")
        }
    }
}
