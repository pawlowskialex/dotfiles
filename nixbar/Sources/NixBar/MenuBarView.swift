import SwiftUI

struct MenuBarView: View {
    @ObservedObject var manager: NixManager
    @State private var selectedLog: TaskLog?
    @State private var showFlakeInputs = false
    @State private var terminalInput = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if manager.showTerminal {
                terminalView
            } else {
                statusDashboard
                Divider()
                actionButtons
                Divider()
                historySection
            }

            Divider()
            footer
        }
        .padding(.vertical, 8)
        .sheet(item: $selectedLog) { LogDetailView(log: $0) }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "snowflake")
                .font(.title2)
                .foregroundStyle(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("NixBar").font(.headline)
                    if !manager.generationNumber.isEmpty {
                        Text("Gen \(manager.generationNumber)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.cyan.opacity(0.15), in: Capsule())
                            .foregroundStyle(.cyan)
                    }
                }
                if let lastRebuild = manager.lastRebuild {
                    Text("Built \(lastRebuild, style: .relative) ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if !manager.storeSize.isEmpty {
                    Label(manager.storeSize, systemImage: "internaldrive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !manager.packageCount.isEmpty {
                    Label(manager.packageCount, systemImage: "shippingbox")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Status Dashboard

    private var statusDashboard: some View {
        VStack(spacing: 8) {
            pendingChangesBanner
            flakeInputsDisclosure
            lastResultStatus
        }
        .padding(.vertical, 6)
    }

    private var pendingChangesBanner: some View {
        Group {
            if !manager.pendingChanges.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(manager.pendingChanges.count) pending change\(manager.pendingChanges.count == 1 ? "" : "s")")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Text(manager.pendingChanges.prefix(3).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button { Task { await manager.rebuild() } } label: {
                        Text("Rebuild")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
            }
        }
    }

    private var flakeInputsDisclosure: some View {
        Group {
            if !manager.flakeInputs.isEmpty {
                DisclosureGroup(isExpanded: $showFlakeInputs) {
                    VStack(spacing: 2) {
                        ForEach(manager.flakeInputs) { input in
                            HStack {
                                Text(input.name)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(input.age)
                                    .font(.caption2)
                                    .foregroundStyle(ageColor(for: input.lastModified))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                            .font(.caption)
                            .foregroundStyle(.purple)
                        Text("\(manager.flakeInputs.count) flake inputs").font(.caption)
                        if let oldest = oldestInput {
                            Text("oldest: \(oldest.age)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    private var lastResultStatus: some View {
        Group {
            if let lastLog = manager.logs.first, !manager.isRunning {
                HStack(spacing: 6) {
                    Image(systemName: lastLog.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(lastLog.success ? .green : .red)
                        .font(.caption)
                    Text(lastLog.task).font(.caption2)
                    Text(lastLog.success ? "succeeded" : "failed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastLog.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }

    private var oldestInput: FlakeInput? {
        manager.flakeInputs.min(by: { $0.lastModified < $1.lastModified })
    }

    private func ageColor(for date: Date) -> Color {
        let days = Int(Date().timeIntervalSince(date) / 86400)
        if days < 7 { return .green }
        if days < 30 { return .secondary }
        if days < 90 { return .orange }
        return .red
    }

    // MARK: - Terminal View (running + completed)

    private var terminalView: some View {
        VStack(alignment: .leading, spacing: 8) {
            terminalHeader

            ScrollViewReader { proxy in
                ScrollView {
                    Text(manager.liveOutput.isEmpty ? " " : String(manager.liveOutput.suffix(2000)))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .onChange(of: manager.liveOutput) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .frame(height: 260)
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            if manager.isRunning {
                terminalInputField
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var terminalHeader: some View {
        HStack {
            if manager.isRunning {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 1) {
                    Text(manager.currentTask).font(.subheadline.bold())
                    Text(manager.currentPhase.isEmpty ? " " : manager.currentPhase)
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(elapsedTimeString(manager.elapsedTime))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button { manager.cancelTask() } label: {
                        Text("Cancel").font(.caption2).foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                let succeeded = manager.status == .success
                Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(succeeded ? .green : .red)
                Text(manager.currentTask)
                    .font(.subheadline.bold())
                Text(succeeded ? "succeeded" : "failed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let log = manager.logs.first {
                    Text("(\(log.duration.formattedDuration))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { manager.dismissTerminal() } label: {
                    Text("Dismiss")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var terminalInputField: some View {
        let isPasswordPrompt = manager.liveOutput.suffix(150)
            .localizedCaseInsensitiveContains("password:")

        return HStack(spacing: 6) {
            Image(systemName: isPasswordPrompt ? "lock.fill" : "chevron.right")
                .font(.system(size: 10))
                .foregroundStyle(isPasswordPrompt ? Color.orange : Color.secondary)
                .frame(width: 14)

            if isPasswordPrompt {
                SecureField("Password…", text: $terminalInput)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { submitTerminalInput() }
            } else {
                TextField("Send input…", text: $terminalInput)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { submitTerminalInput() }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
    }

    private func submitTerminalInput() {
        manager.sendInput(terminalInput)
        terminalInput = ""
    }

    private func elapsedTimeString(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 2) {
            ActionButton(title: "Update All", subtitle: "flake + brew + rebuild",
                         icon: "arrow.trianglehead.2.clockwise.rotate.90", tint: .cyan) {
                Task { await manager.updateAll() }
            }
            ActionButton(title: "Rebuild", subtitle: "darwin-rebuild switch",
                         icon: "hammer", tint: .blue) {
                Task { await manager.rebuild() }
            }
            ActionButton(title: "Update Flake", subtitle: "nix flake update",
                         icon: "arrow.down.circle", tint: .purple) {
                Task { await manager.updateFlake() }
            }
            ActionButton(title: "Brew Update", subtitle: "update & upgrade",
                         icon: "mug", tint: .orange) {
                Task { await manager.brewUpdate() }
            }
            ActionButton(title: "Garbage Collect", subtitle: "nix-collect-garbage -d",
                         icon: "trash", tint: .red) {
                Task { await manager.garbageCollect() }
            }

            Divider().padding(.vertical, 4)

            ActionButton(title: "Edit Config", subtitle: "~/.nixpkgs",
                         icon: "doc.text", tint: .secondary) {
                manager.editConfig()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if manager.logs.isEmpty {
                Text("No recent activity")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                Text("Recent")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                VStack(spacing: 2) {
                    ForEach(Array(manager.logs.prefix(10))) { log in
                        LogRow(log: log)
                            .onTapGesture { selectedLog = log }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                Task {
                    await manager.refreshInfo()
                    await manager.checkPendingChanges()
                    manager.loadFlakeInputs()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            // DEBUG: verify log population
            Text("\(manager.logs.count) logs")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Spacer()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}
