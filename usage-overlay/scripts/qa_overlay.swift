import AppKit
import Foundation
import WebKit

private enum QAError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): message
        }
    }
}

private struct SpriteStyle: Decodable {
    let display: String
    let width: String
    let transform: String
    let animationName: String
    let backgroundPosition: String
    let state: String
    let actionTrigger: String
    let actionPhase: String
    let frameDuration: String
    let lyingDisplay: String
    let cardWidth: String
    let cardBackgroundColor: String
    let barWidth: String
    let barHeight: String
    let barBorderTopWidth: String
    let barBackgroundColor: String
    let fillBackgroundImage: String
    let percentText: String
    let tokenText: String
    let weekValue: String
    let wLabelCount: Int
    let buttonCount: Int
    let todayLineText: String
    let todayLabelColor: String
}

@main
struct KakaOverlayQA {
    static func main() throws {
        _ = NSApplication.shared

        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let resources = root.appendingPathComponent("Resources", isDirectory: true)
        let output = root.appendingPathComponent("qa/usage-overlay", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 244, height: 260),
            configuration: configuration
        )
        webView.setValue(false, forKey: "drawsBackground")

        let window = NSWindow(
            contentRect: NSRect(x: 24, y: 80, width: 244, height: 260),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentView = webView
        window.orderFrontRegardless()

        webView.loadFileURL(
            resources.appendingPathComponent("index.html"),
            allowingReadAccessTo: resources
        )

        try waitUntilReady(webView)
        // Keep QA screenshots deterministic while leaving production transitions untouched.
        _ = try evaluate(webView, "document.getElementById('barFill').style.transition = 'none'")

        // Force a state transition so the idle timing check starts at frame zero.
        try update(webView, remaining: 90)
        try update(webView, remaining: 40)
        var style = try readStyle(webView)
        try require(style.width == "112px", "人物宽度不是原生 112 px")
        try require(style.transform == "none", "检测到额外 transform 动画")
        try require(style.animationName == "none", "检测到额外 CSS animation")
        try require(style.state == "state-normal", "正常状态没有使用独立 idle 动画")
        try require(style.frameDuration == "3360", "正常状态默认动作仍然过于频繁")
        try require(style.backgroundPosition == "0px 0px", "idle 起始帧不正确")
        try require(style.cardWidth == "132px", "用量区没有使用紧凑两行宽度")
        try require(style.cardBackgroundColor == "rgba(0, 0, 0, 0)", "用量区仍有厚重卡片背景")
        try require(style.barWidth == "132px" && style.barHeight == "12px", "第一行进度条尺寸不正确")
        try require(style.barBorderTopWidth == "0px", "进度条仍有黑色边框")
        try require(style.barBackgroundColor.contains("63, 140, 255"), "进度条底轨不是浅蓝色")
        try require(style.fillBackgroundImage.contains("rgb(40, 120, 243)"), "周进度条没有使用蓝色")
        try require(style.percentText == "40%" && style.weekValue == "40", "周剩余百分比显示不正确")
        try require(style.tokenText == "1.23M", "Today Token 没有使用参考图的紧凑格式")
        try require(style.wLabelCount == 0, "W 标签仍然存在")
        try require(style.buttonCount == 0, "右上角刷新或关闭按钮仍然存在")
        try require(style.todayLineText == "Today: 1.23M", "第二行不是 Today: 今日用量")
        try require(style.todayLabelColor.contains("255, 212, 74"), "Today 标签没有使用黄色")
        try advance(webView)
        style = try readStyle(webView)
        try require(
            style.backgroundPosition == "-112px 0px",
            "idle 没有按原生节奏进入第二帧（实际：\(style.backgroundPosition)）"
        )
        try snapshot(webView, to: output.appendingPathComponent("normal-40.png"))

        style = try beginHoverAction(
            webView,
            actionState: "jump-normal",
            waveSnapshot: output.appendingPathComponent("hover-wave.png")
        )
        try require(style.frameDuration == "155", "普通跳没有使用独立节奏")
        try require(style.backgroundPosition.hasPrefix("0px -485.33"), "普通跳起始帧不正确")
        try advance(webView)
        style = try readStyle(webView)
        try require(style.backgroundPosition.hasPrefix("-112px -485.33"), "普通跳帧间隔不正确")
        try snapshot(webView, to: output.appendingPathComponent("normal-hover.png"))
        try waitForState(webView, state: "state-normal")
        try hover(webView, inside: false)

        try dispatch(webView, event: "click")
        style = try readStyle(webView)
        try require(
            style.state == "jump-normal" && style.actionTrigger == "click" && style.actionPhase == "state-action",
            "点击没有直接触发当前正常状态动作"
        )
        try waitForState(webView, state: "state-normal")

        try update(webView, remaining: 90)
        style = try readStyle(webView)
        try require(style.state == "state-lively", "活泼状态没有使用独立低频待机")
        try require(style.frameDuration == "2520", "活泼状态默认动作仍然过于频繁")
        try require(style.backgroundPosition == "0px 0px", "活泼待机起始帧不正确")
        try snapshot(webView, to: output.appendingPathComponent("lively-90.png"))
        try advance(webView)
        style = try readStyle(webView)
        try require(style.backgroundPosition == "-112px 0px", "活泼低频待机没有使用原生 idle 帧")
        style = try beginHoverAction(webView, actionState: "jump-lively")
        try require(style.frameDuration == "78", "快速双跳没有使用独立节奏")
        try require(style.backgroundPosition.hasPrefix("0px -485.33"), "挥手后没有衔接快速双跳")
        try snapshot(webView, to: output.appendingPathComponent("lively-hover.png"))
        try waitForState(webView, state: "state-lively")
        try hover(webView, inside: false)

        try dispatch(webView, event: "click")
        style = try readStyle(webView)
        try require(
            style.state == "jump-lively" && style.actionTrigger == "click" && style.actionPhase == "state-action",
            "点击没有直接触发快速双跳"
        )
        try waitForState(webView, state: "state-lively")

        try update(webView, remaining: 15)
        style = try readStyle(webView)
        try require(style.state == "state-tired", "疲惫状态没有使用独立低频待机")
        try require(style.frameDuration == "5200", "疲惫状态默认动作仍然过于频繁")
        try require(style.backgroundPosition.hasPrefix("0px -606.66"), "疲惫起始帧不正确")
        try snapshot(webView, to: output.appendingPathComponent("tired-15.png"))
        try advance(webView)
        style = try readStyle(webView)
        try require(style.backgroundPosition.hasPrefix("-112px -606.66"), "疲惫低频待机没有使用轻微缓动")
        style = try beginHoverAction(webView, actionState: "jump-tired")
        try require(style.frameDuration == "260", "弱跳没有使用独立节奏")
        try require(style.backgroundPosition.hasPrefix("0px -485.33"), "挥手后没有衔接弱跳")
        try advance(webView)
        style = try readStyle(webView)
        try require(style.backgroundPosition.hasPrefix("-112px -485.33"), "弱跳节奏不正确")
        try snapshot(webView, to: output.appendingPathComponent("tired-hover.png"))
        try waitForState(webView, state: "state-tired")
        try hover(webView, inside: false)

        try dispatch(webView, event: "click")
        style = try readStyle(webView)
        try require(
            style.state == "jump-tired" && style.actionTrigger == "click" && style.actionPhase == "state-action",
            "点击没有直接触发疲惫弱跳"
        )
        try waitForState(webView, state: "state-tired")

        try update(webView, remaining: 3)
        style = try readStyle(webView)
        try require(style.display == "none" && style.lyingDisplay == "block", "低于 5% 没有躺下")
        try require(style.state == "state-lying", "躺下状态没有使用独立动画标识")
        try require(style.frameDuration == "1000", "躺下状态节奏不正确")
        try snapshot(webView, to: output.appendingPathComponent("lying-3.png"))

        style = try beginHoverAction(webView, actionState: "jump-lying")
        try require(style.display == "block" && style.lyingDisplay == "none", "躺下状态 hover 没有切回原生人物")
        try require(style.frameDuration == "360", "勉强起身没有使用独立节奏")
        try advance(webView)
        try advance(webView)
        style = try readStyle(webView)
        try require(style.backgroundPosition.contains("-485.33"), "勉强起身动作没有进入小跳帧")
        try snapshot(webView, to: output.appendingPathComponent("lying-hover.png"))
        try waitForState(webView, state: "state-lying")
        style = try readStyle(webView)
        try require(style.display == "none" && style.lyingDisplay == "block", "动作结束后没有自动恢复躺下")
        try hover(webView, inside: false)

        try dispatch(webView, event: "click")
        style = try readStyle(webView)
        try require(
            style.state == "jump-lying" && style.actionTrigger == "click" && style.actionPhase == "state-action",
            "点击没有直接触发勉强起身"
        )
        try waitForState(webView, state: "state-lying")

        window.orderOut(nil)
        print("卡卡 QA 通过：四档 hover 均先挥手，再衔接一次性专属动作")
    }

