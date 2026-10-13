import AppKit
import CoreGraphics

/// System-wide listener for the trigger key.
///
/// Runs its event tap on a dedicated thread so it can never slow down typing. When fn is the
/// trigger it swallows the bare fn press/release, which is what stops macOS from also opening
/// the emoji picker or its own dictation (the same approach Wispr Flow uses). Every other key,
/// including fn+arrow and fn+F-key combos, passes through untouched.
final class HotkeyMonitor {
    enum Event {
        case triggerDown
        case triggerUp
        case controlPressed
        case escape
        case otherKey
        /// ⌃⌘V: paste the last dictation again (swallowed so apps don't also see it).
        case pasteLast
        /// Plain ⌘V typed by the user (passed through).
        case userPaste
    }

    /// Read from the tap thread; written from main. A plain enum store is fine for this use.
    var trigger: TriggerKey = .fn
    var onEvent: ((Event) -> Void)?
    private(set) var isRunning = false

    private var tap: CFMachPort?
    private var thread: Thread?
    private var triggerIsDown = false
    private var controlIsDown = false
    private var retryTimer: Timer?

    func start() {
        guard tap == nil else { return }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, ctx in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(ctx!).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            }, userInfo: me)
        else {
            // No Accessibility permission yet: retry quietly until it's granted.
            Log.write("event tap unavailable, retrying")
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in self?.start() }
            return
        }
        self.tap = tap
        let t = Thread { [tap] in
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        t.name = "TypeLikeMe.hotkeys"
        t.qualityOfService = .userInteractive
        t.start()
        thread = t
        isRunning = true
        Log.write("event tap running (fn suppression on)")
    }

    private func emit(_ e: Event) {
        DispatchQueue.main.async { self.onEvent?(e) }
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        case .flagsChanged:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            if code == trigger.keyCode {
                let down = flags.contains(cgFlag(trigger))
                if down != triggerIsDown {
                    triggerIsDown = down
                    emit(down ? .triggerDown : .triggerUp)
                }
                // Swallow the globe/fn key itself so macOS doesn't show emoji or start its own dictation.
                return trigger == .fn ? nil : pass
            }
            if code == 59 || code == 62 {
                let down = flags.contains(.maskControl)
                if down && !controlIsDown && triggerIsDown { emit(.controlPressed) }
                controlIsDown = down
            }
            return pass
        case .keyUp:
            // The 🌐 key sends its own key code alongside the fn flag; swallow it too (it's what opens emoji).
            if trigger == .fn, event.getIntegerValueField(.keyboardEventKeycode) == Self.globeKeyCode { return nil }
            return pass
        case .keyDown:
            if event.getIntegerValueField(.eventSourceUserData) == syntheticTag { return pass }
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if triggerIsDown { Log.write("key \(code) while trigger held") }
            // Part of pressing fn itself, not a second key: never treat it as a chord.
            if code == Self.globeKeyCode { return trigger == .fn ? nil : pass }
            let f = event.flags
            if code == 9, f.contains(.maskCommand) {
                if f.contains(.maskControl), !f.contains(.maskAlternate), !f.contains(.maskShift) {
                    emit(.pasteLast)
                    return nil
                }
                emit(.userPaste)
                return pass
            }
            emit(code == 53 ? .escape : .otherKey)
            return pass
        default:
            return pass
        }
    }

    /// Key code the 🌐/fn key reports on Apple keyboards.
    static let globeKeyCode: Int64 = 179

    private func cgFlag(_ t: TriggerKey) -> CGEventFlags {
        switch t {
        case .fn: return .maskSecondaryFn
        case .rightOption: return .maskAlternate
        case .rightCommand: return .maskCommand
        case .rightControl: return .maskControl
        }
    }
}
