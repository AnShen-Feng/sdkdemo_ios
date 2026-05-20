<!-- Relative path: partnersdk_demo_ios/README.md -->

# PartnerSDK iOS SDK 接入指引

## 简介

PartnerSDK iOS SDK 用于在 iOS 应用中接入实时音视频房间能力。SDK 负责向业务后端获取服务令牌、加入或创建媒体房间、连接媒体服务器、维护房间状态和参与者列表，并提供主持端控制命令。

当前推荐链路：

```text
iOS App -> 业务后端 -> 媒体服务器
```

iOS 端通常只需要配置业务后端地址和业务鉴权信息。媒体服务器地址和媒体房间连接 token 默认由业务后端按房间下发。

## 目录说明

| 路径 | 作用 |
|------|------|
| `app/` | Demo App SwiftUI 代码。 |
| `app/libs/partnersdk_ios.xcframework` | 本地二进制 SDK。 |
| `app/libs/PartnerSDKBinary.podspec` | 二进制 Pod 包装，声明 SDK 及依赖。 |
| `Podfile` | Demo App 的 CocoaPods 依赖配置。 |
| `partnersdk_ios.xcworkspace` | 安装 Pod 后打开和运行的工作区。 |

## 环境要求

| 项目 | 要求 |
|------|------|
| Xcode | 15+ |
| iOS Deployment Target | 13.0+，建议 15.0+ |
| Swift | 5.9+ |
| 依赖管理 | CocoaPods |

必需权限：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>需要使用麦克风加入实时音视频房间</string>
```

如果业务后端使用局域网 HTTP，例如 `http://192.168.3.140:3003`，宿主 App 需要在 `Info.plist` 中允许明文请求：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## CocoaPods 接入

`Podfile` 示例：

```ruby
source "https://cdn.cocoapods.org/"
source "https://github.com/livekit/podspecs.git"

platform :ios, "13.0"

use_frameworks! :linkage => :static

target "PartnerSDKDemo" do
  pod "PartnerSDKBinary", :path => "./app/libs/PartnerSDKBinary.podspec"
end
```

二进制 Podspec 示例：

```ruby
Pod::Spec.new do |s|
  s.name = "PartnerSDKBinary"
  s.version = "1.0.0"
  s.summary = "Binary wrapper for partnersdk_ios xcframework"
  s.platform = :ios, "13.0"
  s.swift_version = "5.9"
  s.source = { :path => "." }
  s.vendored_frameworks = "partnersdk_ios.xcframework"
  s.dependency "LiveKitClient"
end
```

安装依赖：

```bash
cd /Users/zero/Documents/Work/Squady/Squady/partnersdk_demo_ios
pod install
open partnersdk_ios.xcworkspace
```

## 快速开始

```swift
import Foundation
import partnersdk_ios

@MainActor
final class RoomController {
    private var client: RtcClient?

    func joinRoom(baseUrl: String, businessToken: String) async throws {
        let endpoint = try EndpointUrl.parse(baseUrl)
        let authProvider = AnyAuthHeaderProvider {
            let token = businessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty { return nil }
            return token.hasPrefix("Bearer ") ? token : "Bearer \(token)"
        }

        let config = RtcConfig(backendBaseUrl: endpoint)
        let rtc = RtcClient.create(config: config, authHeaderProvider: authProvider)

        rtc.onStateChanged = { state in
            print("room state: \(state)")
        }
        rtc.onParticipantsChanged = { participants in
            print("participants: \(participants.count)")
        }
        rtc.onEvent = { event in
            print("room event: \(event)")
        }

        client = rtc
        try await rtc.connect(
            ConnectParams(
                roomId: "demo-room",
                displayName: "ios-user",
                role: .speaker
            )
        )
    }

    func leaveRoom() async {
        await client?.disconnect()
    }
}
```

## 推荐接入流程

