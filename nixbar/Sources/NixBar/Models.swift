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
    case idle
    case running
    case success
    case failure
}

// MARK: - Shared Helpers

func formatDuration(_ d: TimeInterval) -> String {
    if d < 60 { return String(format: "%.0fs", d) }
    let m = Int(d) / 60
    let s = Int(d) % 60
    return s > 0 ? "\(m)m \(s)s" : "\(m)m"
}

func ageString(from date: Date, relativeTo now: Date = .init()) -> String {
    let days = Int(now.timeIntervalSince(date) / 86400)
    if days == 0 { return "today" }
    if days == 1 { return "1 day ago" }
    if days < 30 { return "\(days) days ago" }
    if days < 365 { return "\(days / 30) months ago" }
    return "\(days / 365)y \((days % 365) / 30)m ago"
}
