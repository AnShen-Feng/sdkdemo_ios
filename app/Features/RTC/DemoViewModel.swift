// Relative path: partnersdk_demo_ios/app/Features/RTC/DemoViewModel.swift

import Foundation
import partnersdk_ios

@MainActor
final class DemoViewModel: ObservableObject {
    enum DemoRole: String, CaseIterable, Identifiable {
        case host
        case speaker
        case listener

        var id: String { rawValue }

        var title: String {
            switch self {
            case .host:
                return "主持人"
            case .speaker:
                return "发言成员"
            case .listener:
                return "听众成员"
            }
        }

        var sdkRole: RoomRole {
            switch self {
            case .host:
                return .host
            case .speaker:
                return .speaker
            case .listener:
                return .listener
            }
        }
    }

    @Published var gatewayBaseUrl: String = "http://192.168.3.140:3003"
    @Published var roomId: String = "demo-room"
    @Published var displayName: String = "DemoUser"
    @Published var businessToken: String = ""
    @Published var selectedRole: DemoRole = .speaker
    @Published var targetIdentity: String = ""
    @Published var stateText: String = "状态：未连接"
    @Published var participants: [RtcParticipant] = []
    @Published var muted: Bool = false
    @Published var lastError: String = ""
    @Published var lastMessage: String = ""
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var hostIdentity: String?

    private var client: RtcClient?
    private var backend: DemoRtcBackend?
    private var backendToken: String?
    private var activeRoomId: String?
    private var localRole: DemoRole = .speaker

    var connectButtonTitle: String {
        isConnected ? "断开连接" : "连接房间"
    }

    var micButtonTitle: String {
        muted ? "取消本地静音" : "本地静音"
    }

    func connectButtonTapped() {
        Task {
            if isConnected {
                await disconnect()
            } else {
                await connect()
            }
        }
    }

    func toggleMicTapped() {
        Task { await setMicMuted(!muted) }
    }

    func refreshParticipantsTapped() {
        Task { await refreshParticipants() }
    }

    func muteTargetTapped() {
        Task { await muteTarget(muted: true) }
    }

    func unmuteTargetTapped() {
        Task { await muteTarget(muted: false) }
    }

    func kickTargetTapped() {
        Task { await kickTarget() }
    }

    func setTargetHostTapped() {
        Task { await setTargetRole(.host) }
    }

    func setTargetSpeakerTapped() {
        Task { await setTargetRole(.speaker) }
    }

    func setTargetListenerTapped() {
        Task { await setTargetRole(.listener) }
    }

    func roleTag(for participant: RtcParticipant) -> String {
        participant.identity == hostIdentity ? "主持人" : "成员"
    }

    func displayName(for participant: RtcParticipant) -> String {
        participant.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? participant.identity : participant.name
    }

    private func connect() async {
        do {
            lastError = ""
            lastMessage = ""
            let accessToken = normalizedAccessToken()
            guard !accessToken.isEmpty else {
                lastError = "请先填写 WebRTC 访问令牌"
                return
            }
            guard let endpoint = EndpointUrl.parseOrNull(gatewayBaseUrl) else {
                lastError = "Gateway 地址不合法"
                return
            }

            client?.close()
            let rtc = RtcClient.create(config: RtcConfig())
            let backend = DemoRtcBackend(gatewayBaseUrl: endpoint)
            bindCallbacks(for: rtc)
            client = rtc
            self.backend = backend

            let normalizedRoomId = roomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "demo-room" : roomId.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "User-\(Int(Date().timeIntervalSince1970) % 10000)" : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            localRole = selectedRole

            lastMessage = "宿主开始 join HTTP 请求 roomId=\(normalizedRoomId), user=\(normalizedName), role=\(selectedRole.sdkRole.rawValue)"
            backendToken = accessToken
            activeRoomId = normalizedRoomId
            let params = ConnectParams(roomId: normalizedRoomId, displayName: normalizedName, role: selectedRole.sdkRole)
            try await rtc.connect(
                params,
                credentialsProvider: AnyMediaCredentialsProvider { requestParams in
                    try await backend.joinRoom(
                        accessToken: accessToken,
                        roomId: requestParams.roomId,
                        displayName: requestParams.displayName,
                        role: requestParams.role,
                        ttlSeconds: Self.defaultTTLSeconds
                    )
                }
            )
            lastMessage = "媒体服务连接成功"
            muted = false
            if selectedRole != .host {
                hostIdentity = nil
            }
        } catch {
            lastError = "连接失败：\(error.localizedDescription)"
        }
    }

