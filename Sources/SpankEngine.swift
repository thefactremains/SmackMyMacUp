import Foundation
import AppKit
import Combine
import ServiceManagement

@MainActor
final class SpankEngine: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case pain = "Pain"
        case sexy = "Sexy (F)"
        case sexyMale = "Sexy (M)"
        case halo = "Halo"
        var id: String { rawValue }

        var isAdult: Bool {
            self == .sexy || self == .sexyMale
        }

        var flags: [String] {
            switch self {
            case .pain: return []
            case .sexy: return ["--sexy"]
            case .sexyMale: return ["--sexy-male"]
            case .halo: return ["--halo"]
            }
        }
    }

    static let adultUnlockThreshold = 3
    @Published var adultModeUnlocked: Bool = UserDefaults.standard.bool(forKey: "adultModeUnlocked")
    @Published var adultTapCount: Int = 0
    @Published var adultTapMessage: String = ""

    var visibleModes: [Mode] {
        Mode.allCases.filter { adultModeUnlocked || !$0.isAdult }
    }

    func handleIconTap() {
        adultTapCount += 1
        let remaining = Self.adultUnlockThreshold - adultTapCount
        if remaining <= 0 {
            adultTapCount = 0
            adultModeUnlocked.toggle()
            UserDefaults.standard.set(adultModeUnlocked, forKey: "adultModeUnlocked")
            if adultModeUnlocked {
                adultTapMessage = "Adult modes unlocked 🔓"
            } else {
                // Reset to safe mode if currently on an adult mode
                if mode.isAdult {
                    mode = .pain
                    if status == .running { restart() }
                }
                adultTapMessage = "Adult modes hidden 🔒"
            }
        } else {
            adultTapMessage = "\(remaining) tap\(remaining == 1 ? "" : "s") to \(adultModeUnlocked ? "hide" : "unlock") adult modes"
        }

        // Clear message after 2 seconds
        if !adultTapMessage.isEmpty {
            let msg = adultTapMessage
            Task {
                try? await Task.sleep(for: .seconds(2))
                if self.adultTapMessage == msg {
                    self.adultTapMessage = ""
                }
            }
        }
    }

    enum Status: String {
        case stopped = "Stopped"
        case starting = "Starting…"
        case running = "Running"
        case error = "Error"
    }

    @Published var isEnabled: Bool = false
    @Published var mode: Mode = .pain
    @Published var sensitivity: Double = 0.25
    @Published var cooldown: Int = 750
    @Published var speed: Double = 1.0
    @Published var volumeScaling: Bool = false
    @Published var fastMode: Bool = true
    @Published var isPaused: Bool = false
    @Published var isRestarting: Bool = false
    @Published var volume: Double = 0.6 {
        didSet { UserDefaults.standard.set(volume, forKey: "volume") }
    }
    @Published var launchAtLogin: Bool = false
    @Published var status: Status = .stopped
    @Published var lastSlap: String = ""
    @Published var slapCount: Int = 0

    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var readTask: Task<Void, Never>?

    init() {
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }

        // Always start when the app launches
        isEnabled = true
        start()
    }

    // MARK: - Sudoers setup (one-time)

    private var sudoersPath: String { "/etc/sudoers.d/smackmymacup" }

    private var isSudoConfigured: Bool {
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    /// Creates a sudoers entry so the spank binary and pkill can run as root without a password.
    /// Only needs to happen once — uses AppleScript for the admin auth dialog.
    private func ensureSudoAccess() -> Bool {
        if isSudoConfigured { return true }

        let binaryPath = Self.binaryPath()
        // sudoers entries: allow running spank and pkill (for cleanup) as root, no password
        let lines = [
            "ALL ALL=(root) NOPASSWD: \(binaryPath)",
            "ALL ALL=(root) NOPASSWD: /usr/bin/pkill"
        ]
        let entry = lines.joined(separator: "\\n")
        let cmd = "printf '\(entry)\\n' > \(sudoersPath) && chmod 0440 \(sudoersPath)"
        let script = "do shell script \"\(cmd)\" with administrator privileges"

        NSLog("SmackMyMacUp: setting up sudoers (one-time)")
        let appleScript = NSAppleScript(source: script)
        var errorInfo: NSDictionary?
        appleScript?.executeAndReturnError(&errorInfo)

        if errorInfo != nil {
            NSLog("SmackMyMacUp: sudoers setup failed: \(errorInfo!)")
            return false
        }

        NSLog("SmackMyMacUp: sudoers configured")
        return true
    }

    // MARK: - Start / Stop

    /// Kill any orphaned spank processes left over from a previous app instance.
    private func killStaleProcesses() {
        let killProc = Process()
        killProc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        killProc.arguments = ["pkill", "-9", "-f", "spank --stdio"]
        killProc.standardOutput = FileHandle.nullDevice
        killProc.standardError = FileHandle.nullDevice
        try? killProc.run()
        killProc.waitUntilExit()
    }

    func start() {
        guard status == .stopped || status == .error else { return }
        status = .starting

        killStaleProcesses()

        let binaryPath = Self.binaryPath()
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            status = .error
            isEnabled = false
            lastSlap = "Binary not found"
            return
        }

        // One-time: set up passwordless sudo
        if !ensureSudoAccess() {
            status = .stopped
            isEnabled = false
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

        proc.terminationHandler = { [weak self] terminatedProc in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Ignore if a newer process has already replaced this one
                guard self.process === terminatedProc else { return }
                self.status = .stopped
                // Auto-restart if the process died unexpectedly (not a user-initiated stop)
                if self.isEnabled {
                    NSLog("SmackMyMacUp: process terminated unexpectedly, restarting…")
                    try? await Task.sleep(for: .milliseconds(500))
                    self.start()
                }
            }
        }

        do {
            try proc.run()
        } catch {
            status = .error
            isEnabled = false
            lastSlap = "Failed to start: \(error.localizedDescription)"
            return
        }

        process = proc
        stdinPipe = stdin
        stdoutPipe = stdout
        status = .running

        NSLog("SmackMyMacUp: spank started (PID \(proc.processIdentifier))")

        // Read stdout for slap events — must be detached to avoid blocking MainActor
        readTask = Task.detached { [weak self] in
            let handle = stdout.fileHandleForReading
            while !Task.isCancelled {
                let data = handle.availableData
                if data.isEmpty { break }
                if let text = String(data: data, encoding: .utf8) {
                    for line in text.components(separatedBy: "\n") where !line.isEmpty {
                        await self?.handleOutput(line)
                    }
                }
            }
        }
    }

    func stop() {
        NSLog("SmackMyMacUp: stopping")
        isEnabled = false
        readTask?.cancel()
        readTask = nil

        // Close stdin pipe first — this causes spank to exit cleanly
        if let pipe = stdinPipe {
            pipe.fileHandleForWriting.closeFile()
        }
        stdinPipe = nil

        // Kill any remaining spank processes via sudo pkill
        let killProc = Process()
        killProc.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        killProc.arguments = ["pkill", "-9", "-f", "spank --stdio"]
        killProc.standardOutput = FileHandle.nullDevice
        killProc.standardError = FileHandle.nullDevice
        try? killProc.run()

        // Also terminate the sudo wrapper
        if let proc = process, proc.isRunning {
            proc.terminate()
        }

        process = nil
        stdoutPipe = nil
        status = .stopped
        slapCount = 0
    }

    func restart() {
        let wasRunning = status == .running
        isRestarting = wasRunning
        stop()
        if wasRunning {
            isEnabled = true  // re-enable so start() works
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                start()
                isRestarting = false
            }
        }
    }

    func quit() {
        stop()
        NSApp.terminate(nil)
    }

    // MARK: - Live settings via stdin JSON

    func sendLiveSettings() {
        var cmd: [String: Any] = ["cmd": "set"]
        cmd["amplitude"] = sensitivity
        cmd["cooldown"] = cooldown
        cmd["speed"] = speed
        sendCommand(cmd)
    }

    func sendPauseState() {
        sendCommand(["cmd": isPaused ? "pause" : "resume"])
    }

    func toggleVolumeScaling() {
        sendCommand(["cmd": "volume-scaling"])
    }

    private func sendCommand(_ dict: [String: Any]) {
        guard let pipe = stdinPipe, process?.isRunning == true else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        var payload = data
        payload.append(contentsOf: [UInt8(ascii: "\n")])
        pipe.fileHandleForWriting.write(payload)
        NSLog("SmackMyMacUp: sent command \(String(data: data, encoding: .utf8) ?? "?")")
    }

    // MARK: - Output handling

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

    // MARK: - Volume

    func setSystemVolume() {
        let vol = Int(volume * 100)
        let script = NSAppleScript(source: "set volume output volume \(vol)")
        var err: NSDictionary?
        script?.executeAndReturnError(&err)
    }

    // MARK: - Launch at login

    func updateLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                lastSlap = "Launch at login failed"
            }
        }
    }

    // MARK: - Binary path

    static func binaryPath() -> String {
        if let bundled = Bundle.main.path(forResource: "spank", ofType: nil) {
            return bundled
        }
        for path in ["/usr/local/bin/spank", "/opt/homebrew/bin/spank"] {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/local/bin/spank"
    }
}
