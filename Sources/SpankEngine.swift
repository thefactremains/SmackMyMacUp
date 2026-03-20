import Foundation
import Combine

/// Manages the spank binary subprocess, communicating via JSON stdio.
@MainActor
final class SpankEngine: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case pain = "Pain"
        case sexy = "Sexy"
        case halo = "Halo"
        var id: String { rawValue }

        var flags: [String] {
            switch self {
            case .pain: return []
            case .sexy: return ["--sexy"]
            case .halo: return ["--halo"]
            }
        }
    }

    enum Status: String {
        case stopped = "Stopped"
        case starting = "Starting…"
        case running = "Running"
        case error = "Error"
    }

    @Published var mode: Mode = .pain {
        didSet { if oldValue != mode { restart() } }
    }
    @Published var sensitivity: Double = 0.05 {
        didSet { sendSettings() }
    }
    @Published var cooldown: Int = 750 {
        didSet { sendSettings() }
    }
    @Published var speed: Double = 1.0 {
        didSet { sendSettings() }
    }
    @Published var volumeScaling: Bool = false {
        didSet { sendCommand(["cmd": "volume-scaling"]) }
    }
    @Published var fastMode: Bool = false {
        didSet { restart() }
    }
    @Published var isPaused: Bool = false {
        didSet { sendCommand(["cmd": isPaused ? "pause" : "resume"]) }
    }
    @Published var status: Status = .stopped
    @Published var lastSlap: String = ""
    @Published var slapCount: Int = 0

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var readTask: Task<Void, Never>?

    func start() {
        guard status == .stopped || status == .error else { return }
        status = .starting

        let binaryPath = Self.binaryPath()
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            status = .error
            lastSlap = "Binary not found at \(binaryPath)"
            return
        }

        let proc = Process()
        let stdin = Pipe()
        let stdout = Pipe()

        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        var args = [binaryPath, "--stdio"]
        args += mode.flags
        if fastMode { args.append("--fast") }
        args += ["--min-amplitude", String(format: "%.4f", sensitivity)]
        args += ["--cooldown", "\(cooldown)"]
        args += ["--speed", String(format: "%.2f", speed)]
        if volumeScaling { args.append("--volume-scaling") }
        proc.arguments = args
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = FileHandle.nullDevice

        proc.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.status = .stopped
            }
        }

        do {
            try proc.run()
        } catch {
            status = .error
            lastSlap = "Failed to start: \(error.localizedDescription)"
            return
        }

        process = proc
        stdinPipe = stdin
        stdoutPipe = stdout

        // Read stdout for events
        readTask = Task { [weak self] in
            let handle = stdout.fileHandleForReading
            while let self = self, !Task.isCancelled {
                let data = handle.availableData
                if data.isEmpty { break }
                if let line = String(data: data, encoding: .utf8) {
                    for jsonLine in line.components(separatedBy: "\n") where !jsonLine.isEmpty {
                        await self.handleOutput(jsonLine)
                    }
                }
            }
        }

        status = .running
    }

    func stop() {
        readTask?.cancel()
        readTask = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        status = .stopped
        slapCount = 0
    }

    func restart() {
        guard status == .running || status == .starting else { return }
        stop()
        // Small delay to let the process fully terminate
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            start()
        }
    }

    private func sendCommand(_ dict: [String: Any]) {
        guard let pipe = stdinPipe, process?.isRunning == true else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        var payload = data
        payload.append(contentsOf: [UInt8(ascii: "\n")])
        pipe.fileHandleForWriting.write(payload)
    }

    private func sendSettings() {
        var cmd: [String: Any] = ["cmd": "set"]
        cmd["amplitude"] = sensitivity
        cmd["cooldown"] = cooldown
        cmd["speed"] = speed
        sendCommand(cmd)
    }

    private func handleOutput(_ json: String) async {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        await MainActor.run {
            if let _ = obj["slapNumber"] as? Int {
                slapCount += 1
                let amp = obj["amplitude"] as? Double ?? 0
                let severity = obj["severity"] as? String ?? "?"
                lastSlap = String(format: "#%d %@ (%.3fg)", slapCount, severity, amp)
            }
            if let s = obj["status"] as? String, s == "ready" {
                status = .running
            }
        }
    }

    static func binaryPath() -> String {
        // Check for bundled binary in app Resources
        if let bundled = Bundle.main.path(forResource: "spank", ofType: nil) {
            return bundled
        }
        // Fallback: check common install locations
        for path in ["/usr/local/bin/spank", "/opt/homebrew/bin/spank"] {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/local/bin/spank"
    }
}