    private func disconnect() async {
        lastMessage = "主动断开连接"
        await client?.disconnect()
        backendToken = nil
        activeRoomId = nil
        participants = []
        muted = false
        hostIdentity = nil
        isConnected = false
        isConnecting = false
        stateText = "状态：未连接"
    }

    private func setMicMuted(_ muted: Bool) async {
        guard let client else { return }
        do {
            try await client.setMicrophoneMuted(muted)
            self.muted = muted
            lastMessage = "本地麦克风状态: muted=\(muted)"
        } catch {
            lastError = "本地麦克风操作失败：\(error.localizedDescription)"
        }
    }

    private func refreshParticipants() async {
        guard let backend, let token = backendToken, let roomId = activeRoomId else { return }
        do {
            let list = try await backend.listParticipants(accessToken: token, roomId: roomId)
            participants = list
            updateHostFromParticipantsIfNeeded(list)
            lastMessage = "命令成功: listParticipants size=\(list.count)"
        } catch {
            lastError = "命令失败: listParticipants：\(error.localizedDescription)"
        }
    }

    private func muteTarget(muted: Bool) async {
        guard let backend, let token = backendToken, let roomId = activeRoomId, let identity = normalizedTargetIdentity() else { return }
        do {
            try await backend.muteParticipant(accessToken: token, roomId: roomId, identity: identity, muted: muted)
            lastMessage = "命令成功: mute identity=\(identity) muted=\(muted)"
        } catch {
            lastError = "命令失败: mute identity=\(identity) muted=\(muted)：\(error.localizedDescription)"
        }
    }

    private func kickTarget() async {
        guard let backend, let token = backendToken, let roomId = activeRoomId, let identity = normalizedTargetIdentity() else { return }
        do {
            try await backend.kickParticipant(accessToken: token, roomId: roomId, identity: identity)
            lastMessage = "命令成功: kick identity=\(identity)"
        } catch {
            lastError = "命令失败: kick identity=\(identity)：\(error.localizedDescription)"
        }
    }

    private func setTargetRole(_ role: DemoRole) async {
        guard let backend, let token = backendToken, let roomId = activeRoomId, let identity = normalizedTargetIdentity() else { return }
        do {
            try await backend.setParticipantRole(accessToken: token, roomId: roomId, identity: identity, role: role.sdkRole)
            if role == .host {
                hostIdentity = identity
            } else if hostIdentity == identity {
                hostIdentity = nil
            }
            lastMessage = "命令成功: setRole identity=\(identity) role=\(role.sdkRole.rawValue)"
        } catch {
            lastError = "命令失败: setRole identity=\(identity) role=\(role.sdkRole.rawValue)：\(error.localizedDescription)"
        }
    }

    private func bindCallbacks(for rtc: RtcClient) {
        rtc.onStateChanged = { [weak self] state in
            Task { @MainActor in self?.apply(state: state) }
        }
        rtc.onParticipantsChanged = { [weak self] list in
            Task { @MainActor in
                self?.participants = list
                self?.updateHostFromParticipantsIfNeeded(list)
            }
        }
        rtc.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event: event) }
        }
    }

    private func apply(state: RtcRoomState) {
        switch state {
        case .disconnected:
            stateText = "状态：未连接"
            isConnected = false
            isConnecting = false
        case .connecting:
            stateText = "状态：连接中..."
            isConnecting = true
        case .connected:
            stateText = "状态：已连接"
            isConnected = true
            isConnecting = false
        case .error:
            stateText = "状态：错误"
            isConnected = false
            isConnecting = false
        @unknown default:
            stateText = "状态：未知"
            isConnected = false
            isConnecting = false
        }
    }

    private func handle(event: RtcEvent) {
        switch event {
        case .participantJoined(let identity):
            lastMessage = "\(identity) 加入房间"
        case .participantLeft(let identity):
            lastMessage = "\(identity) 离开房间"
        case .error(let message):
            lastError = "错误：\(message)"
        @unknown default:
            break
        }
    }

    private func updateHostFromParticipantsIfNeeded(_ list: [RtcParticipant]) {
        if localRole == .host, let localIdentity = list.first(where: { $0.isLocal })?.identity, !localIdentity.isEmpty {
            hostIdentity = localIdentity
        }
    }

    private func normalizedTargetIdentity() -> String? {
        let identity = targetIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
        if identity.isEmpty {
            lastError = "请先输入目标 identity"
            return nil
        }
        return identity
    }

    private func normalizedAccessToken() -> String {
        businessToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let defaultTTLSeconds = 3600
}
