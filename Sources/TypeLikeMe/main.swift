import AppKit
import Combine
import SwiftUI

// CLI formatting check: `TypeLikeMe --format "raw text" [before-cursor] [app] [bundle-id]`.
if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--format" {
    SelfTest.format(Array(CommandLine.arguments.dropFirst(2)))
}

// Resource check: `TypeLikeMe --parakeet-bench file.wav N` loads Parakeet and transcribes N times.
if CommandLine.arguments.count >= 4, CommandLine.arguments[1] == "--parakeet-bench" {
    let path = CommandLine.arguments[2], n = Int(CommandLine.arguments[3]) ?? 10
    Task.detached {
        let data = try! Data(contentsOf: URL(fileURLWithPath: path)).dropFirst(44)
        let samples: [Int16] = data.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
        let t0 = Date(); try! await ParakeetEngine.shared.prepare()
        print("load: \(Int(Date().timeIntervalSince(t0) * 1000)) ms")
        let t1 = Date()
        for _ in 0..<n { _ = try! await ParakeetEngine.shared.transcribe(samples) }
        print("\(n) transcriptions: \(Int(Date().timeIntervalSince(t1) * 1000)) ms total")
        exit(0)
    }
    while true { RunLoop.main.run() }
}

// CLI self-test: `TypeLikeMe --selftest file.wav` runs the Sarvam pipeline headlessly.
if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--selftest" {
    SelfTest.run(path: CommandLine.arguments[2])
}

// Build helper: `TypeLikeMe --render-icon out.png` renders the app icon at 1024 px.
if CommandLine.arguments.count >= 3, CommandLine.arguments[1] == "--render-icon" {
    MainActor.assumeIsolated {
        let r = ImageRenderer(content: AppIconArt().frame(width: 1024, height: 1024))
        r.scale = 1
        if let img = r.nsImage, let tiff = img.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        }
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let controller = DictationController()
    private var statusItem: NSStatusItem!
    private var pill: PillPanel!
    private let flight = FlightPanel()
    private var copyCard: CopyCardPanel!
    private var dashboard: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ note: Notification) {
        pill = PillPanel(controller: controller)
        pill.orderFrontRegardless()
        copyCard = CopyCardPanel(controller: controller)
        controller.$unplaced.sink { [weak self] text in
            guard let self else { return }
            if text != nil {
                self.copyCard.place(above: self.pill.frame)
                self.copyCard.orderFrontRegardless()
            } else {
                // Let the fade-out play before hiding the window.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if self.controller.unplaced == nil { self.copyCard.orderOut(nil) }
                }
            }
        }.store(in: &cancellables)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.image()
        buildMenu()

        controller.$phase.sink { [weak self] p in
            guard let self else { return }
            if p == .listening { self.pill.reposition(avoiding: self.controller.caretRect) }
            if p == .idle { self.pill.reposition() }
            // The mark tints red while you're dictating, template (auto light/dark) otherwise.
            let active = p == .listening || p == .processing
            let img = MenuBarIcon.image(active: active)
            self.statusItem.button?.image = img
            self.statusItem.button?.contentTintColor = active ? NSColor(hex: 0xFF6363) : nil
        }.store(in: &cancellables)

        controller.onDeliver = { [weak self] ctx in
            guard let self, AppSettings.shared.particles,
                  !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return 0 }
            // The words form in the pill first; the paste lands as they dissolve toward the cursor.
            let lead = PixelTiming.lead
            guard let caret = ctx.caret else { return lead }
            let f = self.pill.frame
            let from = CGPoint(x: f.midX,
                               y: f.minY + PillView.bottomInset + PillView.hud.height / 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + lead) { self.flight.launch(from: from, to: caret) }
            return lead + 0.22
        }
        // `TYPELIKEME_PILL_DEMO=1`: loop the bar's animation with a sample transcript, raised above
        // the real bar. No mic, no hotkey, nothing is pasted — for checking visuals safely.
        if let demo = ProcessInfo.processInfo.environment["TYPELIKEME_PILL_DEMO"] {
            pill.lift = 160
            pill.reposition()
            if ProcessInfo.processInfo.environment["TYPELIKEME_CARD_DEMO"] != nil {
                copyCard.setFrameOrigin(NSPoint(x: pill.frame.midX - CopyCardPanel.size.width / 2, y: pill.frame.minY + 200))
                let card = ProcessInfo.processInfo.environment["TYPELIKEME_CARD_DEMO"] ?? ""
                controller.keepUnplacedPreview("Let's move the design review to Thursday at 4 and loop in Priya on the pricing slide.",
                                               pastedInto: card == "note" ? "Zed" : nil)
                return
            }
            controller.runPillDemo(text: demo.count > 3 ? demo : "The new pixel bar is thin, sharp, and it types my words.")
            return
        }
        // Preview copies (sample data) never listen to the fn key, so they can't double up with the real app.
        if ProcessInfo.processInfo.environment["TYPELIKEME_DEMO"] == nil { controller.start() }
        // Keep Parakeet loaded whenever it's the speech engine, so dictations never wait for it.
        AppSettings.shared.$transcriber.sink { value in
            if value == "parakeet" { Task { try? await ParakeetEngine.shared.prepare() } }
        }.store(in: &cancellables)
        // Using fn for dictation means macOS must not also open emoji on it.
        if AppSettings.shared.trigger == .fn { FnUsage.setDoNothing(force: false) }
        if !AudioRecorder.hasPermission { AudioRecorder.requestPermission { _ in } }

        // First launch (or missing permissions): show the dashboard so onboarding is visible.
        let s = AppSettings.shared
        let ready = TextInserter.isTrusted && AudioRecorder.hasPermission && !s.apiKey.isEmpty
        if ready { s.onboarded = true }
        if !s.onboarded || !TextInserter.isTrusted || ProcessInfo.processInfo.environment["TYPELIKEME_DEMO"] != nil {
            showDashboard()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Dashboard", action: #selector(openDashboard), keyEquivalent: "d").target = self
        menu.addItem(withTitle: "Start Hands-free Dictation", action: #selector(toggle), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let again = menu.addItem(withTitle: "Paste Last Dictation", action: #selector(pasteLast), keyEquivalent: "v")
        again.keyEquivalentModifierMask = [.command, .control]
        again.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit TypeLikeMe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func openDashboard() { showDashboard() }
    @objc private func toggle() { controller.toggleHandsFree() }
    @objc private func pasteLast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.controller.pasteLast() }
    }

    func showDashboard() {
        if dashboard == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1060, height: 760),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                             backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.backgroundColor = NSColor(hex: 0x0F0F11)
            w.appearance = NSAppearance(named: .darkAqua)
            w.minSize = NSSize(width: 860, height: 600)
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            w.setFrameAutosaveName("TypeLikeMeDashboard")
            dashboard = w
        }
        if dashboard?.contentView is NSHostingView<DashboardView> == false {
            dashboard?.contentView = NSHostingView(rootView: DashboardView(controller: controller))
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        dashboard?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Tear down the SwiftUI tree so its animations/timers stop costing CPU while hidden.
        DispatchQueue.main.async { self.dashboard?.contentView = NSView() }
        // Back to a pure menu-bar utility: no Dock icon, minimal footprint.
        NSApp.setActivationPolicy(.accessory)
    }
}