```text
1. 使用 EndpointUrl.parse 校验业务后端地址
2. 实现 AuthHeaderProvider 或使用 AnyAuthHeaderProvider 提供业务鉴权头
3. 创建 RtcConfig
4. 调用 RtcClient.create 创建 SDK 客户端
5. 设置 onStateChanged / onParticipantsChanged / onEvent 监听状态、参与者和事件
6. 调用 connect(ConnectParams) 加入媒体房间
7. 根据业务角色调用 setMicrophoneMuted / listParticipants / muteParticipant / kickParticipant / setParticipantRole
8. 页面退出时调用 disconnect，页面销毁或不再复用时调用 close
```

## SDK 接口总览

| 接口 | 作用 | 主要输入 | 主要输出 |
|------|------|----------|----------|
| `EndpointUrl.parse(...)` | 校验并标准化 URL 字符串 | URL 字符串 | `EndpointUrl` 或抛错 |
| `EndpointUrl.parseOrNull(...)` | 校验并标准化 URL 字符串，失败返回 nil | URL 字符串 | `EndpointUrl?` |
| `AnyAuthHeaderProvider(...)` | 用闭包提供业务后端鉴权头 | `() async -> String?` | `AuthHeaderProvider` 实例 |
| `RtcConfig(...)` | 配置业务后端地址、接口路径和 token TTL | URL、路径、TTL | `RtcConfig` |
| `RtcClient.create(...)` | 创建 SDK 客户端 | `RtcConfig`、鉴权提供者、`URLSession` | `RtcClient` |
| `client.connect(...)` | 获取服务令牌并连接媒体房间 | `ConnectParams` | 无直接返回，结果走状态和事件 |
| `client.disconnect()` | 断开当前媒体房间并清理本地状态 | 无 | 无 |
| `client.close()` | 释放客户端资源，关闭回调并断开连接 | 无 | 无 |
| `client.setMicrophoneMuted(...)` | 设置本地麦克风静音状态 | `Bool` | 无 |
| `client.listParticipants(...)` | 拉取参与者列表 | 可选 `roomId` | `[RtcParticipant]` |
| `client.muteParticipant(...)` | 主持端静音或取消静音参与者 | `identity`、`muted` | 无 |
| `client.kickParticipant(...)` | 主持端踢出参与者 | `identity` | 无 |
| `client.setParticipantRole(...)` | 主持端设置参与者角色 | `identity`、`RoomRole` | 无 |
| `client.state` | 当前房间状态快照 | 直接读取 | `RtcRoomState` |
| `client.participants` | 当前参与者快照 | 直接读取 | `[RtcParticipant]` |
| `client.onStateChanged` | 订阅房间状态变化 | `StateHandler` | 回调 `RtcRoomState` |
| `client.onParticipantsChanged` | 订阅参与者列表变化 | `ParticipantsHandler` | 回调 `[RtcParticipant]` |
| `client.onEvent` | 订阅一次性事件 | `EventHandler` | 回调 `RtcEvent` |

## API 详细说明

### EndpointUrl

作用：统一校验和标准化 URL 字符串，避免非法业务后端地址或媒体服务器地址进入后续网络流程。

```swift
public struct EndpointUrl: Hashable, Sendable {
    public let value: String

    public static func parse(_ input: String) throws -> EndpointUrl
    public static func parseOrNull(_ input: String) -> EndpointUrl?
}
```

| 字段 / 接口 | 类型 | 含义 |
|-------------|------|------|
| `value` | `String` | 标准化后的 URL 字符串。尾部 `/` 会被移除。 |
| `parse(_:)` | `(String) throws -> EndpointUrl` | 输入非法时抛出 `EndpointUrlError.invalidUrl`。 |
| `parseOrNull(_:)` | `(String) -> EndpointUrl?` | 输入非法时返回 `nil`，适合表单校验。 |

入参：

| 参数 | 类型 | 必填 | 含义 |
|------|------|------|------|
| `input` | `String` | 是 | URL 字符串，例如 `http://192.168.3.140:3003` 或 `https://api.example.com`。 |

