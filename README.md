<!-- Relative path: partnersdk_demo_ios/README.md -->

# PartnerSDK iOS Demo（XCFramework 接入版）

本工程演示如何在 iOS App 中通过本地 `xcframework` 接入 `partnersdk_ios`，并通过强类型 API 完成 RTC 连接和控制。

## 目录说明

- `app/`: Demo App 代码
- `app/libs/partnersdk_ios.xcframework`: 本地二进制 SDK
- `app/libs/PartnerSDKBinary.podspec`: 二进制 Pod 包装，声明 `LiveKitClient` 依赖

## 运行步骤

1. 进入目录：

```bash
cd /Users/zero/Documents/Work/Squady/Squady/partnersdk_demo_ios
```

2. 安装依赖：

```bash
pod install
```

3. 打开工程：

```bash
open partnersdk_ios.xcworkspace
```

4. 选择 `PartnerSDKDemo` Scheme，运行到模拟器或真机。

## 类型安全说明

- Demo 全程使用 `RtcClient`、`RtcConfig`、`ConnectParams`、`RtcParticipant` 等强类型接口
- 未使用 `Any` 作为业务数据承载
