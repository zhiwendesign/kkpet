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

private struct UsageStyle: Decodable {
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
    let todayLineText: String
    let todayLabelColor: String
    let imageCount: Int
    let characterCount: Int
    let spriteCount: Int
    let resourceBackgroundCount: Int
    let buttonCount: Int
    let wLabelCount: Int
}

@main
struct KakaOverlayQA {
    private static let size = NSSize(width: 156, height: 48)

    static func main() throws {
        _ = NSApplication.shared

        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectRoot = [
            workingDirectory,
            workingDirectory.appendingPathComponent("usage-overlay", isDirectory: true)
        ].first(where: {
            FileManager.default.fileExists(
                atPath: $0.appendingPathComponent("Resources/index.html").path
            )
        }) ?? workingDirectory
        let resources = projectRoot.appendingPathComponent("Resources", isDirectory: true)
        let output = projectRoot.appendingPathComponent("qa/usage-overlay", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let webView = WKWebView(
            frame: NSRect(origin: .zero, size: size),
            configuration: WKWebViewConfiguration()
        )
        webView.setValue(false, forKey: "drawsBackground")

        let window = NSWindow(
            contentRect: NSRect(origin: NSPoint(x: 24, y: 80), size: size),
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
        _ = try evaluate(webView, "document.getElementById('barFill').style.transition = 'none'")
        _ = try evaluate(
            webView,
            "window.__kakaUpdate({remainingPercent:40,dailyTokens:1234567,dailyDate:'2026-07-22'})"
        )
        spin(0.05)

        let style = try readStyle(webView)
        try require(style.cardWidth == "132px", "用量区宽度不是 132 px")
        try require(style.cardBackgroundColor == "rgba(0, 0, 0, 0)", "用量区仍有卡片背景")
        try require(style.barWidth == "132px" && style.barHeight == "12px", "周进度条尺寸不正确")
        try require(style.barBorderTopWidth == "0px", "周进度条仍有黑色边框")
        try require(style.barBackgroundColor.contains("63, 140, 255"), "周进度条底轨不是浅蓝色")
        try require(style.fillBackgroundImage.contains("rgb(40, 120, 243)"), "周进度条没有使用蓝色")
        try require(style.percentText == "40%" && style.weekValue == "40", "周剩余百分比显示不正确")
        try require(style.tokenText == "1.23M", "Today Token 没有使用紧凑格式")
        try require(style.todayLineText == "Today: 1.23M", "第二行不是 Today: 今日用量")
        try require(style.todayLabelColor.contains("255, 212, 74"), "Today 标签没有使用黄色")
        try require(style.imageCount == 0, "伴随层仍包含图片元素")
        try require(style.characterCount == 0, "伴随层仍包含人物容器")
        try require(style.spriteCount == 0, "伴随层仍包含宠物精灵")
        try require(style.resourceBackgroundCount == 0, "伴随层仍加载宠物背景图片")
        try require(style.buttonCount == 0, "伴随层仍包含按钮")
        try require(style.wLabelCount == 0, "伴随层仍包含 W 标签")

        try snapshot(webView, to: output.appendingPathComponent("usage-only.png"))
        window.orderOut(nil)
        print("用量层 QA 通过：仅保留周额度进度条与 Today 用量，不含伴随宠物")
    }

    private static func waitUntilReady(_ webView: WKWebView) throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let ready = try? evaluate(webView, "typeof window.__kakaUpdate === 'function'"),
               (ready as? Bool) == true {
                return
            }
            spin(0.05)
        }
        throw QAError.failed("用量层在 10 秒内没有加载完成")
    }

    private static func readStyle(_ webView: WKWebView) throws -> UsageStyle {
        let script = """
        (() => {
          const card = getComputedStyle(document.querySelector('.usage-card'));
          const bar = getComputedStyle(document.getElementById('weekBar'));
          const fill = getComputedStyle(document.getElementById('barFill'));
          return JSON.stringify({
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
            todayLineText: document.getElementById('todayLine').innerText.replace(/\\s+/g, ' ').trim(),
            todayLabelColor: getComputedStyle(document.querySelector('.today-label')).color,
            imageCount: document.querySelectorAll('img').length,
            characterCount: document.querySelectorAll('#characterWrap, .character-wrap').length,
            spriteCount: document.querySelectorAll('#sprite, .sprite, .lying-sprite').length,
            resourceBackgroundCount: Array.from(document.querySelectorAll('*')).filter(node => getComputedStyle(node).backgroundImage.includes('url(')).length,
            buttonCount: document.querySelectorAll('button').length,
            wLabelCount: Array.from(document.querySelectorAll('span')).filter(node => node.textContent.trim() === 'W').length
          });
        })()
        """
        guard let json = try evaluate(webView, script) as? String,
              let data = json.data(using: .utf8) else {
            throw QAError.failed("无法读取用量层样式")
        }
        return try JSONDecoder().decode(UsageStyle.self, from: data)
    }

    private static func snapshot(_ webView: WKWebView, to url: URL) throws {
        spin(0.35)
        let configuration = WKSnapshotConfiguration()
        configuration.rect = NSRect(origin: .zero, size: size)

        var result: Result<NSImage, Error>?
        webView.takeSnapshot(with: configuration) { image, error in
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
