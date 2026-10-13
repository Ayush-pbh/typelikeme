import AppKit
import SwiftUI

/// Raycast/Linear-style dark system: layered greys, 1 px borders, 13 pt type, red as the only signal.
enum Theme {
    static let canvas = Color(hex: 0x0F0F11)
    static let sidebar = Color(hex: 0x131315)
    static let panel = Color(hex: 0x17171A)
    static let raised = Color(hex: 0x1E1E22)
    static let hover = Color(hex: 0x222226)
    static let border = Color(hex: 0x26262B)
    static let borderStrong = Color(hex: 0x323238)
    static let text = Color(hex: 0xEDEDEF)
    static let secondary = Color(hex: 0xA1A1AA)
    static let tertiary = Color(hex: 0x6E6E78)
    static let accent = Color(hex: 0xFF6363)
    static let green = Color(hex: 0x59D499)
    static let yellow = Color(hex: 0xF5C451)

    static let radius: CGFloat = 10
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) { self.init(nsColor: NSColor(hex: hex)) }
}

/// Bordered surface used for every grouped block.
struct Panel<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.border))
    }
}

struct Divider1: View {
    var body: some View { Rectangle().fill(Theme.border).frame(height: 1) }
}

struct KeyCap: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 5).frame(minWidth: 20, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Theme.raised))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Theme.borderStrong))
    }
}

/// Primary action: raised surface with a hairline, like Raycast's action buttons.
struct ActionButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(prominent ? Color.white : Theme.text)
            .padding(.horizontal, 10).frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(prominent ? Theme.accent.opacity(configuration.isPressed ? 0.8 : 1)
                                : (configuration.isPressed ? Theme.hover : Theme.raised)))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(prominent ? Color.clear : Theme.borderStrong))
            .opacity(enabled ? 1 : 0.4)
    }
}

/// App icon: voice bars that end in a red block text cursor — your voice becoming typed text.
struct AppIconArt: View {
    var body: some View {
        ZStack {
            IconTile()
            VoiceCursorMark(unit: 1)
                .scaleEffect(0.9)
        }
        .frame(width: 824, height: 824)
        .shadow(color: .black.opacity(0.35), radius: 20, y: 12)
        .frame(width: 1024, height: 1024)
    }
}

/// macOS squircle: near-black with a faint top light and a hairline highlight.
private struct IconTile: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 185, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(hex: 0x1D1D22), Color(hex: 0x0B0B0D)], startPoint: .top, endPoint: .bottom))
            .overlay(shape.fill(RadialGradient(colors: [Color.white.opacity(0.07), .clear], center: .top, startRadius: 0, endRadius: 620)))
            .overlay(shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
                                                       startPoint: .top, endPoint: .bottom), lineWidth: 4))
    }
}

/// The mark itself, drawn at 824 pt per `unit`: four rounded bars rising and falling into the cursor.
struct VoiceCursorMark: View {
    var unit: CGFloat
    var body: some View {
        HStack(alignment: .center, spacing: 44 * unit) {
            ForEach(Array([0.20, 0.40, 0.58, 0.32].enumerated()), id: \.offset) { _, h in
                Capsule().fill(LinearGradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xDCDDE2)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 68 * unit, height: 824 * h * unit)
            }
            RoundedRectangle(cornerRadius: 12 * unit, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF7373), Color(hex: 0xE8454A)], startPoint: .top, endPoint: .bottom))
                .frame(width: 62 * unit, height: 824 * 0.68 * unit)
                .padding(.leading, 28 * unit)
        }
        .offset(x: -6 * unit)
    }
}

/// Menu-bar version of the mark: monochrome template image, so macOS tints it for light/dark bars.
enum MenuBarIcon {
    static func image(active: Bool = false) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { rect in
            NSColor.black.setFill()
            let bars: [CGFloat] = [0.30, 0.56, 0.80, 0.46]
            var x: CGFloat = 1.5
            for h in bars {
                let height = rect.height * h
                NSBezierPath(roundedRect: NSRect(x: x, y: (rect.height - height) / 2, width: 2, height: height), xRadius: 1, yRadius: 1).fill()
                x += 3.2
            }
            let cursorH = rect.height * 0.94
            NSBezierPath(roundedRect: NSRect(x: x + 0.8, y: (rect.height - cursorH) / 2, width: 2.4, height: cursorH),
                         xRadius: 0.6, yRadius: 0.6).fill()
            return true
        }
        img.isTemplate = !active
        return img
    }
}
