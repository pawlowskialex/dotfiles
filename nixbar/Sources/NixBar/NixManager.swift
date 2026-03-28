import Foundation
import SwiftUI
import UserNotifications
import OSLog

private let log = Logger(subsystem: "com.alex.nixbar", category: "NixManager")

typealias Manager = NixManager

@MainActor
final class NixManager: ObservableObject {
    @Published var isRunning = false
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
    private let executor: ShellExecutor
    private var runningProcess: Process?
    private var timer: Timer?
    private var refreshTimer: Timer?

    init() {
        executor = ShellExecutor()

        Task { @MainActor [weak self] in
            self?.executor.onLiveOutput = { output, phase in
                Task { @MainActor [weak self] in
                    self?.liveOutput = output
                    self?.currentPhase = phase
                }
            }
        }

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

    // MARK: - Actions

    func rebuild() async {
        await runTask("Rebuild (build)", privileged: false, command: """
            nix --extra-experimental-features 'nix-command flakes' build --json --no-link \
            -- \(configPath)#darwinConfigurations.alex.system 2>&1
            """)
        guard let lastLog = logs.first, lastLog.success else { return }

        let output = lastLog.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let jsonStart = output.lastIndex(of: "["),
              let data = String(output[jsonStart...]).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let storePath = (json.first?["outputs"] as? [String: String])?["out"]
        else {
            logs.insert(TaskLog(task: "Rebuild", output: "Failed to parse build output:\n\(output)",
                                success: false, duration: 0, date: Date()), at: 0)
            status = .failure
            return
        }

        log.info("rebuild: built \(storePath)")
        await runTask("Rebuild (activate)", privileged: true,
                      command: "nix-env -p /nix/var/nix/profiles/system --set \(storePath) && \(storePath)/activate")
        await refreshInfo()
        await checkPendingChanges()
    }

    func updateFlake() async {
        await runTask("Flake Update", privileged: false,
                      command: "nix flake update --flake \(configPath) 2>&1")
        await loadFlakeInputs()
    }

    func brewUpdate() async {
        await runTask("Brew Update", privileged: false,
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
        await runTask("Garbage Collect", privileged: true, command: "nix-collect-garbage -d")
        await refreshInfo()
    }

    func editConfig() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = [configPath]
        try? p.run()
    }

    func cancelTask() {
        runningProcess?.terminate()
        runningProcess = nil
    }

    // MARK: - Info Refresh

    func refreshInfo() async {
        let genInfo = await executor.runSimple(
            "readlink /nix/var/nix/profiles/system 2>/dev/null"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if !genInfo.isEmpty,
           let match = genInfo.range(of: #"\d+"#, options: .regularExpression) {
            generationNumber = String(genInfo[match])
            let ts = await executor.runSimple(
                "stat -f '%m' /nix/var/nix/profiles/system 2>/dev/null"
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            if let t = Double(ts) { lastRebuild = Date(timeIntervalSince1970: t) }
        }

        storeSize = await executor.runSimple(
            "du -sh /nix/store 2>/dev/null | cut -f1"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        packageCount = await executor.runSimple(
            "ls /run/current-system/sw/bin 2>/dev/null | wc -l | tr -d ' '"
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func checkPendingChanges() async {
        let changes = await executor.runSimple(
            "cd \(configPath) && git diff --name-only 2>/dev/null && git diff --cached --name-only 2>/dev/null"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        pendingChanges = changes.isEmpty
            ? []
            : Array(Set(changes.components(separatedBy: "\n").filter { !$0.isEmpty }))
    }

    func loadFlakeInputs() async {
        let lockContent = await executor.runSimple("cat \(configPath)/flake.lock 2>/dev/null")
        guard !lockContent.isEmpty,
              let data = lockContent.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nodes = json["nodes"] as? [String: Any]
        else { return }

        let now = Date()
        flakeInputs = nodes.compactMap { name, value -> FlakeInput? in
            guard name != "root",
                  let node = value as? [String: Any],
                  let locked = node["locked"] as? [String: Any],
                  let lastMod = locked["lastModified"] as? Int
            else { return nil }
            let date = Date(timeIntervalSince1970: Double(lastMod))
            return FlakeInput(name: name, lastModified: date, age: ageString(from: date, relativeTo: now))
        }
        .sorted { $0.name < $1.name }
    }

    // MARK: - Task Execution (deduplicated)

    private func runTask(_ task: String, privileged: Bool, command: String) async {
        isRunning = true
        currentTask = task
        currentPhase = privileged ? "Waiting for authorization..." : ""
        liveOutput = ""
        elapsedTime = 0
        status = .running
        let start = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isRunning else { return }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }

        let (output, success): (String, Bool)
        if privileged {
            (output, success) = await executor.runPrivileged(command)
        } else {
            (output, success) = await executor.run(command)
        }

        timer?.invalidate()
        timer = nil

        let duration = Date().timeIntervalSince(start)
        logs.insert(TaskLog(task: task, output: output, success: success, duration: duration, date: Date()), at: 0)
        if logs.count > 50 { logs = Array(logs.prefix(50)) }

        status = success ? .success : .failure
        currentTask = ""
        currentPhase = ""
        isRunning = false
        runningProcess = nil

        sendNotification(title: task, success: success, duration: duration)

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            if self?.isRunning == false { self?.status = .idle }
        }
    }

    // MARK: - Periodic Refresh

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
        content.sound = success ? .default : .defaultCritical
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