出参：

| 类型 | 含义 |
|------|------|
| `EndpointUrl` | 可用于 `RtcConfig.backendBaseUrl` 或 `RtcConfig.webrtcServiceUrl` 的 URL 封装。 |
| `nil` | 仅 `parseOrNull(_:)` 返回，表示 URL 非法。 |

### AuthHeaderProvider / AnyAuthHeaderProvider

作用：由宿主 App 按需提供业务后端鉴权信息。SDK 在请求业务后端 token 接口时会把返回值写入 `Authorization` Header。

```swift
public protocol AuthHeaderProvider: Sendable {
    func getAuthorizationHeaderValue() async -> String?
}

public struct AnyAuthHeaderProvider: AuthHeaderProvider {
    public init(_ block: @escaping @Sendable () async -> String?)
    public func getAuthorizationHeaderValue() async -> String?
}
```

| 接口 | 作用 | 返回 |
|------|------|------|
| `getAuthorizationHeaderValue()` | 获取业务后端鉴权头。 | `String?`，例如 `Bearer <token>`。 |
| `AnyAuthHeaderProvider.init(_:)` | 用闭包快速创建鉴权提供者。 | `AnyAuthHeaderProvider`。 |

注意：

- 返回 `nil` 表示本次请求不附加 `Authorization` Header。
- 如果业务后端要求 `Bearer` 前缀，宿主 App 应在此处拼接完整值。
- SDK 不持久化业务 token，业务 App 负责 token 生命周期管理。

### RtcConfig

作用：配置 SDK 访问业务后端和媒体房间网关接口所需的信息。

```swift
public struct RtcConfig: Sendable {
    public let webrtcServiceUrl: EndpointUrl?
    public let backendBaseUrl: EndpointUrl
    public let backendTokenPath: String
    public let apiPrefix: String
    public let ttlSeconds: Int

    public init(
        webrtcServiceUrl: EndpointUrl? = nil,
        backendBaseUrl: EndpointUrl,
        backendTokenPath: String = "/webrtc/token",
        apiPrefix: String = "/webrtc",
        ttlSeconds: Int = 3600
    )
}
```

| 字段 | 类型 | 必填 | 默认值 | 含义 |
|------|------|------|--------|------|
| `webrtcServiceUrl` | `EndpointUrl?` | 否 | `nil` | 可选固定媒体服务器地址。为 `nil` 时使用业务后端 token 接口返回的地址。字段名保持 SDK API 不变。 |
| `backendBaseUrl` | `EndpointUrl` | 是 | 无 | 业务后端基础地址。 |
| `backendTokenPath` | `String` | 否 | `/webrtc/token` | 获取服务令牌的业务后端路径。 |
| `apiPrefix` | `String` | 否 | `/webrtc` | 房间和主持端命令接口前缀。 |
| `ttlSeconds` | `Int` | 否 | `3600` | 请求服务令牌和媒体房间凭证时使用的有效期，单位秒。 |

业务后端接口约定：

| 阶段 | 方法和路径 | 请求体 | 返回 |
|------|------------|--------|------|
| 获取服务令牌 | `POST {backendTokenPath}` | `{ "userName": String?, "ttlSeconds": Int }` | `{ "webrtcServiceUrl": String, "token": String, "expiresIn": Int? }` |
| 加入媒体房间 | `POST {apiPrefix}/rooms/{roomId}/join` | `{ "name": String?, "role": RoomRole?, "ttlSeconds": Int }` | `{ "data": { "connection": { "url": String, "token": String } } }` |
| 创建媒体房间 | `POST {apiPrefix}/rooms` | `{ "roomId": String }` | HTTP 200 / 201 |
| 拉取参与者 | `GET {apiPrefix}/commands/rooms/{roomId}/participants` | 无 | `[{ "identity": String?, "name": String? }]` |
| 静音参与者 | `POST {apiPrefix}/commands/rooms/{roomId}/participants/{identity}/mute` | `{ "muted": Bool }` | HTTP 200 / 201 |
| 踢出参与者 | `POST {apiPrefix}/commands/rooms/{roomId}/participants/{identity}/kick` | 无 | HTTP 200 / 201 |
| 设置参与者角色 | `POST {apiPrefix}/commands/rooms/{roomId}/participants/{identity}/setRole` | `{ "role": RoomRole }` | HTTP 200 / 201 |

