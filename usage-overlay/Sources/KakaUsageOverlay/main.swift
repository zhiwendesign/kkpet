import Cocoa
import WebKit

private struct UsageSnapshot {
    var remainingPercent: Int?
    var usedPercent: Int?
    var dailyTokens: Int64?
    var dailyDate: String?
    var resetsAt: Int64?

    static let loading = UsageSnapshot(
        remainingPercent: nil,
        usedPercent: nil,
        dailyTokens: nil,
        dailyDate: nil,
        resetsAt: nil
    )

    func jsonObject() -> [String: Any] {
        [
            "remainingPercent": remainingPercent as Any? ?? NSNull(),
            "usedPercent": usedPercent as Any? ?? NSNull(),
            "dailyTokens": dailyTokens as Any? ?? NSNull(),
            "dailyDate": dailyDate as Any? ?? NSNull(),
            "resetsAt": resetsAt as Any? ?? NSNull()
        ]
    }
}

private struct CodexPetPresentation: Equatable {
    var isOpen: Bool
    var isCodexRunning: Bool
    var isCodexHidden: Bool
    var anchorX: CGFloat?
    var anchorY: CGFloat?

    static let unavailable = CodexPetPresentation(
        isOpen: false,
        isCodexRunning: false,
        isCodexHidden: false,
        anchorX: nil,
        anchorY: nil
    )

    var shouldShow: Bool {
        isOpen && isCodexRunning && !isCodexHidden && anchorX != nil && anchorY != nil
    }
}

private final class CodexPetMonitor {
    var onUpdate: ((CodexPetPresentation) -> Void)?

    private let stateURL: URL
    private var timer: Timer?
    private var lastPresentation = CodexPetPresentation.unavailable
    private var cachedIsOpen = false
    private var cachedAnchorX: CGFloat?
    private var cachedAnchorY: CGFloat?

    init() {
        stateURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/.codex-global-state.json")
    }

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        updateCachedState()

        let applications = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.openai.codex"
        ).filter { !$0.isTerminated }
        let presentation = CodexPetPresentation(
            isOpen: cachedIsOpen,
            isCodexRunning: !applications.isEmpty,
            isCodexHidden: !applications.isEmpty && applications.allSatisfy(\.isHidden),
            anchorX: cachedAnchorX,
            anchorY: cachedAnchorY
        )

        guard presentation != lastPresentation else { return }
        lastPresentation = presentation
        onUpdate?(presentation)
    }

    private func updateCachedState() {
        guard let data = try? Data(contentsOf: stateURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        cachedIsOpen = object["electron-avatar-overlay-open"] as? Bool ?? false
        guard let bounds = object["electron-avatar-overlay-bounds"] as? [String: Any],
              let x = bounds["x"] as? NSNumber,
              let y = bounds["y"] as? NSNumber else {
            cachedAnchorX = nil
            cachedAnchorY = nil
            return
        }
        cachedAnchorX = CGFloat(x.doubleValue)
        cachedAnchorY = CGFloat(y.doubleValue)
    }
}

private final class CodexUsageService {
    var onUpdate: ((UsageSnapshot) -> Void)?

    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputBuffer = Data()
    private var pollTimer: Timer?
    private var nextRequestID = 2
    private var pendingRequests: [Int: String] = [:]
    private var snapshot = UsageSnapshot.loading

