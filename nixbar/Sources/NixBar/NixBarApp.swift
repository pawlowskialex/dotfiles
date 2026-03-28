import SwiftUI

@main
struct NixBarApp: App {
    @StateObject private var manager = NixManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: manager)
                .frame(width: 360)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: menuBarIcon)
                    .symbolEffect(.pulse, isActive: manager.isRunning)
                    .foregroundStyle(menuBarColor)
                if manager.isRunning {
                    Text(manager.currentTask)
                        .font(.caption2)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarIcon: String {
        switch manager.status {
        case .running: return "snowflake.circle"
        case .success: return "snowflake"
        case .failure: return "snowflake"
        case .idle: return "snowflake"
        }
    }

    private var menuBarColor: Color {
        switch manager.status {
        case .running: return .cyan
        case .success: return .green
        case .failure: return .red
        case .idle: return .primary
        }
    }
}