### RtcClient.create

作用：创建 SDK 主客户端。客户端创建后可以绑定回调并调用 `connect`。

```swift
@MainActor
public final class RtcClient {
    public static func create(
        config: RtcConfig,
        authHeaderProvider: AuthHeaderProvider? = nil,
        urlSession: URLSession = .shared
    ) -> RtcClient
}
```

入参：

| 参数 | 类型 | 必填 | 默认值 | 含义 |
|------|------|------|--------|------|
| `config` | `RtcConfig` | 是 | 无 | SDK 配置。 |
| `authHeaderProvider` | `AuthHeaderProvider?` | 否 | `nil` | 业务后端鉴权头提供者。 |
| `urlSession` | `URLSession` | 否 | `.shared` | 网络请求会话。一般使用默认值，测试时可注入自定义实例。 |

出参：

| 类型 | 含义 |
|------|------|
| `RtcClient` | SDK 客户端实例。所有公开方法均在 `@MainActor` 上调用。 |

### client.connect

作用：连接媒体房间。SDK 会先向业务后端请求服务令牌，再调用房间 join 接口获取媒体房间连接凭证，最后连接媒体服务器。

```swift
public func connect(_ params: ConnectParams) async throws
```

入参：

```swift
public struct ConnectParams: Sendable {
    public let roomId: String
    public let displayName: String?
    public let role: RoomRole?

    public init(roomId: String, displayName: String? = nil, role: RoomRole? = nil)
}
```

| 字段 | 类型 | 必填 | 默认值 | 含义 |
|------|------|------|--------|------|
| `roomId` | `String` | 是 | 无 | 业务侧房间 ID。若加入接口返回 404，SDK 会创建该房间并重试加入。 |
| `displayName` | `String?` | 否 | `nil` | 参与者显示名，会传给业务后端和媒体房间。 |
| `role` | `RoomRole?` | 否 | `nil` | 入房角色。为 `nil` 时由后端或默认策略决定。 |

执行过程：

```text
1. 如果当前已有连接，先 disconnect
2. state 变为 .connecting
3. POST /webrtc/token 获取服务令牌和媒体服务器地址
4. POST /webrtc/rooms/{roomId}/join 获取媒体房间连接凭证
5. 如果 join 返回 404，POST /webrtc/rooms 创建房间并重试 join
6. 连接媒体服务器
7. 更新 participants
8. state 变为 .connected
```

出参：无直接返回值。成功或失败通过以下方式观察：

| 输出 | 含义 |
|------|------|
| `client.state` / `onStateChanged` | 输出 `.connecting`、`.connected`、`.error` 等状态。 |
| `client.participants` / `onParticipantsChanged` | 输出本地和远端参与者列表。 |
| `client.onEvent` | 失败时输出 `.error(message:)`，参与者变化时输出事件。 |
| `throws` | 网络失败、业务后端非 2xx、返回结构不符合预期、客户端已关闭等错误会抛出。 |

### client.disconnect

作用：断开当前媒体房间连接并重置本地状态。

```swift
public func disconnect() async
```

入参：无。

出参：无。

行为：

| 行为 | 说明 |
|------|------|
| 断开媒体房间 | 如果当前已连接，会断开底层连接。 |
| 清理连接上下文 | 清空当前 roomId、服务令牌、媒体服务器地址。 |
| 清空参与者 | `participants` 变为 `[]`。 |
| 更新状态 | `state` 变为 `.disconnected`，触发 `onStateChanged`。 |

### client.close