enum SelfTest {
    static func run(path: String) -> Never {
        let sem = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                let url = URL(fileURLWithPath: path)
                let data = try Data(contentsOf: url)
                // Pull PCM16 samples out of a 16 kHz mono WAV (skip the 44-byte header).
                let pcm = data.dropFirst(44)
                let samples: [Int16] = pcm.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
                let key = AppSettings.loadAPIKey()
                print("key: \(key.isEmpty ? "MISSING" : "found (\(key.prefix(4))…)")")
                print("audio: \(String(format: "%.2f", Double(samples.count) / 16000)) s, chunks: \(WAV.chunks(samples).count), silent: \(WAV.isSilent(samples))")
                var client = SarvamClient(apiKey: key)
                // TLM_SPEECH=local transcribes with the local model (TLM_LOCAL_MODEL, default gemma4:e4b).
                let env = ProcessInfo.processInfo.environment
                if env["TLM_SPEECH"] == "parakeet" {
                    client.parakeet = true
                    let t = Date(); try await ParakeetEngine.shared.prepare()
                    print("parakeet load: \(ms(t))")
                }
                if env["TLM_SPEECH"] == "local" { client.localSpeech = (env["TLM_LOCAL_ENDPOINT"] ?? "http://localhost:11434", env["TLM_LOCAL_MODEL"] ?? "gemma4:e4b-it-qat") }
                if env["TLM_ENGINE"] == "local" { client.engine = .local(kind: .ollama, endpoint: env["TLM_LOCAL_ENDPOINT"] ?? "http://localhost:11434", model: env["TLM_LOCAL_MODEL"] ?? "gemma4:e4b-it-qat") }
                var t0 = Date()
                let t = try await client.transcribe(samples: samples, model: "saaras:v3", language: "unknown", mode: .transcribe)
                print("stt  [\(ms(t0))]: \(t.text)  (\(t.language))")
                t0 = Date()
                let p = try await client.polish(t.text, style: .clean, context: CursorContext(before: nil, appName: "Slack", bundleID: "com.tinyspeck.slackmacgap"), vocabulary: ["TypeLikeMe"])
                print("polish [\(ms(t0))]: \(p)")
                print("local fallback: \(Cleanup.local(t.text))")
                print("SELFTEST OK")
                exit(0)
            } catch {
                print("SELFTEST FAILED: \(error.localizedDescription)")
                exit(1)
            }
        }
        sem.wait()
        exit(0)
    }

    static func format(_ a: [String]) -> Never {
        Task.detached {
            let ctx = CursorContext(before: a.count > 1 && a[1] != "-" ? a[1] : nil, appName: a.count > 2 ? a[2] : "", bundleID: a.count > 3 ? a[3] : "")
            var client = SarvamClient(apiKey: AppSettings.loadAPIKey())
            // TLM_ENGINE=local tests the on-device model (TLM_LOCAL_MODEL / TLM_LOCAL_ENDPOINT override the defaults).
            let env = ProcessInfo.processInfo.environment
            if env["TLM_ENGINE"] == "local" {
                client.engine = .local(kind: .ollama, endpoint: env["TLM_LOCAL_ENDPOINT"] ?? "http://localhost:11434",
                                       model: env["TLM_LOCAL_MODEL"] ?? "gemma4:e4b-it-qat")
            }
            do {
                let t0 = Date()
                let p = SarvamClient.isAITool(ctx)
                    ? try await client.promptify(a[0], context: ctx, vocabulary: Store.shared.vocabulary)
                    : try await client.polish(a[0], style: .clean, context: ctx, vocabulary: Store.shared.vocabulary)
                let joined = SmartJoin.apply(QuestionFix.apply(p), before: ctx.before, adjustCase: false)
                print("[\(ms(t0))] \((ctx.before ?? "") + joined)")
            } catch { print("ERR \(error)") }
            exit(0)
        }
        while true { RunLoop.main.run() }
    }

    static func ms(_ d: Date) -> String { "\(Int(Date().timeIntervalSince(d) * 1000)) ms" }
}
