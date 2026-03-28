import Foundation
import OSLog
import SwiftUI
import UserNotifications

private let log = Logger(subsystem: "com.alex.nixbar", category: "NixManager")

private func debugLog(_ message: String) {
    let line = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
    let path = "/tmp/nixbar-debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: line.data(using: .utf8))
    }
}

struct TaskLog: Identifiable {
    let id = UUID()
    let task: String
    let output: String
    let success: Bool
    let duration: TimeInterval
    let date: Date
}

struct FlakeInput: Identifiable {
    let id = UUID()
    let name: String
    let lastModified: Date
    let age: String
}

enum SystemStatus {
    case idle
    case running
    case success
    case failure
}

@MainActor
final class NixManager: ObservableObject {
    @Published var isRunning = false
    @Published var currentTask = ""
    @Published var currentPhase = ""
    @Published var liveOutput = ""
    @Published var logs: [TaskLog] = []
    @Published var generation = ""
    @Published var generationNumber = ""
    @Published var storeSize = ""
    @Published var lastRebuild: Date?
    @Published var packageCount = ""
    @Published var pendingChanges: [String] = []
    @Published var flakeInputs: [FlakeInput] = []
    @Published var status: SystemStatus = .idle
    @Published var elapsedTime: TimeInterval = 0