作用：释放客户端资源。调用后该客户端不可再用于 `connect`。

```swift
public func close()
```

入参：无。

出参：无。

行为：

| 行为 | 说明 |
|------|------|
| 标记关闭 | 后续调用 `connect` 会抛出 `NetworkError.clientClosed`。 |
| 清空回调 | `onEvent`、`onStateChanged`、`onParticipantsChanged` 置空。 |
| 异步断开 | 内部会触发 `disconnect()` 清理连接。 |

建议：页面只是临时离开房间时使用 `disconnect()`；页面销毁且不再复用客户端时使用 `close()`。

### client.setMicrophoneMuted

作用：设置本地麦克风静音状态。

```swift
public func setMicrophoneMuted(_ muted: Bool) async throws
```

入参：

| 参数 | 类型 | 含义 |
|------|------|------|
| `muted` | `Bool` | `true` 表示静音本地麦克风，`false` 表示打开本地麦克风。 |

出参：无直接返回值。

注意：

- 调用前应确保 App 已获得麦克风权限。
- 未连接媒体房间时调用会直接返回，不抛错。
- 操作成功后 SDK 会刷新参与者快照。

### client.listParticipants

作用：从业务后端拉取指定媒体房间的参与者列表。

```swift
public func listParticipants(roomId: String? = nil) async throws -> [RtcParticipant]
```

入参：

| 参数 | 类型 | 必填 | 默认值 | 含义 |
|------|------|------|--------|------|
| `roomId` | `String?` | 否 | `nil` | 指定房间 ID。为空时使用当前已连接房间 ID。 |

出参：

| 类型 | 含义 |
|------|------|
| `[RtcParticipant]` | 参与者列表。通过命令接口拉取的参与者 `isLocal` 通常为 `false`。 |

注意：如果当前没有可用 roomId 或服务令牌，返回空数组。

### client.muteParticipant

作用：主持端命令，静音或取消静音指定参与者。

```swift
public func muteParticipant(identity: String, muted: Bool) async throws
```

入参：

| 参数 | 类型 | 含义 |
|------|------|------|
| `identity` | `String` | 目标参与者在媒体房间中的 identity。 |
| `muted` | `Bool` | `true` 表示静音目标，`false` 表示取消静音目标。 |

出参：无直接返回值。

注意：

- 该接口依赖当前连接房间的 roomId 和服务令牌。
- 权限由业务后端或媒体房间控制服务判断。非主持人调用可能返回 HTTP 错误。

### client.kickParticipant

作用：主持端命令，踢出指定参与者。

```swift
public func kickParticipant(identity: String) async throws
```

入参：

| 参数 | 类型 | 含义 |
|------|------|------|
| `identity` | `String` | 目标参与者在媒体房间中的 identity。 |

出参：无直接返回值。

### client.setParticipantRole

作用：主持端命令，设置指定参与者的房间角色。

```swift
public func setParticipantRole(identity: String, role: RoomRole) async throws
```

入参：

| 参数 | 类型 | 含义 |
|------|------|------|
| `identity` | `String` | 目标参与者在媒体房间中的 identity。 |
| `role` | `RoomRole` | 目标角色。 |

出参：无直接返回值。

## 数据模型说明

### RoomRole

作用：定义参与者在房间内的业务角色。

```swift
public enum RoomRole: String, Sendable, Codable {
    case host = "HOST"
    case speaker = "SPEAKER"
    case listener = "LISTENER"
}
```

| 值 | 含义 |
|----|------|
| `.host` | 主持人，通常可执行静音、踢人、改角色等主持端命令。 |
| `.speaker` | 发言成员，通常可入房并使用麦克风发言。 |
| `.listener` | 听众成员，通常以收听为主。 |

### RtcRoomState

作用：表示当前媒体房间连接状态。

```swift
public enum RtcRoomState: Sendable, Codable {
    case disconnected
    case connecting
    case connected
    case error
}
```

