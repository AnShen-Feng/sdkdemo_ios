// Relative path: partnersdk_demo_ios/app/Features/RTC/DemoViewModel.swift

import Foundation
import partnersdk_ios

@MainActor
final class DemoViewModel: ObservableObject {
    @Published var backendBaseUrl: String = "http://127.0.0.1:3000"
    @Published var roomId: String = "demo-room"
    @Published var displayName: String = "ios-demo"
    @Published var businessToken: String = ""
    @Published var targetIdentity: String = ""
    @Published var stateText: String = "disconnected"
    @Published var participants: [RtcParticipant] = []
    @Published var muted: Bool = false
    @Published var lastError: String = ""

    private var client: RtcClient?

    func connectTapped() {
        Task { await connect() }
    }

    func disconnectTapped() {
        Task { await disconnect() }
    }

    func toggleMicTapped() {
        Task { await toggleMic() }
    }

    func muteTargetTapped() {
        Task { await muteTarget() }
    }

    func kickTargetTapped() {
        Task { await kickTarget() }
    }

    private func connect() async {
        do {
            lastError = ""
            guard let endpoint = EndpointUrl.parseOrNull(backendBaseUrl) else {
                lastError = "backendBaseUrl 非法"
                return
            }

            let capturedToken = businessToken
            let authProvider = AnyAuthHeaderProvider {
                let token = capturedToken.trimmingCharacters(in: .whitespacesAndNewlines)
                return token.isEmpty ? nil : "Bearer \(token)"
            }

            let config = RtcConfig(backendBaseUrl: endpoint)
            let rtc = RtcClient.create(config: config, authHeaderProvider: authProvider)
            rtc.onStateChanged = { [weak self] state in
                Task { @MainActor in self?.stateText = Self.describe(state) }
            }
            rtc.onParticipantsChanged = { [weak self] list in
                Task { @MainActor in self?.participants = list }
            }
            rtc.onEvent = { [weak self] event in
                guard case .error(let message) = event else { return }
                Task { @MainActor in self?.lastError = message }
            }

            client = rtc
            try await rtc.connect(ConnectParams(roomId: roomId, displayName: displayName, role: .host))
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func disconnect() async {
        await client?.disconnect()
        participants = []
        muted = false
    }

    private func toggleMic() async {
        guard let client else { return }
        do {
            try await client.setMicrophoneMuted(!muted)
            muted.toggle()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func muteTarget() async {
        guard let client else { return }
        let identity = targetIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identity.isEmpty else { return }
        do {
            try await client.muteParticipant(identity: identity, muted: true)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func kickTarget() async {
        guard let client else { return }
        let identity = targetIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identity.isEmpty else { return }
        do {
            try await client.kickParticipant(identity: identity)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func describe(_ state: RtcRoomState) -> String {
        switch state {
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .error:
            return "error"
        @unknown default:
            return "unknown"
        }
    }
}