    private static func waitUntilReady(_ webView: WKWebView) throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let ready = try? evaluate(
                webView,
                "typeof window.__kakaUpdate === 'function' && typeof window.__kakaPointerMoved === 'function'"
            ),
               (ready as? Bool) == true {
                return
            }
            spin(0.05)
        }
        throw QAError.failed("悬浮层在 10 秒内没有加载完成")
    }

    private static func update(_ webView: WKWebView, remaining: Int) throws {
        _ = try evaluate(
            webView,
            "window.__kakaUpdate({remainingPercent:\(remaining),dailyTokens:1234567,dailyDate:'2026-07-21'})"
        )
        spin(0.05)
    }

    private static func dispatch(_ webView: WKWebView, event: String) throws {
        _ = try evaluate(
            webView,
            "document.getElementById('characterWrap').dispatchEvent(new MouseEvent('\(event)'))"
        )
        spin(0.05)
    }

    private static func hover(_ webView: WKWebView, inside: Bool) throws {
        let script: String
        if inside {
            script = """
            (() => {
              const rect = document.getElementById('characterWrap').getBoundingClientRect();
              window.__kakaPointerMoved(rect.left + rect.width / 2, rect.top + rect.height / 2);
            })()
            """
        } else {
            script = "window.__kakaPointerLeft()"
        }
        _ = try evaluate(webView, script)
        spin(0.05)
    }

    private static func beginHoverAction(
        _ webView: WKWebView,
        actionState: String,
        waveSnapshot: URL? = nil
    ) throws -> SpriteStyle {
        try hover(webView, inside: true)
        var style = try readStyle(webView)
        try require(
            style.state == actionState && style.actionTrigger == "hover" && style.actionPhase == "wave",
            "hover 没有先进入挥手阶段"
        )
        try require(style.frameDuration == "160", "挥手开场节奏不正确")
        try require(style.backgroundPosition.hasPrefix("0px -364"), "hover 开场没有使用挥手行")
        if let waveSnapshot {
            try advance(webView)
            try advance(webView)
            try snapshot(webView, to: waveSnapshot)
        }

        for _ in 0..<10 {
            try advance(webView)
            style = try readStyle(webView)
            if style.actionPhase == "state-action" { return style }
        }
        throw QAError.failed("挥手结束后没有衔接 \(actionState)")
    }

    private static func readStyle(_ webView: WKWebView) throws -> SpriteStyle {
        let script = """
        (() => {
          const sprite = document.getElementById('sprite');
          const style = getComputedStyle(sprite);
          const card = getComputedStyle(document.querySelector('.usage-card'));
          const bar = getComputedStyle(document.getElementById('weekBar'));
          const fill = getComputedStyle(document.getElementById('barFill'));
          return JSON.stringify({
            display: style.display,
            width: style.width,
            transform: style.transform,
            animationName: style.animationName,
            backgroundPosition: style.backgroundPosition,
            state: sprite.dataset.avatarState || '',
            actionTrigger: sprite.dataset.actionTrigger || '',
            actionPhase: sprite.dataset.actionPhase || '',
            frameDuration: sprite.dataset.frameDuration || '',
            lyingDisplay: getComputedStyle(document.querySelector('.lying-sprite')).display,
            cardWidth: card.width,
            cardBackgroundColor: card.backgroundColor,
            barWidth: bar.width,
            barHeight: bar.height,
            barBorderTopWidth: bar.borderTopWidth,
            barBackgroundColor: bar.backgroundColor,
            fillBackgroundImage: fill.backgroundImage,
            percentText: document.getElementById('percent').textContent || '',
            tokenText: document.getElementById('dailyTokens').textContent || '',
            weekValue: document.getElementById('weekBar').getAttribute('aria-valuenow') || '',
            wLabelCount: Array.from(document.querySelectorAll('span')).filter(node => node.textContent.trim() === 'W').length,
            buttonCount: document.querySelectorAll('button').length,
            todayLineText: document.getElementById('todayLine').innerText.replace(/\\s+/g, ' ').trim(),
            todayLabelColor: getComputedStyle(document.querySelector('.today-label')).color
          });
        })()
        """
        guard let json = try evaluate(webView, script) as? String,
              let data = json.data(using: .utf8) else {
            throw QAError.failed("无法读取人物动画样式")
        }
        return try JSONDecoder().decode(SpriteStyle.self, from: data)
    }

    private static func advance(_ webView: WKWebView) throws {
        _ = try evaluate(webView, "animate(nextFrameAt + 1, false)")
        spin(0.03)
    }

    private static func waitForState(_ webView: WKWebView, state: String) throws {
        for _ in 0..<24 {
            if try readStyle(webView).state == state { return }
            try advance(webView)
        }
        throw QAError.failed("一次性动作没有自动恢复到 \(state)")
    }

    private static func snapshot(_ webView: WKWebView, to url: URL) throws {
        // Freeze the selected frame so transparent WebKit layers cannot be captured mid-swap.
        _ = try evaluate(
            webView,
            "window.__qaAnimation = animation; window.__qaFrameIndex = frameIndex; animation = null"
        )
        spin(0.45)

        let config = WKSnapshotConfiguration()
        config.rect = NSRect(x: 0, y: 0, width: 244, height: 260)

        var result: Result<NSImage, Error>?
        webView.takeSnapshot(with: config) { image, error in
            if let image {
                result = .success(image)
            } else {
                result = .failure(error ?? QAError.failed("截图失败"))
            }
        }
        while result == nil { spin(0.01) }
        let image = try result!.get()
        guard let representation = image.tiffRepresentation.flatMap(NSBitmapImageRep.init),
              let png = representation.representation(using: .png, properties: [:]) else {
            throw QAError.failed("无法写入 QA 截图")
        }
        try png.write(to: url)
        _ = try evaluate(
            webView,
            "animation = window.__qaAnimation; frameIndex = window.__qaFrameIndex; drawFrame(); nextFrameAt = performance.now() + animation.frames[frameIndex].duration"
        )
    }

    private static func evaluate(_ webView: WKWebView, _ script: String) throws -> Any? {
        var result: Result<Any?, Error>?
        webView.evaluateJavaScript(script) { value, error in
            if let error {
                result = .failure(error)
            } else {
                result = .success(value)
            }
        }
        while result == nil { spin(0.01) }
        return try result!.get()
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw QAError.failed(message) }
    }

    private static func spin(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }
}
