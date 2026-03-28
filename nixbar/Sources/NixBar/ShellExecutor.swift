import Foundation
import OSLog

private let log = Logger(subsystem: "com.alex.nixbar", category: "ShellExecutor")

// MARK: - Shell Executor

final class ShellExecutor {
    var onLiveOutput: ((String, String) -> Void)?

    init(onLiveOutput: ((String, String) -> Void)? = nil) {
        self.onLiveOutput = onLiveOutput
    }

    // MARK: Public API

    func run(_ command: String) async -> (output: String, success: Bool) {
        log.info("execute: \(command)")
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = pipe
        process.standardError = pipe
        return await execute(process, pipe: pipe)
    }

    func runPrivileged(_ command: String) async -> (output: String, success: Bool) {
        log.info("executePrivileged: \(command)")
        let outputFile = "/tmp/nixbar-\(UUID().uuidString).log"
        FileManager.default.createFile(atPath: outputFile, contents: nil)

        let tailProcess = Process()
        let tailPipe = Pipe()
        tailProcess.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        tailProcess.arguments = ["-f", outputFile]
        tailProcess.standardOutput = tailPipe
        tailProcess.standardError = FileHandle.nullDevice

        let tracker = OutputTracker()
        tailPipe.fileHandleForReading.readabilityHandler = { [onLiveOutput] handle in
            guard let chunk = String(data: handle.availableData, encoding: .utf8) else { return }
            tracker.append(chunk) { fullOutput in
                onLiveOutput?(String(fullOutput.suffix(2000)), detectPhase(from: fullOutput))
            }
        }
        try? tailProcess.run()

        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\\\\\")
            .replacingOccurrences(of: "\"", with: "\\\\\\\"")
        let shellCmd = "/bin/zsh -l -c \\\"\(escaped)\\\" > \(outputFile) 2>&1"
        let script = "do shell script \"\(shellCmd)\" with administrator privileges"

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = pipe

        var success = false
        do {
            try process.run()
            process.waitUntilExit()
            success = process.terminationStatus == 0
            log.info("executePrivileged: exit=\(process.terminationStatus)")
        } catch {
            log.error("executePrivileged: \(error.localizedDescription)")
        }

        tailProcess.terminate()
        tailPipe.fileHandleForReading.readabilityHandler = nil

        let output: String
        if let data = FileManager.default.contents(atPath: outputFile),
           let text = String(data: data, encoding: .utf8), !text.isEmpty {
            output = text
        } else {
            output = tracker.currentOutput
        }
        try? FileManager.default.removeItem(atPath: outputFile)
        return (output, success)
    }

    func runSimple(_ command: String) async -> String {
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
                    continuation.resume(returning: String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }

    // MARK: Private

    private func execute(_ process: Process, pipe: Pipe) async -> (String, Bool) {
        let tracker = OutputTracker()
        let handler = onLiveOutput
        pipe.fileHandleForReading.readabilityHandler = { handle in
            guard let chunk = String(data: handle.availableData, encoding: .utf8) else { return }
            tracker.append(chunk) { fullOutput in
                handler?(String(fullOutput.suffix(2000)), detectPhase(from: fullOutput))
            }
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try process.run()
                    process.waitUntilExit()
                    pipe.fileHandleForReading.readabilityHandler = nil
                    let output = tracker.currentOutput
                    continuation.resume(returning: (output, process.terminationStatus == 0))
                } catch {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: (error.localizedDescription, false))
                }
            }
        }
    }
}

// MARK: - Phase Detection

private func detectPhase(from output: String) -> String {
    let recent = output.suffix(2000)
    if recent.contains("evaluating") || recent.contains("evaluation") { return "Evaluating..." }
    if recent.contains("building") || recent.contains("Building") { return "Building..." }
    if recent.contains("copying") || recent.contains("Copying") { return "Copying..." }
    if recent.contains("activating") || recent.contains("Activating") { return "Activating..." }
    if recent.contains("fetching") || recent.contains("Fetching") { return "Fetching..." }
    if recent.contains("downloading") || recent.contains("Downloading") { return "Downloading..." }
    if recent.contains("unpacking") { return "Unpacking..." }
    if recent.contains("Updated") && recent.contains("Outdated") { return "Checking..." }
    if recent.contains("Upgrading") { return "Upgrading..." }
    if recent.contains("removing") || recent.contains("deleting") { return "Cleaning..." }
    return ""
}

// MARK: - Thread-Safe Output Tracker

private final class OutputTracker: @unchecked Sendable {
    private let lock = DispatchQueue(label: "com.nixbar.output")
    private var buffer = ""

    var currentOutput: String {
        lock.sync { buffer }
    }

    func append(_ chunk: String, onChange: @escaping (String) -> Void) {
        let updated: String = lock.sync {
            buffer += chunk
            return buffer
        }
        onChange(updated)
    }
}

// MARK: - Debug Logging

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
