import Foundation
import Combine

@MainActor
final class Mix: ObservableObject {

    @Published var navigateToMain = false {
        didSet {
            if navigateToMain {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    @Published var navigateToWeb = false {
        didSet {
            if navigateToWeb {
                deadlineTask?.cancel()
                uiLocked = true
            }
        }
    }

    @Published var showPermissionPrompt = false
    @Published var showOfflineView = false

    private let damper: Damper
    private var cancellables = Set<AnyCancellable>()
    private var deadlineTask: Task<Void, Never>?
    private var uiLocked = false

    init() {
        self.damper = Booth.shared.patch(Damper.self)
        wireTones()
    }

    deinit {
        deadlineTask?.cancel()
    }

    private func wireTones() {
        damper.toneStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tone in
                self?.settle(tone)
            }
            .store(in: &cancellables)
    }

    func ignite() {
        damper.ensureLaced()
        armDeadline()
    }

    func ingestPads(_ data: [String: Any]) {
        Task {
            damper.takePads(data)
            await damper.absorb()
        }
    }

    func ingestTaps(_ data: [String: Any]) {
        damper.takeTaps(data)
    }

    func acceptConsent() {
        damper.acceptMute {
            self.showPermissionPrompt = false
        }
    }

    func skipConsent() {
        showPermissionPrompt = false
        damper.skipMute()
    }

    func networkConnectivityChanged(_ connected: Bool) {
        if !connected {
            showOfflineView = true
            uiLocked = true
        }
    }

    private func settle(_ tone: Tone) {
        guard !uiLocked else { return }

        switch tone {
        case .murmur:
            break
        case .cue:
            showPermissionPrompt = true
        case .air:
            navigateToWeb = true
        case .feedback:
            navigateToMain = true
        }
    }

    private func armDeadline() {
        deadlineTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self = self else { return }
            if self.damper.reportSilence() {
                self.settle(.feedback)
            }
        }
    }
}