| 值 | 含义 |
|----|------|
| `.disconnected` | 未连接或已断开。 |
| `.connecting` | 正在请求服务令牌、加入房间或连接媒体服务器。 |
| `.connected` | 已连接媒体房间。 |
| `.error` | 连接或命令流程发生错误。 |

### RtcParticipant

作用：表示一个媒体房间参与者。

```swift
public struct RtcParticipant: Hashable, Sendable, Codable {
    public let identity: String
    public let name: String
    public let isLocal: Bool
}
```

| 字段 | 类型 | 含义 |
|------|------|------|
| `identity` | `String` | 参与者唯一标识。主持端命令使用该字段定位目标。 |
| `name` | `String` | 参与者显示名。可能为空，业务侧可回退展示 `identity`。 |
| `isLocal` | `Bool` | 是否为当前 App 本地参与者。 |

### RtcEvent

作用：表示一次性事件，可用于 toast、日志或错误展示。

```swift
public enum RtcEvent: Sendable {
    case participantJoined(identity: String)
    case participantLeft(identity: String)
    case error(message: String)
}
```

| 事件 | 字段 | 含义 |
|------|------|------|
| `.participantJoined` | `identity` | 有远端参与者加入。 |
| `.participantLeft` | `identity` | 有远端参与者离开。 |
| `.error` | `message` | SDK 或底层连接发生错误。 |

### RtcRoomInfo

作用：描述房间信息。该模型用于与后端协议保持类型一致，当前 Demo 主要使用参与者和状态接口。

```swift
public struct RtcRoomInfo: Sendable, Codable {
    public let roomId: String
    public let status: RtcRoomState
    public let maxParticipants: Int?
    public let metadata: [String: JSONValue]?
    public let hostIdentity: String
    public let participantCount: Int?
}
```

| 字段 | 类型 | 含义 |
|------|------|------|
| `roomId` | `String` | 房间 ID。 |
| `status` | `RtcRoomState` | 房间状态。 |
| `maxParticipants` | `Int?` | 最大参与者数量，后端未返回时为 `nil`。 |
| `metadata` | `[String: JSONValue]?` | 房间元数据。 |
| `hostIdentity` | `String` | 主持人 identity。 |
| `participantCount` | `Int?` | 当前参与者数量，后端未返回时为 `nil`。 |

### MediaCredentials

作用：表示媒体房间连接凭证。SDK 内部通过 join 接口解析该模型并用于连接媒体服务器。

```swift
public struct MediaCredentials: Sendable, Codable {
    public let url: String
    public let token: String
}
```

| 字段 | 类型 | 含义 |
|------|------|------|
| `url` | `String` | 媒体服务器连接地址。 |
| `token` | `String` | 媒体房间连接 token。 |

### JSONValue

作用：表示类型安全的 JSON 值，避免使用 `Any` 承载业务数据。

```swift
public enum JSONValue: Sendable, Codable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
}
```

| 值 | 含义 |
|----|------|
| `.string` | 字符串。 |
| `.int` | 整数。 |
| `.double` | 浮点数。 |
| `.bool` | 布尔值。 |
| `.object` | JSON 对象。 |
| `.array` | JSON 数组。 |
| `.null` | JSON null。 |

### RtcClient.NetworkError

作用：SDK 网络和客户端生命周期错误。

```swift
public enum NetworkError: Error {
    case invalidResponse
    case httpStatus(code: Int, body: String)
    case clientClosed
}
```

| 值 | 含义 |
|----|------|
| `.invalidResponse` | 后端返回结构不符合 SDK 预期，或响应不是有效 HTTP 响应。 |
| `.httpStatus(code:body:)` | 后端返回非预期 HTTP 状态码。`code` 为状态码，`body` 为响应正文。 |
| `.clientClosed` | 客户端已调用 `close()`，不允许再次连接。 |

## 状态和事件模型

### client.state

```swift
public private(set) var state: RtcRoomState
```

