import Foundation
import OSLog

private let log = Logger(subsystem: "com.alex.nixbar", category: "ShellExecutor")

final class ShellExecutor {
    private(set) var currentSession: TerminalSession?

    /// Run `command` in a PTY, streaming live events back as an `AsyncStream`.
    func run(_ command: String) -> AsyncStream<ShellEvent> {
        log.info("run: \(command)")
        let session = TerminalSession()
        currentSession = session

        return AsyncStream { continuation in
            guard let ptyStream = session.start(command: command) else {
                continuation.yield(.finished(output: "", success: false))
                continuation.finish()
                return
            }

            let task = Task.detached { [weak self] in
                var fullOutput = ""
                var success = false

                for await event in ptyStream {
                    switch event {
                    case .output(let chunk):
                        fullOutput += chunk
                        let tail = String(fullOutput.suffix(2000))
                        let phase = Phase.detect(from: fullOutput)?.label ?? ""
                        continuation.yield(.output(tail, phase: phase))
                    case .exited(let ok):
                        success = ok
                    }
                }

                self?.currentSession = nil
                continuation.yield(.finished(output: fullOutput, success: success))
                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func sendInput(_ text: String) {
        currentSession?.sendInput(text)
    }

    func cancel() {
        currentSession?.terminate()
        currentSession = nil
    }

    /// Lightweight non-PTY execution for simple info queries.
    func runSimple(_ command: String) async -> String {
        await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", command]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
