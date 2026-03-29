import Foundation
import OSLog
import SwiftUI
import UserNotifications

private let log = Logger(subsystem: "com.alex.nixbar", category: "NixManager")

@MainActor
final class NixManager: ObservableObject {
    @Published var isRunning = false
    @Published var showTerminal = false
    @Published var currentTask = ""
    @Published var currentPhase = ""
    @Published var liveOutput = ""
    @Published var logs: [TaskLog] = []
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
    private let executor = ShellExecutor()
    private var refreshTask: Task<Void, Never>?

    init() {
        Task {
            await refreshInfo()
            await checkPendingChanges()
            loadFlakeInputs()
        }
        requestNotificationPermission()
        startPeriodicRefresh()
    }

    deinit { refreshTask?.cancel() }

    // MARK: - Actions

    func rebuild() async {
        await runTask("Rebuild", command: "sudo darwin-rebuild switch --flake \(configPath)#alex")
        await refreshInfo()
        await checkPendingChanges()
    }

    func updateFlake() async {
        await runTask("Flake Update", command: "nix flake update --flake \(configPath) 2>&1")
        loadFlakeInputs()
    }

    func brewUpdate() async {
        await runTask(
            "Brew Update",
            command: "/opt/homebrew/bin/brew update && /opt/homebrew/bin/brew upgrade 2>&1")
    }

    func updateAll() async {
        await updateFlake()
        guard logs.first?.success == true else { return }
        await brewUpdate()
        guard logs.first?.success == true else { return }
        await rebuild()
    }

    func garbageCollect() async {
        await runTask("Garbage Collect", command: "sudo nix-collect-garbage -d")
        await refreshInfo()
    }

    func editConfig() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = [configPath]
        try? p.run()
    }

    func cancelTask() { executor.cancel() }

    func dismissTerminal() {
        showTerminal = false
        liveOutput = ""
        currentTask = ""
        currentPhase = ""
    }

    func sendInput(_ text: String) {
        executor.sendInput(text + "\n")
    }

    // MARK: - Info Refresh

    func refreshInfo() async {
        let genInfo = await executor.runSimple(
            "readlink /nix/var/nix/profiles/system 2>/dev/null"
        ).trimmed

        if let match = genInfo.range(of: #"\d+"#, options: .regularExpression) {
            generationNumber = String(genInfo[match])
            let ts = await executor.runSimple(
                "stat -f '%m' /nix/var/nix/profiles/system 2>/dev/null"
            ).trimmed
            if let t = Double(ts) { lastRebuild = Date(timeIntervalSince1970: t) }
        }

        storeSize = await executor.runSimple(
            "du -sh /nix/store 2>/dev/null | cut -f1"
        ).trimmed

        packageCount = await executor.runSimple(
            "ls /run/current-system/sw/bin 2>/dev/null | wc -l | tr -d ' '"
        ).trimmed
    }

    func checkPendingChanges() async {
        let changes = await executor.runSimple(
            "cd \(configPath) && git diff --name-only 2>/dev/null && git diff --cached --name-only 2>/dev/null"
        ).trimmed
        pendingChanges = changes.isEmpty
            ? []
            : Array(Set(changes.split(separator: "\n").map(String.init)))
    }

    func loadFlakeInputs() {
        let url = URL(fileURLWithPath: configPath).appendingPathComponent("flake.lock")
        guard let data = try? Data(contentsOf: url),
              let lock = try? JSONDecoder().decode(FlakeLock.self, from: data)
        else { return }
        flakeInputs = lock.inputs()
    }

    // MARK: - Task Execution

    private func runTask(_ task: String, command: String) async {
        isRunning = true
        showTerminal = true
        currentTask = task
        currentPhase = ""
        liveOutput = ""
        elapsedTime = 0
        status = .running
        let start = Date()

        let timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard isRunning else { break }
                elapsedTime = Date().timeIntervalSince(start)
            }
        }

        var finalOutput = ""
        var success = false

        for await event in executor.run(command) {
            switch event {
            case .output(let text, let phase):
                liveOutput = text
                if !phase.isEmpty { currentPhase = phase }
            case .finished(let output, let ok):
                finalOutput = output
                success = ok
            }
        }

        timerTask.cancel()

        let duration = Date().timeIntervalSince(start)
        logs.insert(
            TaskLog(task: task, output: finalOutput, success: success, duration: duration, date: .now),
            at: 0)
        if logs.count > 50 { logs = Array(logs.prefix(50)) }

        status = success ? .success : .failure
        isRunning = false
        sendNotification(title: task, success: success, duration: duration)
    }

    // MARK: - Periodic Refresh

    private func startPeriodicRefresh() {
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !isRunning else { continue }
                await refreshInfo()
                await checkPendingChanges()
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
            ? "Finished in \(duration.formattedDuration)"
            : "Task failed after \(duration.formattedDuration). Click to view details."
        content.sound = success ? .default : .defaultCritical
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