    private let configPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".nixpkgs").path
    private var runningProcess: Process?
    private var timer: Timer?
    private var taskStartTime: Date?
    private var refreshTimer: Timer?

    init() {
        Task {
            await refreshInfo()
            await checkPendingChanges()
            await loadFlakeInputs()
        }
        requestNotificationPermission()
        startPeriodicRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Periodic refresh

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard !self.isRunning else { return }
                await self.refreshInfo()
                await self.checkPendingChanges()
            }
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, success: Bool, duration: TimeInterval) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = success ? "\(title) Completed" : "\(title) Failed"
        content.body = success
            ? "Finished in \(formatDuration(duration))"
            : "Task failed after \(formatDuration(duration)). Click to view details."
        content.sound = success ? .default : UNNotificationSound.defaultCritical

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        if d < 60 { return String(format: "%.0fs", d) }
        let m = Int(d) / 60
        let s = Int(d) % 60
        return s > 0 ? "\(m)m \(s)s" : "\(m)m"
    }

    // MARK: - Actions

    func rebuild() async {
        // Step 1: Build as user (needs git access to the flake)
        await run(
            "Rebuild (build)",
            command: """
                nix --extra-experimental-features 'nix-command flakes' build --json --no-link \
                -- \(configPath)#darwinConfigurations.alex.system 2>&1
                """
        )
        guard let lastLog = logs.first, lastLog.success else { return }

        // Extract the store path from nix build JSON output
        let output = lastLog.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonStart = output.lastIndex(of: "["),
              let data = String(output[jsonStart...]).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first,
              let outputs = first["outputs"] as? [String: String],
              let storePath = outputs["out"]
        else {
            debugLog("rebuild: failed to parse nix build output")
            let log = TaskLog(task: "Rebuild", output: "Failed to parse build output:\n\(output)", success: false, duration: 0, date: Date())
            logs.insert(log, at: 0)
            status = .failure
            return
        }

        log.info("rebuild: built \(storePath)")

        // Step 2: Activate as root (profile switch + activation)
        let activateCmd = "nix-env -p /nix/var/nix/profiles/system --set \(storePath) && \(storePath)/activate"
        await runPrivileged("Rebuild (activate)", command: activateCmd)

        await refreshInfo()
        await checkPendingChanges()
    }

    func updateFlake() async {
        await run(
            "Flake Update",
            command: "nix flake update --flake \(configPath) 2>&1"
        )
        await loadFlakeInputs()
    }

    func brewUpdate() async {
        await run(
            "Brew Update",
            command: "/opt/homebrew/bin/brew update && /opt/homebrew/bin/brew upgrade 2>&1"
        )
    }

    func updateAll() async {
        await updateFlake()
        guard logs.first?.success == true else { return }
        await brewUpdate()
        guard logs.first?.success == true else { return }
        await rebuild()
    }

    func garbageCollect() async {
        await runPrivileged(
            "Garbage Collect",
            command: "nix-collect-garbage -d"
        )
        await refreshInfo()
    }

    func editConfig() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [configPath]
        try? process.run()
    }

    func cancelTask() {
        runningProcess?.terminate()
        runningProcess = nil
    }

    func refreshInfo() async {
        // Read generation info from profile symlinks (no root needed)
        let genInfo = await shellOutput(
            "readlink /nix/var/nix/profiles/system 2>/dev/null"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if !genInfo.isEmpty {
            // Extract generation number from "system-173-link"
            if let match = genInfo.range(of: #"\d+"#, options: .regularExpression) {
                generationNumber = String(genInfo[match])
            }
            // Get modification time of the symlink as last rebuild date
            let dateStr = await shellOutput(
                "stat -f '%m' /nix/var/nix/profiles/system 2>/dev/null"
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if let timestamp = Double(dateStr) {
                lastRebuild = Date(timeIntervalSince1970: timestamp)
            }
        }

        storeSize = await shellOutput(
            "du -sh /nix/store 2>/dev/null | cut -f1"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        packageCount = await shellOutput(
            "ls /run/current-system/sw/bin 2>/dev/null | wc -l | tr -d ' '"
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func checkPendingChanges() async {
        let changes = await shellOutput(
            "cd \(configPath) && git diff --name-only 2>/dev/null && git diff --cached --name-only 2>/dev/null"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if changes.isEmpty {
            pendingChanges = []
        } else {
            pendingChanges = Array(Set(changes.components(separatedBy: "\n").filter { !$0.isEmpty }))
        }
    }

    func loadFlakeInputs() async {
        let lockContent = await shellOutput(
            "cat \(configPath)/flake.lock 2>/dev/null"
        )
        guard !lockContent.isEmpty,
              let data = lockContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nodes = json["nodes"] as? [String: Any]
        else { return }

        var inputs: [FlakeInput] = []
        let now = Date()

        for (name, nodeValue) in nodes {
            guard name != "root",
                  let node = nodeValue as? [String: Any],
                  let locked = node["locked"] as? [String: Any],
                  let lastMod = locked["lastModified"] as? Int
            else { continue }

            let date = Date(timeIntervalSince1970: Double(lastMod))
            let interval = now.timeIntervalSince(date)
            let days = Int(interval / 86400)
            let age: String
            if days == 0 { age = "today" }
            else if days == 1 { age = "1 day ago" }
            else if days < 30 { age = "\(days) days ago" }
            else if days < 365 { age = "\(days / 30) months ago" }
            else { age = "\(days / 365)y \((days % 365) / 30)m ago" }

            inputs.append(FlakeInput(name: name, lastModified: date, age: age))
        }

        flakeInputs = inputs.sorted { $0.name < $1.name }
    }

    // MARK: - Phase detection

    private func detectPhase(from output: String) -> String {
        let lines = output.suffix(2000)
        if lines.contains("evaluating") || lines.contains("evaluation") { return "Evaluating..." }
        if lines.contains("building") || lines.contains("Building") { return "Building..." }
        if lines.contains("copying") || lines.contains("Copying") { return "Copying..." }
        if lines.contains("activating") || lines.contains("Activating") { return "Activating..." }
        if lines.contains("fetching") || lines.contains("Fetching") { return "Fetching..." }
        if lines.contains("downloading") || lines.contains("Downloading") { return "Downloading..." }
        if lines.contains("unpacking") { return "Unpacking..." }
        if lines.contains("Updated") && lines.contains("Outdated") { return "Checking..." }
        if lines.contains("Upgrading") { return "Upgrading..." }
        if lines.contains("removing") || lines.contains("deleting") { return "Cleaning..." }
        return ""
    }

    // MARK: - Shell execution

    private func run(_ task: String, command: String) async {
        isRunning = true
        currentTask = task
        currentPhase = ""
        liveOutput = ""
        elapsedTime = 0
        status = .running
        let start = Date()
        taskStartTime = start

        // Start elapsed timer
        let taskStart = start
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedTime = Date().timeIntervalSince(taskStart)
            }
        }

        let (output, success) = await execute(command)

        timer?.invalidate()
        timer = nil
        taskStartTime = nil

        let duration = Date().timeIntervalSince(start)
        let log = TaskLog(
            task: task,
            output: output,
            success: success,
            duration: duration,
            date: Date()
        )
        logs.insert(log, at: 0)
        if logs.count > 50 { logs = Array(logs.prefix(50)) }

        status = success ? .success : .failure
        currentTask = ""
        currentPhase = ""
        isRunning = false
        runningProcess = nil

        sendNotification(title: task, success: success, duration: duration)

        // Reset status indicator after 30s
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !self.isRunning {
                self.status = .idle
            }
        }
    }

    /// Run a command that requires root privileges via macOS authorization dialog.
    /// Streams output through a temp file so we get live updates.
    private func runPrivileged(_ task: String, command: String) async {
        isRunning = true
        currentTask = task
        currentPhase = "Waiting for authorization..."
        liveOutput = ""
        elapsedTime = 0
        status = .running
        let start = Date()
        taskStartTime = start

        let taskStart = start
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedTime = Date().timeIntervalSince(taskStart)
            }
        }

        let (output, success) = await executePrivileged(command)

        timer?.invalidate()
        timer = nil
        taskStartTime = nil

        let duration = Date().timeIntervalSince(start)
        let log = TaskLog(
            task: task,
            output: output,
            success: success,
            duration: duration,
            date: Date()
        )
        logs.insert(log, at: 0)
        if logs.count > 50 { logs = Array(logs.prefix(50)) }

        status = success ? .success : .failure
        currentTask = ""
        currentPhase = ""
        isRunning = false
        runningProcess = nil

        sendNotification(title: task, success: success, duration: duration)

        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if !self.isRunning {
                self.status = .idle
            }
        }
    }

    private func executePrivileged(_ command: String) async -> (String, Bool) {
        let manager = self
        let outputFile = "/tmp/nixbar-\(UUID().uuidString).log"

        log.info("executePrivileged: \(command)")

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Create the output file
                FileManager.default.createFile(atPath: outputFile, contents: nil)

                // Start tailing the output file for live updates
                let tailProcess = Process()
                let tailPipe = Pipe()
                tailProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
                tailProcess.arguments = ["-f", outputFile]
                tailProcess.standardOutput = tailPipe
                tailProcess.standardError = FileHandle.nullDevice

                nonisolated(unsafe) var collectedOutput = ""

                tailPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                    collectedOutput += chunk
                    let lines = String(collectedOutput.suffix(2000))
                    Task { @MainActor in
                        manager.liveOutput = lines
                        manager.currentPhase = manager.detectPhase(from: lines)
                    }
                }

                try? tailProcess.run()

                // Run the privileged command via osascript with admin privileges.
                // do shell script runs via /bin/sh as root. We need /bin/zsh -l
                // for nix commands to be on PATH.
                let escapedCommand = command
                    .replacingOccurrences(of: "\\", with: "\\\\\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\\\\\"")

                let shellCmd = "/bin/zsh -l -c \\\"\(escapedCommand)\\\" > \(outputFile) 2>&1"
                let script = "do shell script \"\(shellCmd)\" with administrator privileges"

                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", script]
                process.standardOutput = pipe
                process.standardError = pipe

                Task { @MainActor in
                    manager.runningProcess = process
                }

                var success = false
                do {
                    try process.run()

                    Task { @MainActor in
                        manager.currentPhase = ""
                    }

                    process.waitUntilExit()
                    success = process.terminationStatus == 0

                    log.info("executePrivileged: exit=\(process.terminationStatus)")
                } catch {
                    log.error("executePrivileged: process launch error: \(error.localizedDescription)")
                    collectedOutput += "\n" + error.localizedDescription
                }

                // Stop tailing
                tailProcess.terminate()
                tailPipe.fileHandleForReading.readabilityHandler = nil

                // Read final output from file
                if let fileData = FileManager.default.contents(atPath: outputFile),
                   let fileOutput = String(data: fileData, encoding: .utf8),
                   !fileOutput.isEmpty
                {
                    collectedOutput = fileOutput
                }

                // Clean up temp file
                try? FileManager.default.removeItem(atPath: outputFile)

                continuation.resume(returning: (collectedOutput, success))
            }
        }
    }

    private func execute(_ command: String) async -> (String, Bool) {
        let manager = self
        log.info("execute: \(command)")
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                process.standardOutput = pipe
                process.standardError = pipe

                nonisolated(unsafe) var output = ""

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                        return
                    }
                    output += chunk
                    let lines = String(output.suffix(2000))
                    Task { @MainActor in
                        manager.liveOutput = lines
                        manager.currentPhase = manager.detectPhase(from: lines)
                    }
                }

                Task { @MainActor in
                    manager.runningProcess = process
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil
                    log.info("execute: exit=\(process.terminationStatus)")
                    continuation.resume(returning: (output, process.terminationStatus == 0))
                } catch {
                    log.error("execute: launch error: \(error.localizedDescription)")
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: (error.localizedDescription, false))
                }
            }
        }
    }

    private func shellOutput(_ command: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                let pipe = Pipe()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", command]
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
