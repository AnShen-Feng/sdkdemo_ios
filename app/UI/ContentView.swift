// Relative path: partnersdk_demo_ios/app/UI/ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DemoViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("WebRTC SDK Demo")
                        .font(.title2.weight(.bold))
                    Text(vm.stateText)
                        .font(.subheadline)
                        .foregroundColor(vm.isConnected ? .green : .secondary)
                }

                Section("连接配置") {
                    TextField("请输入 BE 地址", text: $vm.backendBaseUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    TextField("例如：demo-room", text: $vm.roomId)
                        .textInputAutocapitalization(.never)
                    TextField("例如：Alice", text: $vm.displayName)
                        .textInputAutocapitalization(.never)
                    TextField("粘贴用户 JWT（可带或不带 Bearer 前缀）", text: $vm.businessToken)
                        .textInputAutocapitalization(.never)
                    Picker("入房角色", selection: $vm.selectedRole) {
                        ForEach(DemoViewModel.DemoRole.allCases) { role in
                            Text(role.title).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("房间控制") {
                    HStack {
                        Button(vm.connectButtonTitle) { vm.connectButtonTapped() }
                            .disabled(vm.isConnecting)
                        Spacer()
                        Button(vm.micButtonTitle) { vm.toggleMicTapped() }
                            .disabled(!vm.isConnected)
                    }
                }

                Section("目标控制") {
                    TextField("输入目标 identity", text: $vm.targetIdentity)
                        .textInputAutocapitalization(.never)
                    HStack {
                        Button("刷新参与者") { vm.refreshParticipantsTapped() }
                        Spacer()
                        Button("踢出目标", role: .destructive) { vm.kickTargetTapped() }
                    }
                    HStack {
                        Button("静音目标") { vm.muteTargetTapped() }
                        Spacer()
                        Button("取消静音目标") { vm.unmuteTargetTapped() }
                    }
                    HStack {
                        Button("设为主持人") { vm.setTargetHostTapped() }
                        Spacer()
                        Button("设为发言成员") { vm.setTargetSpeakerTapped() }
                    }
                    Button("设为听众成员") { vm.setTargetListenerTapped() }
                }

                Section("参与者列表（可区分主持人与成员）") {
                    if vm.participants.isEmpty {
                        Text("暂无参与者")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(vm.participants, id: \.self) { participant in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(vm.displayName(for: participant)) [\(vm.roleTag(for: participant))]")
                                    .font(.body.weight(.medium))
                                Text("\(participant.identity)\(participant.isLocal ? " (我)" : "")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !vm.lastMessage.isEmpty {
                    Section("日志") {
                        Text(vm.lastMessage)
                            .font(.footnote)
                    }
                }

                if !vm.lastError.isEmpty {
                    Section("错误") {
                        Text(vm.lastError)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Partner SDK Demo")
        }
    }
}
