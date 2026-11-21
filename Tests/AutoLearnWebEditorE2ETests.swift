import AppKit
import Foundation
import WebKit

// The standalone harness only needs this policy dependency from AutoLearnTypes.
enum AIProvider: String { case voiceInkRefine; var supportsEnhancement: Bool { true }; var defaultModel: String { "test" } }

/// End-to-end check of Auto Learn against real WebKit editors.
///
/// The test binary relaunches itself as a fixture app that shows a WKWebView
/// editor, the same engine Muse uses. The parent then runs the production
/// Accessibility capture, edits the field like a user would, and checks that
/// the correction reaches the candidate stage. WebKit or macOS changes that
/// break capture fail here before users see the manual-registration notice.
@main
struct AutoLearnWebEditorE2ETests {
    static func main() {
        if CommandLine.arguments.contains("--fixture") {
            MainActor.assumeIsolated { FixtureApp.run() }
            return
        }
        Task {
            await Harness().run()
            exit(0)
        }
        dispatchMain()
    }
}

// MARK: - Fixture app (child process)

@MainActor
final class FixtureApp: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    private static var retained: FixtureApp?
    private var window: NSWindow!
    private var webView: WKWebView!

    static func run() {
        let app = NSApplication.shared
        let delegate = FixtureApp()
        retained = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        webView.navigationDelegate = self
        window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 640, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "VoiceInk Auto Learn E2E"
        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        webView.loadHTMLString(Self.page, baseURL: nil)
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.reply("loaded")
            Thread.detachNewThread { [weak self] in
                while let line = readLine() {
                    DispatchQueue.main.async { self?.handle(line) }
                }
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        }
    }

    private func handle(_ line: String) {
        guard let data = line.data(using: .utf8),
            let command = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return reply("error bad-command") }
        // Editors only report focus while the app is active and the window is key.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(webView)
        webView.callAsyncJavaScript(
            "return fixture.run(command)", arguments: ["command": command], in: nil, in: .page
        ) { [weak self] result in
            switch result {
            case .success(let value): self?.reply("ok \(value as? String ?? "")")
            case .failure(let error): self?.reply("error \(error.localizedDescription)")
            }
        }
    }

    private func reply(_ message: String) {
        print(message.replacingOccurrences(of: "\n", with: "\\n"))
        fflush(stdout)
    }

    /// Common WebKit editor shapes. Muse 13.1's focus-proxy quirk is not
    /// reproducible with plain HTML; AutoLearnWebFocusTests covers it instead.
    private static let page = """
    <!doctype html><html><head><meta charset="utf-8"></head><body>
    <div id="root"></div>
    <script>
    const shapes = {
      "textarea": '<textarea id="editor" rows="6" cols="60"></textarea>',
      "contenteditable": '<div id="editor" contenteditable="true" style="min-height:80px;border:1px solid #888"></div>',
      "deep-nested": '<div role="group"><div role="group"><div role="group"><div role="group">' +
        '<div role="group"><div role="group"><div role="group"><div role="button" tabindex="-1">' +
        '<div id="editor" contenteditable="true" role="textbox" aria-multiline="true" ' +
        'style="min-height:80px;border:1px solid #888"></div>' +
        '</div></div></div></div></div></div></div></div>'
    };
    const editor = () => document.getElementById("editor");
    const value = () => { const e = editor(); return e.tagName === "TEXTAREA" ? e.value : e.innerText; };
    function placeCaretAtEnd(e) {
      if (e.tagName === "TEXTAREA") { e.setSelectionRange(e.value.length, e.value.length); return; }
      const range = document.createRange(); range.selectNodeContents(e); range.collapse(false);
      const s = getSelection(); s.removeAllRanges(); s.addRange(range);
    }
    function select(e, text) {
      if (e.tagName === "TEXTAREA") {
        const i = e.value.indexOf(text); if (i < 0) throw new Error("missing " + text);
        e.setSelectionRange(i, i + text.length); return;
      }
      const walker = document.createTreeWalker(e, NodeFilter.SHOW_TEXT);
      for (let n = walker.nextNode(); n; n = walker.nextNode()) {
        const i = n.data.indexOf(text);
        if (i >= 0) {
          const range = document.createRange(); range.setStart(n, i); range.setEnd(n, i + text.length);
          const s = getSelection(); s.removeAllRanges(); s.addRange(range); return;
        }
      }
      throw new Error("missing " + text);
    }
    window.fixture = { run(c) {
      if (c.op === "setup") {
        document.getElementById("root").innerHTML = shapes[c.shape];
        if (c.prefix) {
          const e = editor();
          if (e.tagName === "TEXTAREA") e.value = c.prefix; else e.innerText = c.prefix;
        }
        editor().focus(); placeCaretAtEnd(editor()); return value();
      }
      editor().focus();
      // insertText goes through the editor's normal input path, like a paste.
      if (c.op === "insert") { placeCaretAtEnd(editor()); document.execCommand("insertText", false, c.text); return value(); }
      if (c.op === "replace") { select(editor(), c.from); document.execCommand("insertText", false, c.to); return value(); }
      if (c.op === "value") return value();
      throw new Error("unknown op " + c.op);
    } };
    </script></body></html>
    """
}

