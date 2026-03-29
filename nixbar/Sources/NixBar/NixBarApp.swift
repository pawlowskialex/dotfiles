import SwiftUI

@main
struct NixBarApp: App {
    @StateObject private var manager = NixManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(manager: manager)
                .frame(width: 480)
        } label: {
            Image(systemName: "snowflake")
        }
        .menuBarExtraStyle(.window)
    }
}