    func start() {
        guard process == nil, let executable = codexExecutable() else {
            return
        }

        let process = Process()
        let input = Pipe()
        let output = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                self?.consume(data)
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                guard let self, self.process != nil else { return }
                self.stopProcessOnly()
                self.start()
            }
        }

        do {
            try process.run()
            self.process = process
            self.inputHandle = input.fileHandleForWriting
            send([
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "kaka-usage-overlay",
                        "title": "卡卡用量悬浮层",
                        "version": "1.5.0"
                    ],
                    "capabilities": [
                        "experimentalApi": true,
                        "requestAttestation": false,
                        "optOutNotificationMethods": []
                    ]
                ]
            ])
        } catch {
            stopProcessOnly()
        }
    }

    func refresh() {
        guard process?.isRunning == true else {
            start()
            return
        }

        request(method: "account/rateLimits/read", kind: "rateLimits")
        request(method: "account/usage/read", kind: "usage")
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        process?.terminationHandler = nil
        stopProcessOnly()
    }

    private func codexExecutable() -> String? {
        let candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            NSString(string: "~/.local/bin/codex").expandingTildeInPath,
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        return candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) })
    }

    private func request(method: String, kind: String) {
        let id = nextRequestID
        nextRequestID += 1
        pendingRequests[id] = kind
        send(["id": id, "method": method])
    }

    private func send(_ object: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(object),
              var data = try? JSONSerialization.data(withJSONObject: object) else {
            return
        }
        data.append(0x0A)
        try? inputHandle?.write(contentsOf: data)
    }

    private func consume(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 0x0A) {
            let line = outputBuffer[..<newline]
            outputBuffer.removeSubrange(...newline)
            guard !line.isEmpty,
                  let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any] else {
                continue
            }
            handle(object)
        }
    }

    private func handle(_ object: [String: Any]) {
        if let id = (object["id"] as? NSNumber)?.intValue, id == 1, object["result"] != nil {
            send(["method": "initialized"])
            refresh()
            pollTimer?.invalidate()
            pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.refresh()
            }
            return
        }

        if object["method"] as? String == "account/rateLimits/updated",
           let params = object["params"] as? [String: Any],
           let limits = params["rateLimits"] as? [String: Any] {
            applyRateLimits(limits)
            publish()
            return
        }

        guard let id = (object["id"] as? NSNumber)?.intValue,
              let kind = pendingRequests.removeValue(forKey: id),
              let result = object["result"] as? [String: Any] else {
            return
        }

        switch kind {
        case "rateLimits":
            let buckets = result["rateLimitsByLimitId"] as? [String: Any]
            let codexBucket = buckets?["codex"] as? [String: Any]
            let limits = codexBucket ?? (result["rateLimits"] as? [String: Any])
            if let limits { applyRateLimits(limits) }
        case "usage":
            applyDailyUsage(result)
        default:
            break
        }
        publish()
    }

    private func applyRateLimits(_ limits: [String: Any]) {
        let windows = ["primary", "secondary"].compactMap { limits[$0] as? [String: Any] }
        let weekly = windows.first(where: {
            (($0["windowDurationMins"] as? NSNumber)?.intValue ?? 0) >= 7 * 24 * 60
        }) ?? windows.max(by: {
            (($0["windowDurationMins"] as? NSNumber)?.intValue ?? 0) <
            (($1["windowDurationMins"] as? NSNumber)?.intValue ?? 0)
        })

        guard let weekly,
              let used = (weekly["usedPercent"] as? NSNumber)?.intValue else {
            return
        }

        let clampedUsed = min(100, max(0, used))
        snapshot.usedPercent = clampedUsed
        snapshot.remainingPercent = 100 - clampedUsed
        snapshot.resetsAt = (weekly["resetsAt"] as? NSNumber)?.int64Value
    }

    private func applyDailyUsage(_ result: [String: Any]) {
        guard let buckets = result["dailyUsageBuckets"] as? [[String: Any]],
              let latest = buckets.max(by: {
                  ($0["startDate"] as? String ?? "") < ($1["startDate"] as? String ?? "")
              }) else {
            return
        }

        snapshot.dailyDate = latest["startDate"] as? String
        snapshot.dailyTokens = (latest["tokens"] as? NSNumber)?.int64Value
    }

    private func publish() {
        onUpdate?(snapshot)
    }

    private func stopProcessOnly() {
        process?.standardOutput = nil
        process?.standardInput = nil
        if process?.isRunning == true {
            process?.terminate()
        }
        inputHandle = nil
        process = nil
        outputBuffer.removeAll(keepingCapacity: false)
        pendingRequests.removeAll()
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private var panel: NSPanel!
    private var webView: WKWebView!
    private var usageService: CodexUsageService?
    private var petMonitor: CodexPetMonitor?
    private var currentSnapshot = UsageSnapshot.loading
    private var currentPetPresentation = CodexPetPresentation.unavailable
    private var webViewReady = false
    private let panelSize = NSSize(width: 156, height: 48)

    private var isPreviewMode: Bool {
        CommandLine.arguments.contains("--preview")
    }

    private var isCompanionMode: Bool {
        !isPreviewMode && !CommandLine.arguments.contains("--standalone")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makePanel()
        loadInterface()

        if let preview = previewPercent() {
            currentSnapshot = UsageSnapshot(
                remainingPercent: preview,
                usedPercent: 100 - preview,
                dailyTokens: 36_667_046,
                dailyDate: "2026-07-20",
                resetsAt: Int64(Date().addingTimeInterval(3 * 24 * 3600).timeIntervalSince1970)
            )
        } else {
            let service = CodexUsageService()
            service.onUpdate = { [weak self] snapshot in
                self?.currentSnapshot = snapshot
                self?.render(snapshot)
            }
            usageService = service
            service.start()
        }

        if isCompanionMode {
            let monitor = CodexPetMonitor()
            monitor.onUpdate = { [weak self] presentation in
                self?.currentPetPresentation = presentation
                self?.applyPetPresentation()
            }
            petMonitor = monitor
            monitor.start()
        } else {
            panel.orderFrontRegardless()
        }

        if let seconds = quitAfterSeconds() {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                NSApp.terminate(nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        petMonitor?.stop()
        usageService?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !isCompanionMode
    }

    private func makePanel() {
        let size = panelSize
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 24,
            y: screenFrame.minY + 24
        )

        panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = false
        panel.isMovableByWindowBackground = !isCompanionMode
        panel.ignoresMouseEvents = isCompanionMode
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if !isCompanionMode {
            panel.setFrameAutosaveName("KakaUsageOverlayWindow")
        }

        let configuration = WKWebViewConfiguration()

        webView = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.autoresizingMask = [.width, .height]
        panel.contentView = webView
    }

    private func loadInterface() {
        guard let html = Bundle.main.url(forResource: "index", withExtension: "html") else {
            return
        }
        webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webViewReady = true
        render(currentSnapshot)
        applyPetPresentation()
    }

    private func applyPetPresentation() {
        guard isCompanionMode else { return }

        if currentPetPresentation.shouldShow {
            positionPanelAbovePet(currentPetPresentation)
            guard webViewReady else { return }
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private func positionPanelAbovePet(_ presentation: CodexPetPresentation) {
        guard let anchorX = presentation.anchorX,
              let anchorY = presentation.anchorY else {
            return
        }

        let primaryScreen = NSScreen.screens.first(where: {
            abs($0.frame.origin.x) < 0.5 && abs($0.frame.origin.y) < 0.5
        }) ?? NSScreen.main
        let primaryTop = primaryScreen?.frame.maxY ?? 900
        let petTopInAppKit = primaryTop - anchorY
        let petWidth: CGFloat = 112
        let usageTopOffset: CGFloat = 46

        var origin = NSPoint(
            x: anchorX + petWidth / 2 - panelSize.width / 2,
            y: petTopInAppKit + usageTopOffset - panelSize.height
        )

        let petPoint = NSPoint(x: anchorX + petWidth / 2, y: petTopInAppKit)
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(petPoint, $0.frame, false) })
            ?? primaryScreen
            ?? NSScreen.main
        if let visibleFrame = targetScreen?.visibleFrame {
            origin.x = min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - panelSize.width)
            origin.y = min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - panelSize.height)
        }

        let currentOrigin = panel.frame.origin
        guard abs(currentOrigin.x - origin.x) > 0.5 || abs(currentOrigin.y - origin.y) > 0.5 else {
            return
        }
        panel.setFrameOrigin(origin)
    }

    private func render(_ snapshot: UsageSnapshot) {
        if let remaining = snapshot.remainingPercent {
            let tokens = snapshot.dailyTokens.map(String.init) ?? "—"
            panel.title = "卡卡用量 · 周剩余 \(remaining)% · 每日 Token \(tokens)"
        } else {
            panel.title = "卡卡用量 · 正在同步"
        }

        guard webViewReady,
              JSONSerialization.isValidJSONObject(snapshot.jsonObject()),
              let data = try? JSONSerialization.data(withJSONObject: snapshot.jsonObject()),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        webView.evaluateJavaScript("window.__kakaUpdate(\(json));")
    }

    private func previewPercent() -> Int? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--preview"), args.indices.contains(index + 1) else {
            return nil
        }
        return Int(args[index + 1]).map { min(100, max(0, $0)) }
    }

    private func quitAfterSeconds() -> Double? {
        let args = CommandLine.arguments
        guard let index = args.firstIndex(of: "--quit-after"), args.indices.contains(index + 1) else {
            return nil
        }
        return Double(args[index + 1])
    }
}

let application = NSApplication.shared
private let applicationDelegate = AppDelegate()
application.delegate = applicationDelegate
application.run()
