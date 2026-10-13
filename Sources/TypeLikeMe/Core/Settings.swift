import AppKit
import SwiftUI

enum TriggerKey: String, CaseIterable, Identifiable {
    case fn, rightOption, rightCommand, rightControl
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fn: return "fn / 🌐"
        case .rightOption: return "Right ⌥ Option"
        case .rightCommand: return "Right ⌘ Command"
        case .rightControl: return "Right ⌃ Control"
        }
    }
    var short: String {
        switch self {
        case .fn: return "fn"
        case .rightOption: return "right ⌥"
        case .rightCommand: return "right ⌘"
        case .rightControl: return "right ⌃"
        }
    }
    /// Virtual key code reported in flagsChanged events.
    var keyCode: UInt16 {
        switch self {
        case .fn: return 63
        case .rightOption: return 61
        case .rightCommand: return 54
        case .rightControl: return 62
        }
    }
    var flag: NSEvent.ModifierFlags {
        switch self {
        case .fn: return .function
        case .rightOption: return .option
        case .rightCommand: return .command
        case .rightControl: return .control
        }
    }
}

enum PolishStyle: String, CaseIterable, Identifiable {
    case off, clean, professional, casual
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: return "Raw"
        case .clean: return "Clean"
        case .professional: return "Formal"
        case .casual: return "Casual"
        }
    }
    var blurb: String {
        switch self {
        case .off: return "Exactly what was heard, with no clean-up."
        case .clean: return "Removes filler words and fixes punctuation. Keeps your wording."
        case .professional: return "Tightens wording for work messages and email."
        case .casual: return "Relaxed and lowercase, for chats with friends."
        }
    }
    var icon: String {
        switch self {
        case .off: return "waveform"
        case .clean: return "sparkles"
        case .professional: return "briefcase.fill"
        case .casual: return "bubble.left.and.bubble.right.fill"
        }
    }
}

enum OutputMode: String, CaseIterable, Identifiable {
    case transcribe, translate, codemix, translit
    var id: String { rawValue }
    var label: String {
        switch self {
        case .transcribe: return "Native script"
        case .translate: return "Translate to English"
        case .codemix: return "Code-mixed (Hinglish)"
        case .translit: return "Romanized"
        }
    }
}

struct Language: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
    static let all: [Language] = [
        .init(code: "unknown", name: "Auto-detect"),
        .init(code: "en-IN", name: "English"),
        .init(code: "hi-IN", name: "हिन्दी Hindi"),
        .init(code: "bn-IN", name: "বাংলা Bengali"),
        .init(code: "ta-IN", name: "தமிழ் Tamil"),
        .init(code: "te-IN", name: "తెలుగు Telugu"),
        .init(code: "kn-IN", name: "ಕನ್ನಡ Kannada"),
        .init(code: "ml-IN", name: "മലയാളം Malayalam"),
        .init(code: "mr-IN", name: "मराठी Marathi"),
        .init(code: "gu-IN", name: "ગુજરાતી Gujarati"),
        .init(code: "pa-IN", name: "ਪੰਜਾਬੀ Punjabi"),
        .init(code: "od-IN", name: "ଓଡ଼ିଆ Odia"),
    ]
    static func name(for code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }
}

/// Persistent user preferences. Everything but the API key lives in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private static let d = UserDefaults.standard

    @Published var trigger: TriggerKey = TriggerKey(rawValue: d.string(forKey: "trigger") ?? "") ?? .fn { didSet { Self.d.set(trigger.rawValue, forKey: "trigger") } }
    @Published var language: String = d.string(forKey: "language") ?? "unknown" { didSet { Self.d.set(language, forKey: "language") } }
    @Published var sttModel: String = d.string(forKey: "sttModel") ?? "saaras:v4" { didSet { Self.d.set(sttModel, forKey: "sttModel") } }
    @Published var outputMode: OutputMode = OutputMode(rawValue: d.string(forKey: "outputMode") ?? "") ?? .transcribe { didSet { Self.d.set(outputMode.rawValue, forKey: "outputMode") } }
    @Published var polish: PolishStyle = PolishStyle(rawValue: d.string(forKey: "polish") ?? "") ?? .clean { didSet { Self.d.set(polish.rawValue, forKey: "polish") } }
    @Published var contextAware: Bool = d.object(forKey: "contextAware") as? Bool ?? true { didSet { Self.d.set(contextAware, forKey: "contextAware") } }
    /// Where the dictation bar docks along the bottom edge: "left", "center" or "right".
    @Published var barAnchor: String = d.string(forKey: "barAnchor") ?? "center" { didSet { Self.d.set(barAnchor, forKey: "barAnchor") } }
    @Published var promptMode: Bool = d.object(forKey: "promptMode") as? Bool ?? true { didSet { Self.d.set(promptMode, forKey: "promptMode") } }
    @Published var smartFormat: Bool = d.object(forKey: "smartFormat") as? Bool ?? true { didSet { Self.d.set(smartFormat, forKey: "smartFormat") } }
    @Published var particles: Bool = d.object(forKey: "particles") as? Bool ?? true { didSet { Self.d.set(particles, forKey: "particles") } }
    @Published var sounds: Bool = d.object(forKey: "sounds") as? Bool ?? true { didSet { Self.d.set(sounds, forKey: "sounds") } }
    @Published var trailingSpace: Bool = d.object(forKey: "trailingSpace") as? Bool ?? true { didSet { Self.d.set(trailingSpace, forKey: "trailingSpace") } }
    @Published var onboarded: Bool = d.bool(forKey: "onboarded") { didSet { Self.d.set(onboarded, forKey: "onboarded") } }
    @Published var alwaysShowPill: Bool = d.object(forKey: "alwaysShowPill") as? Bool ?? true { didSet { Self.d.set(alwaysShowPill, forKey: "alwaysShowPill") } }

    @Published var apiKey: String = ""

    private init() {
        apiKey = Self.loadAPIKey()
    }

    static var supportDir: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TypeLikeMe", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static var configURL: URL { supportDir.appendingPathComponent("config.json") }

    /// Key lookup order: config file → SARVAM_API_KEY env → ./.env next to the working dir.
    static func loadAPIKey() -> String {
        if let data = try? Data(contentsOf: configURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let key = obj["sarvamApiKey"] as? String, !key.isEmpty {
            return key
        }
        if let env = ProcessInfo.processInfo.environment["SARVAM_API_KEY"], !env.isEmpty { return env }
        let dotenv = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env")
        if let text = try? String(contentsOf: dotenv) {
            for line in text.split(separator: "\n") where line.hasPrefix("SARVAM_API_KEY=") {
                return String(line.dropFirst("SARVAM_API_KEY=".count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"' \r"))
            }
        }
        return ""
    }

    func saveAPIKey(_ key: String) {
        apiKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let obj = ["sarvamApiKey": apiKey]
        let url = Self.configURL
        if let data = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted) {
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
}
