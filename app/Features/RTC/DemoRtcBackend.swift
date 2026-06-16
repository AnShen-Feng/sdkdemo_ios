// Relative path: partnersdk_demo_ios/app/Features/RTC/DemoRtcBackend.swift

import Foundation
import partnersdk_ios

actor DemoRtcBackend {
    private let gatewayBaseUrl: URL
    private let urlSession: URLSession
    private let apiPrefix: String

    init(
        gatewayBaseUrl: EndpointUrl,
        urlSession: URLSession = .shared,
        apiPrefix: String = "/api/v1"
    ) {
        self.gatewayBaseUrl = URL(string: gatewayBaseUrl.value)!
        self.urlSession = urlSession
        self.apiPrefix = apiPrefix
    }

    func joinRoom(
        accessToken: String,
        roomId: String,
        displayName: String?,
        role: RoomRole?,
        ttlSeconds: Int
    ) async throws -> MediaCredentials {
        let endpoint = resolve(path: joinedPath(apiPrefix, "rooms", roomId, "join"))
        let requestBody = JoinRoomRequest(name: nonBlank(displayName), role: role, ttlSeconds: ttlSeconds)
        let headers = authorizationHeaders(accessToken: accessToken)
        let initial = try await executeRaw(
            url: endpoint,
            method: "POST",
            headers: headers,
            body: requestBody,
            acceptCodes: [200, 201, 404]
        )
        if initial.statusCode == 404 {
            try await createRoom(accessToken: accessToken, roomId: roomId)
            let retry = try await executeRaw(
                url: endpoint,
                method: "POST",
                headers: headers,
                body: requestBody,
                acceptCodes: [200, 201]
            )
            return try parseJoinResponse(data: retry.data)
        }
        return try parseJoinResponse(data: initial.data)
    }

    func listParticipants(accessToken: String, roomId: String) async throws -> [RtcParticipant] {
        let response: ParticipantsResponse = try await executeJSON(
            url: resolve(path: joinedPath(apiPrefix, "commands", "rooms", roomId, "participants")),
            method: "GET",
            headers: authorizationHeaders(accessToken: accessToken),
            body: EmptyBody?.none,
            acceptCodes: [200]
        )
        return response.data.map {
            RtcParticipant(
                identity: $0.identity,
                name: $0.name,
                isLocal: false,
                isMicrophoneMuted: $0.isMicrophoneMuted ?? $0.muted ?? false
            )
        }
    }

    func muteParticipant(accessToken: String, roomId: String, identity: String, muted: Bool) async throws {
        _ = try await executeRaw(
            url: resolve(path: joinedPath(apiPrefix, "commands", "rooms", roomId, "participants", identity, "mute")),
            method: "POST",
            headers: authorizationHeaders(accessToken: accessToken),
            body: MuteParticipantRequest(muted: muted),
            acceptCodes: [200, 201]
        )
    }

    func kickParticipant(accessToken: String, roomId: String, identity: String) async throws {
        _ = try await executeRaw(
            url: resolve(path: joinedPath(apiPrefix, "commands", "rooms", roomId, "participants", identity, "kick")),
            method: "POST",
            headers: authorizationHeaders(accessToken: accessToken),
            body: EmptyBody(),
            acceptCodes: [200, 201]
        )
    }

    func setParticipantRole(accessToken: String, roomId: String, identity: String, role: RoomRole) async throws {
        _ = try await executeRaw(
            url: resolve(path: joinedPath(apiPrefix, "commands", "rooms", roomId, "participants", identity, "setRole")),
            method: "POST",
            headers: authorizationHeaders(accessToken: accessToken),
            body: SetParticipantRoleRequest(role: role),
            acceptCodes: [200, 201]
        )
    }

    private func createRoom(accessToken: String, roomId: String) async throws {
        _ = try await executeRaw(
            url: resolve(path: joinedPath(apiPrefix, "rooms")),
            method: "POST",
            headers: authorizationHeaders(accessToken: accessToken),
            body: CreateRoomRequest(roomId: roomId),
            acceptCodes: [200, 201]
        )
    }

    private func parseJoinResponse(data: Data) throws -> MediaCredentials {
        let response = try JSONDecoder().decode(JoinRoomResponse.self, from: data)
        guard let livekit = response.data.livekit,
              let url = nonBlank(livekit.url),
              let token = nonBlank(livekit.token) else {
            throw DemoRtcBackendError.invalidResponse
        }
        return MediaCredentials(url: url, token: token)
    }

    private func resolve(path: String) -> URL {
        var url = gatewayBaseUrl
        if !url.absoluteString.hasSuffix("/") {
            url.appendPathComponent("")
        }
        return url.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private func joinedPath(_ segments: String...) -> String {
        segments
            .flatMap { $0.split(separator: "/") }
            .map(String.init)
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private func authorizationHeaders(accessToken: String) -> [String: String] {
        let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = trimmed.hasPrefix("Bearer ") ? trimmed : "Bearer \(trimmed)"
        return ["Authorization": value, "Content-Type": "application/json"]
    }

    private func nonBlank(_ input: String?) -> String? {
        guard let input else { return nil }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func executeJSON<Response: Decodable, Body: Encodable>(
        url: URL,
        method: String,
        headers: [String: String],
        body: Body,
        acceptCodes: Set<Int>
    ) async throws -> Response {
        let raw = try await executeRaw(url: url, method: method, headers: headers, body: body, acceptCodes: acceptCodes)
        return try JSONDecoder().decode(Response.self, from: raw.data)
    }

    private func executeRaw<Body: Encodable>(
        url: URL,
        method: String,
        headers: [String: String],
        body: Body,
        acceptCodes: Set<Int>
    ) async throws -> RawResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if !(body is EmptyBody?) {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DemoRtcBackendError.invalidResponse
        }
        guard acceptCodes.contains(http.statusCode) else {
            throw DemoRtcBackendError.httpStatus(code: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return RawResponse(statusCode: http.statusCode, data: data)
    }
}

enum DemoRtcBackendError: LocalizedError {
    case invalidResponse
    case httpStatus(code: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid backend response"
        case .httpStatus(let code, let body):
            return "HTTP \(code): \(body)"
        }
    }
}

private struct RawResponse {
    let statusCode: Int
    let data: Data
}

private struct JoinRoomRequest: Encodable {
    let name: String?
    let role: RoomRole?
    let ttlSeconds: Int
}

private struct JoinRoomResponse: Decodable {
    let data: JoinRoomData
}

private struct JoinRoomData: Decodable {
    let livekit: MediaCredentials?
}

private struct ParticipantsResponse: Decodable {
    let data: [ParticipantItem]
}

private struct ParticipantItem: Decodable {
    let identity: String
    let name: String
    let isMicrophoneMuted: Bool?
    let muted: Bool?
}

private struct CreateRoomRequest: Encodable {
    let roomId: String
}

private struct MuteParticipantRequest: Encodable {
    let muted: Bool
}

private struct SetParticipantRoleRequest: Encodable {
    let role: RoomRole
}

private struct EmptyBody: Encodable {}
