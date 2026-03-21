import SwiftUI

struct SettingsView: View {
    @ObservedObject var engine: SpankEngine
    @StateObject private var updater = UpdateChecker()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                    .onTapGesture {
                        engine.handleIconTap()
                    }
                Text("SmackMyMacUp")
                    .font(.title2.bold())
                Spacer()
                StatusBadge(status: engine.status)
            }
            .padding()

            if !engine.adultTapMessage.isEmpty {
                Text(engine.adultTapMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .transition(.opacity)
                    .animation(.easeInOut, value: engine.adultTapMessage)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Pause toggle
                    Toggle(isOn: $engine.isPaused) {
                        Label("Pause", systemImage: "pause.circle")
                            .font(.headline)
                    }
                    .toggleStyle(.switch)
                    .onChange(of: engine.isPaused) { _ in
                        engine.sendPauseState()
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
                            ForEach(engine.visibleModes) { mode in
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

                    // Sensitivity (slider is inverted: low value = less sensitive, high value = more sensitive)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Sensitivity", systemImage: "waveform.path")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.2f", engine.sensitivity))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: Binding(
                            get: { 0.55 - engine.sensitivity },
                            set: { engine.sensitivity = 0.55 - $0 }
                        ), in: 0.05...0.50, step: 0.01)
                            .onChange(of: engine.sensitivity) { _ in
                                engine.sendLiveSettings()
                            }
                        HStack {
                            Text("Less sensitive")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("More sensitive")
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
                        Text("Minimum time between slap sounds")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    // Toggles
                    Toggle(isOn: $engine.volumeScaling) {
                        Label("Volume Scaling", systemImage: "speaker.wave.3")
                    }
                    .toggleStyle(.switch)
                    .onChange(of: engine.volumeScaling) { _ in
                        engine.toggleVolumeScaling()
                    }
                    Text("Harder slaps play louder sounds")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

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
                .tint(.blue)
            }

            Divider()

            // Update status
            Group {
                switch updater.state {
                case .checking:
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for updates…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                case .upToDate:
                    Text("You're on the latest version (v\(updater.currentVersion))")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal)
                        .padding(.top, 6)
                case .available(let version, let url):
                    HStack {
                        Text("v\(version) available!")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Download") {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.plain)
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.top, 6)
                case .error(let msg):
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .padding(.top, 6)
                case .idle:
                    EmptyView()
                }
            }

            // Footer
            HStack {
                Text("Slaps: \(engine.slapCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check for Updates") {
                    updater.check()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .padding(.horizontal)
            .padding(.top, 4)

            HStack {
                Spacer()
                Button("Quit SmackMyMacUp") {
                    engine.quit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.caption.bold())
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .frame(width: 320, height: 580)
    }

    private var modeDescription: String {
        switch engine.mode {
        case .pain: return "Says \"ow!\" when slapped"
        case .sexy: return "Escalating female responses based on slap frequency"
        case .sexyMale: return "Escalating male responses based on slap frequency"
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