| 状态 | 触发时机 |
|------|----------|
| `.disconnected` | 初始状态、主动断开、底层连接断开。 |
| `.connecting` | 调用 `connect` 后开始请求服务令牌和连接媒体服务器。 |
| `.connected` | 媒体房间连接成功并完成参与者快照刷新。 |
| `.error` | `connect` 流程中发生错误。 |

### client.participants

```swift
public private(set) var participants: [RtcParticipant]
```

| 内容 | 含义 |
|------|------|
| 本地参与者 | `isLocal = true`，通常位于数组首位。 |
| 远端参与者 | `isLocal = false`，来自媒体房间远端参与者快照。 |
| 空数组 | 未连接、已断开或尚未获取到参与者。 |

### onStateChanged

```swift
public typealias StateHandler = @Sendable (RtcRoomState) -> Void
public var onStateChanged: StateHandler?
```

作用：监听 `state` 变化。适合驱动连接按钮、状态文案和 loading 展示。

### onParticipantsChanged

```swift
public typealias ParticipantsHandler = @Sendable ([RtcParticipant]) -> Void
public var onParticipantsChanged: ParticipantsHandler?
```

作用：监听 `participants` 变化。适合刷新参与者列表。

### onEvent

```swift
public typealias EventHandler = @Sendable (RtcEvent) -> Void
public var onEvent: EventHandler?
```

作用：监听一次性事件。适合展示参与者加入/离开提示和错误 toast。

## 主持端功能建议

| 功能 | 推荐调用 | UI 输入 |
|------|----------|---------|
| 刷新参与者 | `listParticipants()` | 无，或指定 roomId。 |
| 静音目标 | `muteParticipant(identity: muted: true)` | 目标 `identity`。 |
| 取消静音目标 | `muteParticipant(identity: muted: false)` | 目标 `identity`。 |
| 踢出目标 | `kickParticipant(identity:)` | 目标 `identity`。 |
| 设置主持人 | `setParticipantRole(identity: role: .host)` | 目标 `identity`。 |
| 设置发言成员 | `setParticipantRole(identity: role: .speaker)` | 目标 `identity`。 |
| 设置听众成员 | `setParticipantRole(identity: role: .listener)` | 目标 `identity`。 |

## 常见问题

### 业务后端连接失败

检查：

1. `backendBaseUrl` 是否指向业务后端，例如 `http://192.168.3.140:3003`。
2. 真机和后端机器是否在同一局域网。
3. 业务后端是否监听 `0.0.0.0`，而不是只监听 `localhost`。
4. iOS 是否允许 HTTP 明文请求。
5. 手机浏览器是否能打开业务后端健康检查地址。
6. `AuthHeaderProvider` 是否返回了业务后端要求的鉴权头。

### 连接后没有声音

检查：

1. `Info.plist` 是否配置麦克风权限说明。
2. 用户是否授予麦克风权限。
3. 是否调用了 `setMicrophoneMuted(true)` 导致本地静音。
4. `state` 是否为 `.connected`。
5. `participants` 是否包含本地参与者和远端参与者。

### 主持端命令失败

检查：

1. 当前用户是否具备主持端权限。
2. `identity` 是否填写目标参与者的完整 identity。
3. 当前是否已连接房间并持有服务令牌。
4. 业务后端命令接口路径是否与 `apiPrefix` 匹配。
5. 错误是否为 `NetworkError.httpStatus(code:body:)`，可查看 `body` 获取后端原因。

### Join 返回 404

SDK 会自动调用创建房间接口并重试一次加入。如果仍失败，检查：

1. `apiPrefix` 是否正确。
2. 业务后端是否支持 `POST /webrtc/rooms` 创建房间。
3. 业务 token 是否有创建房间权限。

## 版本信息

- SDK 包名：`partnersdk_ios`
- Demo 接入方式：本地 `xcframework` + CocoaPods 二进制 Pod
- Pod 包装版本：`PartnerSDKBinary 1.0.0`
