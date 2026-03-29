import Foundation
import SwiftUI

// MARK: - Domain Models

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
    case idle, running, success, failure
}

// MARK: - Phase Detection

enum Phase: CaseIterable {
    case password, evaluating, building, copying, activating
    case fetching, downloading, unpacking, checking, upgrading, cleaning

    var label: String {
        switch self {
        case .password:    "Waiting for password..."
        case .evaluating:  "Evaluating..."
        case .building:    "Building..."
        case .copying:     "Copying..."
        case .activating:  "Activating..."
        case .fetching:    "Fetching..."
        case .downloading: "Downloading..."
        case .unpacking:   "Unpacking..."
        case .checking:    "Checking..."
        case .upgrading:   "Upgrading..."
        case .cleaning:    "Cleaning..."
        }
    }

    private var patterns: [String] {
        switch self {
        case .password:    ["password:"]
        case .evaluating:  ["evaluating", "evaluation"]
        case .building:    ["building", "Building"]
        case .copying:     ["copying", "Copying"]
        case .activating:  ["activating", "Activating"]
        case .fetching:    ["fetching", "Fetching"]
        case .downloading: ["downloading", "Downloading"]
        case .unpacking:   ["unpacking"]
        case .checking:    ["Updated"]
        case .upgrading:   ["Upgrading"]
        case .cleaning:    ["removing", "deleting"]
        }
    }

    static func detect(from output: String) -> Phase? {
        let recent = output.suffix(2000)
        if recent.localizedCaseInsensitiveContains("password:") { return .password }
        for phase in allCases where phase != .password {
            if phase == .checking {
                guard recent.contains("Updated"), recent.contains("Outdated") else { continue }
                return .checking
            }
            if phase.patterns.contains(where: { recent.contains($0) }) { return phase }
        }
        return nil
    }
}

// MARK: - Flake Lock (Codable)

struct FlakeLock: Decodable {
    let nodes: [String: FlakeNode]

    struct FlakeNode: Decodable {
        let locked: LockedInfo?

        struct LockedInfo: Decodable {
            let lastModified: Int?
        }
    }

    func inputs(relativeTo now: Date = .init()) -> [FlakeInput] {
        nodes.compactMap { name, node in
            guard name != "root",
                  let lastMod = node.locked?.lastModified
            else { return nil }
            let date = Date(timeIntervalSince1970: Double(lastMod))
            return FlakeInput(name: name, lastModified: date, age: date.relativeAge(to: now))
        }
        .sorted { $0.name < $1.name }
    }
}

// MARK: - Shell Events

enum ShellEvent {
    case output(String, phase: String)
    case finished(output: String, success: Bool)
}

enum PTYEvent {
    case output(String)
    case exited(success: Bool)
}

// MARK: - Formatting Extensions

extension TimeInterval {
    var formattedDuration: String {
        if self < 60 { return String(format: "%.0fs", self) }
        let m = Int(self) / 60
        let s = Int(self) % 60
        return s > 0 ? "\(m)m \(s)s" : "\(m)m"
    }
}

extension Date {
    func relativeAge(to now: Date = .init()) -> String {
        let days = Int(now.timeIntervalSince(self) / 86400)
        if days == 0 { return "today" }
        if days == 1 { return "1 day ago" }
        if days < 30 { return "\(days) days ago" }
        if days < 365 { return "\(days / 30) months ago" }
        return "\(days / 365)y \((days % 365) / 30)m ago"
    }
}
