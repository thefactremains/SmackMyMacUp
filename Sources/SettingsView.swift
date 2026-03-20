import SwiftUI

struct SettingsView: View {
    @ObservedObject var engine: SpankEngine

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                Text("SmackMyMacUp")
                    .font(.title2.bold())
                Spacer()
                StatusBadge(status: engine.status)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Power toggle
                    Toggle(isOn: $engine.isEnabled) {
                        Label("Enabled", systemImage: "power")
                            .font(.headline)
                    }
                    .toggleStyle(.switch)
                    .onChange(of: engine.isEnabled) { newValue in
                        if newValue {
                            engine.start()
                        } else {
                            engine.stop()
                        }
                    }

                    if engine.status == .running {
                        Toggle(isOn: $engine.isPaused) {
                            Label("Paused", systemImage: "pause.circle")
                        }
                        .toggleStyle(.switch)
                        .onChange(of: engine.isPaused) { _ in
                            engine.sendPauseState()
                        }
                    }

                    if engine.status == .error, !engine.lastSlap.isEmpty {
                        Text(engine.lastSlap)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Divider()

                    // Mode picker
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Mode", systemImage: "music.note.list")
                            .font(.headline)
                        Picker("Mode", selection: $engine.mode) {
                            ForEach(SpankEngine.Mode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: engine.mode) { _ in
                            if engine.status == .running {
                                engine.restart()
                            }
                        }

                        Text(modeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Sensitivity
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Sensitivity", systemImage: "waveform.path")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.2f", engine.sensitivity))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $engine.sensitivity, in: 0.05...0.50, step: 0.01)
                            .onChange(of: engine.sensitivity) { _ in
                                engine.sendLiveSettings()
                            }
                        HStack {
                            Text("More sensitive")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Less sensitive")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Volume
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Volume", systemImage: "speaker.wave.2")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(engine.volume * 100))%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Slider(value: $engine.volume, in: 0...1, step: 0.01)
                                .onChange(of: engine.volume) { _ in
                                    engine.setSystemVolume()
                                }
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Cooldown
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Cooldown", systemImage: "timer")
                                .font(.headline)
                            Spacer()
                            Text("\(engine.cooldown)ms")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { Double(engine.cooldown) },
                            set: { engine.cooldown = Int($0) }
                        ), in: 100...2000, step: 50)
                            .onChange(of: engine.cooldown) { _ in
                                engine.sendLiveSettings()
                            }
                    }

                    // Speed
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Speed", systemImage: "gauge.with.needle")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.1fx", engine.speed))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $engine.speed, in: 0.3...2.0, step: 0.1)
                            .onChange(of: engine.speed) { _ in
                                engine.sendLiveSettings()
                            }
                    }

                    // Toggles
                    Toggle(isOn: $engine.volumeScaling) {
                        Label("Volume Scaling", systemImage: "speaker.wave.3")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: engine.volumeScaling) { _ in
                        engine.toggleVolumeScaling()
                    }

                    Toggle(isOn: $engine.fastMode) {
                        Label("Fast Mode", systemImage: "hare")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: engine.fastMode) { _ in
                        if engine.status == .running {
                            engine.restart()
                        }
                    }

                    Divider()

                    Toggle(isOn: $engine.launchAtLogin) {
                        Label("Launch at Login", systemImage: "arrow.right.circle")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: engine.launchAtLogin) { _ in
                        engine.updateLaunchAtLogin()
                    }

                    // Last slap info
                    if engine.status == .running, !engine.lastSlap.isEmpty {
                        HStack {
                            Image(systemName: "hand.point.up.left.fill")
                                .foregroundStyle(.orange)
                            Text(engine.lastSlap)
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Text("Slaps: \(engine.slapCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit SmackMyMacUp") {
                    engine.quit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.caption.bold())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 580)
    }

    private var modeDescription: String {
        switch engine.mode {
        case .pain: return "Says \"ow!\" when slapped"
        case .sexy: return "Escalating responses based on slap frequency"
        case .halo: return "Halo death sounds when slapped"
        }
    }
}

struct StatusBadge: View {
    let status: SpankEngine.Status

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(status.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch status {
        case .running: return .green
        case .starting: return .orange
        case .stopped: return .gray
        case .error: return .red
        }
    }
}
