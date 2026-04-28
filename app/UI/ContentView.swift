// Relative path: partnersdk_ios/app/UI/ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var vm = DemoViewModel()

    var body: some View {
        NavigationView {
            Form {
                Section("Config") {
                    TextField("Backend Base URL", text: $vm.backendBaseUrl)
                    TextField("Room ID", text: $vm.roomId)
                    TextField("Display Name", text: $vm.displayName)
                    TextField("Business JWT", text: $vm.businessToken)
                }

                Section("Connection") {
                    Text("State: \(vm.stateText)")
                    Button("Connect") { vm.connectTapped() }
                    Button("Disconnect") { vm.disconnectTapped() }
                    Button(vm.muted ? "Unmute Mic" : "Mute Mic") { vm.toggleMicTapped() }
                }

                Section("Moderation") {
                    TextField("Target Identity", text: $vm.targetIdentity)
                    Button("Mute Target") { vm.muteTargetTapped() }
                    Button("Kick Target") { vm.kickTargetTapped() }
                }

                Section("Participants") {
                    ForEach(vm.participants, id: \.self) { p in
                        Text("\(p.name) (\(p.identity)) \(p.isLocal ? "[local]" : "")")
                    }
                }

                if !vm.lastError.isEmpty {
                    Section("Error") {
                        Text(vm.lastError).foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Partner SDK Demo")
        }
    }
}
