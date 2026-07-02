import Foundation

final class Reel {

    private let vault: Vault
    private var loaded = false
    private var _current = Sample()
    private var timeline: [Sample] = []

    init(vault: Vault) {
        self.vault = vault
    }

    var current: Sample {
        _current
    }

    func lace() {
        guard !loaded else { return }
        loaded = true
        _current = vault.lift()
    }

    func commit(_ sample: Sample) {
        lace()
        timeline.append(_current)
        _current = sample
        vault.stow(sample)
    }

    func amend(_ change: (inout Sample) -> Void) {
        lace()
        var draft = _current
        change(&draft)
        commit(draft)
    }

    @discardableResult
    func revert() -> Bool {
        lace()
        guard let prior = timeline.popLast() else { return false }
        _current = prior
        vault.stow(prior)
        return true
    }
}
