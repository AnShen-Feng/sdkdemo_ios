<!-- Relative path: partnersdk_demo_ios/README.md -->

# PartnerSDK iOS Demo 接入指引

## 简介

本 Demo 展示如何通过本地二进制 `partnersdk_ios.xcframework` 接入实时语音房间能力。

当前接入链路与 Android Demo 保持一致：

```text
iOS Demo -> WebRTC Gateway HTTP API -> LiveKit Media Server
```

职责划分：

- Demo 负责自行发起 HTTP 请求：join 房间、创建房间、刷新参与者、静音、踢人、改角色。
- SDK 只接收 `MediaCredentials`，负责连接 LiveKit、维护连接状态、参与者快照和本地麦克风能力。
- SDK 不再负责请求业务后端 token，也不再持有业务 HTTP API 细节。

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

如果 Gateway 使用局域网 HTTP，例如 `http://192.168.3.140:3003`，宿主 App 需要在 `Info.plist` 中允许明文请求：

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
    private let gateway = DemoRtcBackend(gatewayBaseUrl: try! EndpointUrl.parse("https://gateway.example.com"))

    func joinRoom(accessToken: String) async throws {
        let rtc = RtcClient.create(config: RtcConfig())
        let params = ConnectParams(
            roomId: "demo-room",
            displayName: "ios-user",
            role: .speaker
        )

        rtc.onStateChanged = { state in print("room state: \(state)") }
        rtc.onParticipantsChanged = { participants in print("participants: \(participants.count)") }
        rtc.onEvent = { event in print("room event: \(event)") }

        client = rtc
        try await rtc.connect(
            params,
            credentialsProvider: AnyMediaCredentialsProvider { requestParams in
                try await gateway.joinRoom(
                    accessToken: accessToken,
                    roomId: requestParams.roomId,
                    displayName: requestParams.displayName,
                    role: requestParams.role,
                    ttlSeconds: 3600
                )
            }
        )
    }

    func leaveRoom() async {
        await client?.disconnect()
    }
}
```

也可以由宿主先完成 HTTP 请求，再直接传入凭证：

```swift
let credentials = MediaCredentials(url: livekitUrl, token: livekitToken)
try await client.connect(params, credentials: credentials)
```

## 推荐接入流程

```text
1. 使用 EndpointUrl.parse 校验 Gateway 地址
2. 宿主保存 WebRTC Gateway access token
3. 创建 RtcClient.create(config: RtcConfig())
4. 设置 onStateChanged / onParticipantsChanged / onEvent 监听状态、参与者和事件
5. 在 AnyMediaCredentialsProvider 中自行请求 POST /api/v1/rooms/{roomId}/join
6. 从响应 data.livekit.url / data.livekit.token 构造 MediaCredentials
7. SDK 使用 MediaCredentials 连接媒体服务
8. 主持端命令由宿主继续调用 Gateway HTTP API
9. 页面退出时调用 disconnect，页面销毁或不再复用时调用 close
```

## Gateway API 约定

| 阶段 | 方法和路径 | 请求体 | 返回 |
|------|------------|--------|------|
| 加入媒体房间 | `POST /api/v1/rooms/{roomId}/join` | `{ "name": String?, "role": RoomRole?, "ttlSeconds": Int }` | `{ "data": { "livekit": { "url": String, "token": String } } }` |
| 创建媒体房间 | `POST /api/v1/rooms` | `{ "roomId": String }` | HTTP 200 / 201 |
| 拉取参与者 | `GET /api/v1/commands/rooms/{roomId}/participants` | 无 | `{ "data": [{ "identity": String, "name": String, "muted": Bool? }] }` |
| 静音参与者 | `POST /api/v1/commands/rooms/{roomId}/participants/{identity}/mute` | `{ "muted": Bool }` | HTTP 200 / 201 |
| 踢出参与者 | `POST /api/v1/commands/rooms/{roomId}/participants/{identity}/kick` | `{}` | HTTP 200 / 201 |
| 设置参与者角色 | `POST /api/v1/commands/rooms/{roomId}/participants/{identity}/setRole` | `{ "role": RoomRole }` | HTTP 200 / 201 |

所有 Gateway 请求使用：

```text
Authorization: Bearer <accessToken>
Content-Type: application/json
```

## SDK 接口总览

| 接口 | 作用 |
|------|------|
| `EndpointUrl.parse(...)` | 校验并标准化 URL 字符串。 |
| `RtcConfig(...)` | 配置可选媒体服务地址覆盖值，通常直接使用默认值。 |
| `RtcClient.create(...)` | 创建 SDK 客户端。 |
| `client.connect(..., credentials:)` | 使用宿主已获取的媒体凭证连接房间。 |
| `client.connect(..., credentialsProvider:)` | 通过宿主 Provider 获取媒体凭证后连接房间。 |
| `client.disconnect()` | 断开当前媒体房间并清理本地状态。 |
| `client.close()` | 释放客户端资源，关闭回调并断开连接。 |
| `client.setMicrophoneMuted(...)` | 设置本地麦克风静音状态。 |
| `client.state` | 当前房间状态快照。 |
| `client.participants` | 当前参与者快照。 |
| `client.onStateChanged` | 订阅房间状态变化。 |
| `client.onParticipantsChanged` | 订阅参与者列表变化。 |
| `client.onEvent` | 订阅一次性事件。 |

## 数据模型说明

### `ConnectParams`

| 字段 | 类型 | 含义 |
|------|------|------|
| `roomId` | `String` | 业务侧房间 ID。 |
| `displayName` | `String?` | 参与者显示名。 |
| `role` | `RoomRole?` | 入房角色：`.host`、`.speaker`、`.listener`。 |

### `MediaCredentials`

| 字段 | 类型 | 含义 |
|------|------|------|
| `url` | `String` | LiveKit 媒体服务器连接地址。 |
| `token` | `String` | LiveKit 房间连接 token。 |

### `RtcParticipant`

| 字段 | 类型 | 含义 |
|------|------|------|
| `identity` | `String` | 参与者唯一标识，主持端命令使用该字段定位目标。 |
| `name` | `String` | 参与者显示名。 |
| `isLocal` | `Bool` | 是否为本地参与者。 |
| `isMicrophoneMuted` | `Bool` | 麦克风是否静音。 |

## Demo 使用说明

1. 填写 Gateway 地址，例如 `http://192.168.3.140:3003`。
2. 填写房间 ID、展示名、WebRTC 访问令牌。
3. 选择入房角色后点击“连接房间”。
4. Demo 会在 `AnyMediaCredentialsProvider` 中自行调用 join 接口，并把 `MediaCredentials` 交给 SDK。
5. “刷新参与者”“静音目标”“踢出目标”“设置角色”均由 Demo 调用 Gateway 命令接口完成。

## 常见问题

### Gateway 连接失败

检查：

1. Gateway 地址是否正确，例如 `http://192.168.3.140:3003`。
2. 真机和 Gateway 机器是否在同一局域网。
3. Gateway 是否监听 `0.0.0.0`，而不是只监听 `localhost`。
4. iOS 是否允许 HTTP 明文请求。
5. WebRTC access token 是否有效，是否需要 `Bearer` 前缀。

### Join 返回 404

Demo 会自动调用创建房间接口并重试一次加入。如果仍失败，检查：

1. Gateway 是否支持 `POST /api/v1/rooms` 创建房间。
2. access token 是否有创建房间权限。
3. 房间策略是否允许当前角色加入。

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
3. 当前是否已连接房间并持有 access token。
4. Gateway 命令接口路径是否与 `/api/v1` 匹配。
5. 错误是否包含 HTTP 状态码和响应正文。

## 版本信息

- SDK 包名：`partnersdk_ios`
- Demo 接入方式：本地 `xcframework` + CocoaPods 二进制 Pod
- Pod 包装版本：`PartnerSDKBinary 1.0.0`