// MARK: - Harness (parent process)

final class Harness {
    private struct Scenario {
        let shape: String
        let prefix: String
        let pasted: String
        let from: String
        let to: String
    }

    private let scenarios = [
        Scenario(shape: "textarea", prefix: "", pasted: "明日はギットハブで確認します。", from: "ギットハブ", to: "GitHub"),
        Scenario(shape: "contenteditable", prefix: "", pasted: "明日はギットハブで確認します。", from: "ギットハブ", to: "GitHub"),
        Scenario(shape: "contenteditable", prefix: "メモ: ", pasted: "ディープシークを使って実行します。", from: "ディープシーク", to: "DeepSeek"),
        Scenario(shape: "deep-nested", prefix: "", pasted: "明日はギットハブで確認します。", from: "ギットハブ", to: "GitHub"),
    ]

    private var process: Process!
    private var input: FileHandle!
    private var lines: AsyncLineReader!

    func run() async {
        guard AXIsProcessTrusted() else {
            print("SKIP Accessibility permission is required for the terminal running this test")
            exit(0)
        }
        do { try launchFixture() } catch { fail("fixture launch failed: \(error)") }
        defer { process.terminate() }
        guard let loaded = await lines.next(timeout: 20), loaded == "loaded" else { fail("fixture did not load") }

        var failures: [String] = []
        for scenario in scenarios {
            let label = "\(scenario.shape)\(scenario.prefix.isEmpty ? "" : "+prefix")"
            if let failure = await check(scenario) {
                print("FAIL \(label): \(failure)")
                failures.append(label)
            } else {
                print("PASS \(label): paste is observed and \(scenario.from) -> \(scenario.to) reaches review")
            }
        }
        process.terminate()
        guard failures.isEmpty else {
            print("FAIL \(failures.count) of \(scenarios.count) web editor scenario(s)")
            exit(1)
        }
    }

    private func check(_ scenario: Scenario) async -> String? {
        guard await send(["op": "setup", "shape": scenario.shape, "prefix": scenario.prefix]) != nil
        else { return "setup failed" }
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard await send(["op": "insert", "text": scenario.pasted]) != nil else { return "insert failed" }

        // Production waits ~120 ms and retries for about one second; give the
        // fixture the same budget so the test reflects what users get.
        let runtime = AutoLearnAXRuntime()
        var outcome = AutoLearnCaptureOutcome.rejected("not-attempted")
        for delay: UInt64 in [120_000_000, 150_000_000, 300_000_000, 550_000_000] {
            try? await Task.sleep(nanoseconds: delay)
            outcome = await runtime.capturePastedText(text: scenario.pasted, processID: process.processIdentifier)
            if case .armed = outcome { break }
        }
        guard case .armed(let token) = outcome else {
            if case .rejected(let reason) = outcome { return "capture rejected reason=\(reason)" }
            return "capture failed"
        }

        guard await send(["op": "replace", "from": scenario.from, "to": scenario.to]) != nil
        else { return "user correction failed" }
        try? await Task.sleep(nanoseconds: 200_000_000)
        await runtime.refreshSnapshot(token: token)

        switch await runtime.finishSnapshot(token: token) {
        case .skipped(let reason):
            return "snapshot skipped reason=\(reason)"
        case .snapshot(let snapshot):
            guard let revision = FinalSnapshotDiffEngine.revision(from: snapshot) else {
                return "no revision from baseline=\(snapshot.baselineFieldText.debugDescription) final=\(snapshot.finalFieldText.debugDescription)"
            }
            let candidates = CorrectionDiffEngine.candidates(from: revision, usesAIReviewer: true)
            guard candidates.contains(where: {
                $0.originalText.contains(scenario.from) && $0.correctedText.contains(scenario.to)
            }) else {
                return "candidate missing; revision=\(revision.original.debugDescription) -> \(revision.corrected.debugDescription)"
            }
            return nil
        }
    }

    private func send(_ command: [String: String]) async -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: command) else { return nil }
        input.write(data + Data("\n".utf8))
        guard let reply = await lines.next(timeout: 10), reply.hasPrefix("ok") else { return nil }
        return reply
    }

    private func launchFixture() throws {
        process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        process.arguments = ["--fixture"]
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        input = stdinPipe.fileHandleForWriting
        lines = AsyncLineReader(stdoutPipe.fileHandleForReading)
        try process.run()
    }

    private func fail(_ message: String) -> Never {
        print("FAIL \(message)")
        process?.terminate()
        exit(1)
    }
}

/// Reads newline-delimited replies from the fixture with a timeout.
final class AsyncLineReader: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var pending: [String] = []

    init(_ handle: FileHandle) {
        handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard let self, !chunk.isEmpty else { return }
            self.lock.lock()
            self.buffer.append(chunk)
            while let newline = self.buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: self.buffer[..<newline], as: UTF8.self)
                self.buffer.removeSubrange(...newline)
                self.pending.append(line)
            }
            self.lock.unlock()
        }
    }

    func next(timeout: TimeInterval) async -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let line = popLine() { return line }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return nil
    }

    private func popLine() -> String? {
        lock.withLock { pending.isEmpty ? nil : pending.removeFirst() }
    }
}
