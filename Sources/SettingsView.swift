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
                Text("WhacMyMac")
                    .font(.title2.bold())
                Spacer()
                StatusBadge(status: engine.status)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Power toggle
                    HStack {
                        Toggle(isOn: Binding(
                            get: { engine.status == .running || engine.status == .starting },
                            set: { $0 ? engine.start() : engine.stop() }
                        )) {
                            Label("Enabled", systemImage: "power")
                                .font(.headline)
                        }
                        .toggleStyle(.switch)
                    }

                    if engine.status == .running {
                        // Pause toggle
                        Toggle(isOn: $engine.isPaused) {
                            Label("Paused", systemImage: "pause.circle")
                        }
                        .toggleStyle(.switch)
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

                        Text(modeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Sensitivity slider
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Sensitivity", systemImage: "waveform.path")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.2f", engine.sensitivity))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $engine.sensitivity, in: 0.01...0.5, step: 0.01)
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

                    // Cooldown slider
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
                    }

                    // Speed slider
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
                    }

                    // Toggles
                    Toggle(isOn: $engine.volumeScaling) {
                        Label("Volume Scaling", systemImage: "speaker.wave.3")
                    }
                    .toggleStyle(.switch)

                    Toggle(isOn: $engine.fastMode) {
                        Label("Fast Mode", systemImage: "hare")
                    }
                    .toggleStyle(.switch)

                    Divider()

                    // Last slap info
                    if !engine.lastSlap.isEmpty {
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
                Button("Quit") {
                    engine.stop()
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 420)
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
