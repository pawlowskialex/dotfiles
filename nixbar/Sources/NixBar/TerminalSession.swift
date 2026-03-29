import CTerminal
import Darwin
import Foundation
import OSLog

private let log = Logger(subsystem: "com.alex.nixbar", category: "TerminalSession")

/// Runs a shell command in a real PTY so interactive programs (sudo, brew, etc.)
/// can prompt the user for input through the terminal interface.
final class TerminalSession {
    private var masterFD: Int32 = -1
    private var childPID: pid_t = -1

    /// Spawn a PTY and return a stream of output events.
    /// Returns `nil` if the PTY could not be created.
    func start(command: String) -> AsyncStream<PTYEvent>? {
        var master: Int32 = -1
        let pid = command.withCString { pty_spawn_zsh($0, &master) }

        guard pid > 0 else {
            log.error("pty_spawn_zsh failed (errno \(errno))")
            return nil
        }

        masterFD = master
        childPID = pid
        log.info("PTY session started: pid=\(pid)")

        let handle = FileHandle(fileDescriptor: master, closeOnDealloc: false)

        return AsyncStream { continuation in
            handle.readabilityHandler = { fh in
                let data = fh.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    Darwin.close(master)
                    var status: Int32 = 0
                    waitpid(pid, &status, 0)
                    let success = status == 0
                    log.info("PTY session exited: pid=\(pid) success=\(success)")
                    continuation.yield(.exited(success: success))
                    continuation.finish()
                } else {
                    let text =
                        String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .isoLatin1)
                        ?? ""
                    continuation.yield(.output(text.strippingANSI))
                }
            }

            continuation.onTermination = { _ in
                handle.readabilityHandler = nil
            }
        }
    }

    func sendInput(_ text: String) {
        guard masterFD >= 0 else { return }
        text.withCString { ptr in
            _ = Darwin.write(masterFD, ptr, strlen(ptr))
        }
    }

    func terminate() {
        guard childPID > 0 else { return }
        kill(childPID, SIGTERM)
    }
}

// MARK: - ANSI Escape Stripping

extension String {
    var strippingANSI: String {
        let s = replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var out = ""
        out.reserveCapacity(s.count)
        var i = s.startIndex

        while i < s.endIndex {
            let ch = s[i]
            guard ch == "\u{1B}" else {
                out.append(ch)
                i = s.index(after: i)
                continue
            }

            let next = s.index(after: i)
            guard next < s.endIndex else { break }

            switch s[next] {
            case "[":
                i = s.index(after: next)
                while i < s.endIndex {
                    let c = s[i]
                    i = s.index(after: i)
                    if c.isLetter || c == "~" || c == "@" { break }
                }
            case "]":
                i = s.index(after: next)
                while i < s.endIndex {
                    let c = s[i]
                    i = s.index(after: i)
                    if c == "\u{07}" || c == "\u{1B}" { break }
                }
            default:
                i = s.index(after: next)
            }
        }

        return out
    }
}
