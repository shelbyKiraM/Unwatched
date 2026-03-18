import SwiftUI
import Combine
import Foundation
import UnwatchedShared

private struct SubtitleFontSizeOption {
    let size: Double
    let increment: Int
    let label: String
}

private let subtitleFontSizeOptions: [SubtitleFontSizeOption] = [
    .init(size: 10, increment: -2, label: "50%"),
    .init(size: 12, increment: -1, label: "75%"),
    .init(size: 14, increment: 0, label: "100%"),
    .init(size: 18, increment: 2, label: "150%"),
    .init(size: 22, increment: 4, label: "200%"),
    .init(size: 30, increment: 8, label: "300%"),
    .init(size: 38, increment: 12, label: "400%")
]

final class SubtitleStyleSettingsStore: ObservableObject {
    static let customScriptKey = "SubtitleStyleCustomScript"

    @Published var fontFamily: Int {
        didSet { UserDefaults.standard.set(fontFamily, forKey: "SubtitleStyleFontFamily") }
    }
    @Published var fontSize: Double {
        didSet { UserDefaults.standard.set(fontSize, forKey: "SubtitleStyleFontSize") }
    }
    @Published var fontColor: Color {
        didSet { UserDefaults.standard.setColor(color: fontColor, forKey: "SubtitleStyleFontColor") }
    }
    @Published var textOpacity: Double {
        didSet { UserDefaults.standard.set(textOpacity, forKey: "SubtitleStyleTextOpacity") }
    }
    @Published var backgroundColor: Color {
        didSet { UserDefaults.standard.setColor(color: backgroundColor, forKey: "SubtitleStyleBackgroundColor") }
    }
    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: "SubtitleStyleBackgroundOpacity") }
    }
    @Published var windowColor: Color {
        didSet { UserDefaults.standard.setColor(color: windowColor, forKey: "SubtitleStyleWindowColor") }
    }
    @Published var windowOpacity: Double {
        didSet { UserDefaults.standard.set(windowOpacity, forKey: "SubtitleStyleWindowOpacity") }
    }
    @Published var charEdgeStyle: Int {
        didSet { UserDefaults.standard.set(charEdgeStyle, forKey: "SubtitleStyleCharEdgeStyle") }
    }
    @Published var customScript: String? {
        didSet {
            UserDefaults.standard.set(customScript, forKey: Self.customScriptKey)
        }
    }

    init() {
        let storedFontFamily = UserDefaults.standard.integer(forKey: "SubtitleStyleFontFamily")
        fontFamily = (
            storedFontFamily == 0
                && UserDefaults.standard.object(forKey: "SubtitleStyleFontFamily") == nil
        ) ? 3 : storedFontFamily // default 3

        let storedSize = UserDefaults.standard.double(forKey: "SubtitleStyleFontSize")
        let defaultFontSize = 18.0
        let resolvedFontSize = storedSize == 0 ? defaultFontSize : storedSize
        fontSize = SubtitleStyleSettingsStore.closestFontSize(to: resolvedFontSize)

        fontColor = UserDefaults.standard.colorForKey(key: "SubtitleStyleFontColor") ?? .white

        let storedTextOpacity = UserDefaults.standard.object(forKey: "SubtitleStyleTextOpacity") as? Double
        textOpacity = storedTextOpacity ?? 1.0

        backgroundColor = UserDefaults.standard.colorForKey(key: "SubtitleStyleBackgroundColor") ?? .black

        let storedBackgroundOpacity = UserDefaults.standard.object(forKey: "SubtitleStyleBackgroundOpacity") as? Double
        backgroundOpacity = storedBackgroundOpacity ?? 1.0

        windowColor = UserDefaults.standard.colorForKey(key: "SubtitleStyleWindowColor") ?? .black

        let storedWindowOpacity = UserDefaults.standard.object(forKey: "SubtitleStyleWindowOpacity") as? Double
        windowOpacity = storedWindowOpacity ?? 0.0

        let storedCharEdgeStyle = UserDefaults.standard.integer(forKey: "SubtitleStyleCharEdgeStyle")
        charEdgeStyle = (
            storedCharEdgeStyle == 0
                && UserDefaults.standard.object(forKey: "SubtitleStyleCharEdgeStyle") == nil
        ) ? 0 : storedCharEdgeStyle

        customScript = UserDefaults.standard.string(forKey: Self.customScriptKey)
    }

    var generatedScript: String {
        let fontSizeIncrement = SubtitleStyleSettingsStore.fontSizeIncrement(for: fontSize)
        let fontFamily = javaScriptFontFamily
        let colorString = fontColor.toHexString()
        let backgroundString = backgroundColor.toHexString()
        let windowColorString = windowColor.toHexString()
        let generatedCSS = generatedCaptionCSS

        return """
        (function() {
          const settings = {
            fontFamily: \(fontFamily),
            fontSizeIncrement: \(fontSizeIncrement),
            color: "\(colorString)",
            fontOpacity: \(textOpacity),
            background: "\(backgroundString)",
            backgroundOpacity: \(backgroundOpacity),
            windowColor: "\(windowColorString)",
            windowOpacity: \(windowOpacity),
            charEdgeStyle: \(charEdgeStyle)
          };
          localStorage.setItem('yt-player-caption-display-settings', JSON.stringify({
            data: JSON.stringify({
              ...settings
            }),
            expiration: Date.now() + 30 * 24 * 60 * 60 * 1000,
            creation: Date.now()
          }));
          if (typeof window.upsertUnwatchedStyle === 'function') {
            window.upsertUnwatchedStyle('unwatched-generated-caption-style', \(generatedCSS.jsTemplateLiteral()));
          }
        })();
        """
    }

    var generatedCaptionCSS: String {
        let textColor = Self.cssColorString(fontColor, opacity: textOpacity)
        let background = Self.cssColorString(backgroundColor, opacity: backgroundOpacity)
        let window = Self.cssColorString(windowColor, opacity: windowOpacity)
        let fontScale = Self.fontSizeScale(for: fontSize)
        let textShadow = Self.charEdgeStyleShadow(for: charEdgeStyle)
        let fontVariantCSS = cssFontVariantRules

        return """
        .html5-video-player .caption-visual-line,
        body ytd-app[fullscreen] .caption-window .caption-visual-line {
            font-size: calc(100% * \(fontScale)) !important;
        }

        .html5-video-player .caption-visual-line .ytp-caption-segment,
        body ytd-app[fullscreen] .caption-window .ytp-caption-segment {
            font-family: \(cssFontFamily) !important;
            font-size: inherit !important;
            color: \(textColor) !important;
            opacity: 1 !important;
            background-color: \(background) !important;
            text-shadow: \(textShadow) !important;
            \(fontVariantCSS)
        }

        .html5-video-player .caption-window,
        body ytd-app[fullscreen] .caption-window {
            background-color: \(window) !important;
        }
        """
    }

    var cssFontFamily: String {
        switch fontFamily {
        case 0:
            return "\"Courier New\", Courier, \"Nimbus Mono L\", \"Cutive Mono\", monospace"
        case 1:
            return "\"Times New Roman\", Times, Georgia, Cambria, \"PT Serif Caption\", serif"
        case 2:
            return "\"Deja Vu Sans Mono\", \"Lucida Console\", Monaco, Consolas, \"PT Mono\", monospace"
        case 3:
            return "\"YouTube Noto\", Roboto, Arial, Helvetica, Verdana, \"PT Sans Caption\", sans-serif"
        case 4:
            return "\"Comic Sans MS\", Impact, Handlee, fantasy"
        case 5:
            return "\"Monotype Corsiva\", \"URW Chancery L\", \"Apple Chancery\", \"Dancing Script\", cursive"
        case 6:
            return "Arial, Helvetica, Verdana, \"Marcellus SC\", sans-serif"
        case 7:
            return "\"American Typewriter\", \"Courier New\", serif"
        default:
            return "-apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif"
        }
    }

    var cssFontVariantRules: String {
        guard fontFamily == 6 else {
            return """
            font-variant-ligatures: normal !important;
            font-variant-caps: normal !important;
            font-variant-alternates: normal !important;
            font-variant-numeric: normal !important;
            font-variant-east-asian: normal !important;
            font-variant-position: normal !important;
            """
        }
        return """
        font-variant-ligatures: normal !important;
        font-variant-caps: small-caps !important;
        font-variant-alternates: normal !important;
        font-variant-numeric: normal !important;
        font-variant-east-asian: normal !important;
        font-variant-position: normal !important;
        """
    }

    var javaScriptFontFamily: Int {
        switch fontFamily {
        case 7:
            return 1
        default:
            return fontFamily
        }
    }

    var activePlayerScript: String {
        if let customScript, !customScript.isEmpty {
            let sanitizedScript = Self.sanitizeLegacyReload(in: customScript)
            return Self.runtimeScript(for: sanitizedScript)
        }
        return generatedScript
    }

    static func playerScript(userDefaults: UserDefaults = .standard) -> String {
        let customScript = userDefaults.string(forKey: customScriptKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let customScript, !customScript.isEmpty {
            let sanitizedScript = sanitizeLegacyReload(in: customScript)
            if sanitizedScript != customScript {
                userDefaults.set(sanitizedScript, forKey: customScriptKey)
            }
            return runtimeScript(for: sanitizedScript)
        }
        return SubtitleStyleSettingsStore().generatedScript
    }

    private static func runtimeScript(for script: String) -> String {
        if looksLikeCSS(script) {
            return cssInjectionScript(css: script)
        }
        return """
        (function() {
          window.injectUnwatchedCSS = function(cssText, styleId = 'unwatched-custom-caption-style') {
            if (!cssText) {
              return;
            }
            if (typeof window.upsertUnwatchedStyle === 'function') {
              window.upsertUnwatchedStyle(styleId, cssText);
              return;
            }
            let style = document.getElementById(styleId);
            if (!style) {
              style = document.createElement('style');
              style.id = styleId;
              document.head.appendChild(style);
            }
            style.textContent = cssText;
          };
        })();
        \(script)
        """
    }

    private static func looksLikeCSS(_ script: String) -> Bool {
        let lowered = script.lowercased()
        let javaScriptMarkers = [
            "function",
            "=>",
            "const ",
            "let ",
            "var ",
            "localstorage",
            "window.",
            "document.",
            "queryselector",
            "appendchild",
            "settimeout",
            "addeventlistener",
            "json."
        ]
        guard script.contains("{"), script.contains("}") else {
            return false
        }
        return !javaScriptMarkers.contains(where: lowered.contains)
    }

    private static func cssInjectionScript(css: String) -> String {
        return """
        (function() {
          const css = \(css.jsTemplateLiteral());
          if (typeof window.upsertUnwatchedStyle === 'function') {
            window.upsertUnwatchedStyle('unwatched-custom-caption-style', css);
            return;
          }
          let style = document.getElementById('unwatched-custom-caption-style');
          if (!style) {
            style = document.createElement('style');
            style.id = 'unwatched-custom-caption-style';
            document.head.appendChild(style);
          }
          style.textContent = css;
        })();
        """
    }

    fileprivate static func isLegacyGeneratedScript(_ script: String) -> Bool {
        script.contains("localStorage.setItem('yt-player-caption-display-settings'") &&
        script.contains("window.upsertUnwatchedStyle('unwatched-generated-caption-style', \"")
    }

    fileprivate static func sanitizeLegacyReload(in script: String) -> String {
        script
            .replacingOccurrences(of: "window.location.reload();", with: "")
            .replacingOccurrences(of: "window.location.reload()", with: "")
            .replacingOccurrences(of: "location.reload();", with: "")
            .replacingOccurrences(of: "location.reload()", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cssColorString(_ color: Color, opacity: Double) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02X%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255),
            Int((alpha * opacity * 255).rounded())
        )
    }

    private static func charEdgeStyleShadow(for charEdgeStyle: Int) -> String {
        switch charEdgeStyle {
        case 1:
            return "rgb(34, 34, 34) 1.6px 1.6px 2.4px, rgb(34, 34, 34) 1.6px 1.6px 3.2px, rgb(34, 34, 34) 1.6px 1.6px 4px"
        case 2:
            return "rgba(255, 255, 255, 0.75) -1px -1px 0px, rgba(0, 0, 0, 0.85) 1px 1px 0px"
        case 3:
            return "rgba(0, 0, 0, 0.85) -1px -1px 0px, rgba(255, 255, 255, 0.75) 1px 1px 0px"
        case 4:
            return "rgb(34, 34, 34) 1px 0px 0px, rgb(34, 34, 34) -1px 0px 0px, rgb(34, 34, 34) 0px 1px 0px, rgb(34, 34, 34) 0px -1px 0px"
        default:
            return "none"
        }
    }

    static func closestFontSize(to size: Double) -> Double {
        subtitleFontSizeOptions.min { abs($0.size - size) < abs($1.size - size) }?.size ?? 18
    }

    static func fontSizeIncrement(for size: Double) -> Int {
        subtitleFontSizeOptions.first(where: { $0.size == size })?.increment ?? 0
    }

    static func fontSizeLabel(for size: Double) -> String {
        subtitleFontSizeOptions.first(where: { $0.size == size })?.label ?? "100%"
    }

    static func fontSizeScale(for size: Double) -> String {
        let scale = subtitleFontSizeOptions.first(where: { $0.size == size })?.size ?? 14
        return String(format: "%.2f", scale / 14)
    }

    static func opacityLabel(for opacity: Double) -> String {
        "\(Int((opacity * 100).rounded()))%"
    }
}

extension Color {
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let redComponent = Int(red * 255)
        let greenComponent = Int(green * 255)
        let blueComponent = Int(blue * 255)
        let alphaComponent = Int(alpha * 255)
        if alphaComponent < 255 {
            return String(
                format: "#%02X%02X%02X%02X",
                redComponent,
                greenComponent,
                blueComponent,
                alphaComponent
            )
        } else {
            return String(format: "#%02X%02X%02X", redComponent, greenComponent, blueComponent)
        }
    }
}

extension UserDefaults {
    func setColor(color: Color, forKey key: String) {
        let uiColor = UIColor(color)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false) {
            self.set(data, forKey: key)
        }
    }

    func colorForKey(key: String) -> Color? {
        guard let data = self.data(forKey: key) else {
            return nil
        }
        if let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
            return Color(uiColor)
        } else {
            return nil
        }
    }
}

extension String {
    func jsTemplateLiteral() -> String {
        let escaped = self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        return "`\(escaped)`"
    }
}

struct SubtitleStyleSettingsView: View {
    @AppStorage(Const.alwaysShowSubtitles) var alwaysShowSubtitles: Bool = false
    @AppStorage(Const.enableWebInspector) var enableWebInspector: Bool = false
    @ObservedObject var store: SubtitleStyleSettingsStore
    @State private var customScriptText: String = ""
    @State private var isEditingCustomScript = false
    @State private var isSyncingGeneratedScript = false
    @State private var clipboardText: String?
    @State private var applyStatus: String?

    let fontFamilyOptions: [(Int, String)] = [
        (0, "Monospaced Serif"),
        (1, "Proportional Serif"),
        (2, "Monospaced Sans-Serif"),
        (3, "Proportional Sans-Serif"),
        (4, "Casual"),
        (5, "Cursive"),
        (6, "Small Capitals"),
        (7, "American Typewriter")
    ]

    let charEdgeStyleOptions: [(Int, String)] = [
        (0, "None"),
        (1, "Drop Shadow"),
        (2, "Raised"),
        (3, "Depressed"),
        (4, "Outline")
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Always show subtitles", isOn: $alwaysShowSubtitles)
                    .onChange(of: alwaysShowSubtitles) {
                        applySubtitleVisibilityPreferenceIfPossible()
                    }
            }

            Section(header: Text("Subtitle Style")) {
                Picker("Font Family", selection: $store.fontFamily) {
                    ForEach(fontFamilyOptions, id: \.0) { key, label in
                        Text(label).tag(key)
                    }
                }
                .pickerStyle(.menu)
                Picker(selection: $store.fontSize) {
                    ForEach(subtitleFontSizeOptions, id: \.size) { option in
                        Text(option.label).tag(option.size)
                    }
                } label: {
                    Text("Font size")
                }
                .pickerStyle(.menu)
                ColorPicker("Font Color", selection: $store.fontColor)
                Slider(value: $store.textOpacity, in: 0...1, step: 0.25) {
                    LabeledContent(
                        "Text opacity",
                        value: SubtitleStyleSettingsStore.opacityLabel(for: store.textOpacity)
                    )
                }
                Picker("Character Edge Style", selection: $store.charEdgeStyle) {
                    ForEach(charEdgeStyleOptions, id: \.0) { key, label in
                        Text(label).tag(key)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Background")) {
                ColorPicker("Background Color", selection: $store.backgroundColor)
                Slider(value: $store.backgroundOpacity, in: 0...1, step: 0.25) {
                    LabeledContent(
                        "Background opacity",
                        value: SubtitleStyleSettingsStore.opacityLabel(for: store.backgroundOpacity)
                    )
                }
                ColorPicker("Window Color", selection: $store.windowColor)
                Slider(value: $store.windowOpacity, in: 0...1, step: 0.25) {
                    LabeledContent(
                        "Window opacity",
                        value: SubtitleStyleSettingsStore.opacityLabel(for: store.windowOpacity)
                    )
                }
            }

            Section(header: Text("Custom Userscript (overrides the generated script)")) {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $customScriptText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.5))
                        )
                        .onChange(of: customScriptText) {
                            guard !isSyncingGeneratedScript else {
                                isSyncingGeneratedScript = false
                                return
                            }
                            isEditingCustomScript = true
                            store.customScript = customScriptText.isEmpty ? nil : customScriptText
                        }

                    HStack {
                        Button("Apply to current video") {
                            applyCurrentScript()
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .disabled(WebViewState.shared.webView == nil)

                        Button("Copy") {
                            ClipboardService.set(customScriptText)
                            clipboardText = customScriptText
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button("Paste") {
                            guard let pastedText = ClipboardService.get(), !pastedText.isEmpty else { return }
                            clipboardText = pastedText
                            customScriptText = pastedText
                            isEditingCustomScript = true
                            store.customScript = pastedText
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .disabled((clipboardText ?? ClipboardService.get())?.isEmpty != false)

                        Spacer()

                        Button("Reset") {
                            isEditingCustomScript = false
                            store.customScript = nil
                            customScriptText = store.generatedScript
                        }
                        .buttonStyle(.borderless)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let applyStatus {
                        Text(applyStatus)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    Text("Editing this will override the automatically generated userscript for captions.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    #if os(iOS) || os(visionOS)
                    Toggle("Enable Web Inspector (may crash on some simulators)", isOn: $enableWebInspector)
                        .onChange(of: enableWebInspector) {
                            applyWebInspectorPreferenceIfPossible()
                        }
                    #endif
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
        }
        .onAppear {
            clipboardText = ClipboardService.get()
            if let savedScript = store.customScript, !savedScript.isEmpty {
                if SubtitleStyleSettingsStore.isLegacyGeneratedScript(savedScript) {
                    syncGeneratedScript()
                } else {
                    customScriptText = savedScript
                    isEditingCustomScript = true
                }
            } else {
                syncGeneratedScript()
            }
        }
        .onChange(of: store.fontFamily) { handleGeneratedSettingsChange() }
        .onChange(of: store.fontSize) { handleGeneratedSettingsChange() }
        .onChange(of: store.fontColor) { handleGeneratedSettingsChange() }
        .onChange(of: store.textOpacity) { handleGeneratedSettingsChange() }
        .onChange(of: store.charEdgeStyle) { handleGeneratedSettingsChange() }
        .onChange(of: store.backgroundColor) { handleGeneratedSettingsChange() }
        .onChange(of: store.backgroundOpacity) { handleGeneratedSettingsChange() }
        .onChange(of: store.windowColor) { handleGeneratedSettingsChange() }
        .onChange(of: store.windowOpacity) { handleGeneratedSettingsChange() }
    }

    private func handleGeneratedSettingsChange() {
        syncGeneratedScript()
        applyGeneratedScriptIfPossible()
    }

    private func applyCurrentScript() {
        sanitizeCustomScriptIfNeeded()
        guard let webView = WebViewState.shared.webView else {
            applyStatus = "No active video player found."
            return
        }
        applyStatus = "Applied to current video."
        webView.evaluateJavaScript(store.activePlayerScript + " undefined;") { _, error in
            if let error {
                applyStatus = "Couldn’t apply subtitle settings: \(error.localizedDescription)"
            }
        }
        applySubtitleVisibilityPreferenceIfPossible()
    }

    private func sanitizeCustomScriptIfNeeded() {
        guard isEditingCustomScript else {
            return
        }
        let sanitizedScript = SubtitleStyleSettingsStore
            .sanitizeLegacyReload(in: customScriptText)
        guard sanitizedScript != customScriptText else {
            return
        }
        customScriptText = sanitizedScript
        store.customScript = sanitizedScript.isEmpty ? nil : sanitizedScript
    }

    private func syncGeneratedScript() {
        isSyncingGeneratedScript = true
        isEditingCustomScript = false
        store.customScript = nil
        customScriptText = store.generatedScript
    }

    private func applyGeneratedScriptIfPossible() {
        guard let webView = WebViewState.shared.webView else {
            return
        }
        webView.evaluateJavaScript(store.generatedScript + " undefined;") { _, error in
            if let error {
                applyStatus = "Couldn’t apply subtitle settings: \(error.localizedDescription)"
            }
        }
    }

    private func applySubtitleVisibilityPreferenceIfPossible() {
        guard alwaysShowSubtitles,
              let webView = WebViewState.shared.webView else {
            return
        }
        let script = """
        (function() {
          function findSubtitleButton() {
            return document.querySelector('.ytp-subtitles-button')
              || document.querySelector('.ytmClosedCaptioningButtonButton')
              || document.querySelector('button[aria-label*="Subtitles/closed captions"]');
          }

          function subtitlesAreEnabled(button) {
            return button?.getAttribute('aria-pressed') === 'true';
          }

          function subtitleButtonIsReady(button) {
            const subtitleButton = button || findSubtitleButton();
            if (!subtitleButton) {
              return false;
            }
            const ariaDisabled = subtitleButton.getAttribute('aria-disabled') === 'true';
            const isDisabled = subtitleButton.disabled || subtitleButton.classList?.contains('ytp-button-disabled');
            const title = (
              subtitleButton.getAttribute('aria-label')
              || subtitleButton.getAttribute('data-title-no-tooltip')
              || subtitleButton.getAttribute('title')
              || ''
            ).toLowerCase();
            return !ariaDisabled && !isDisabled && !title.includes('unavailable');
          }

          function getCaptionTrack(currentTrack) {
            if (!currentTrack?.captionTracks) {
              return null;
            }
            let currentLocale = Object.values(currentTrack || {})
              .find(value => value?.languageCode)
              ?.languageCode;
            if (!currentLocale) {
              currentLocale = navigator.language?.split('-')?.[0] ?? 'en';
            }
            const tracks = currentTrack.captionTracks?.filter(track => track.languageCode === currentLocale);
            if (tracks.length === 0) {
              return currentTrack.captionTracks[0];
            }
            if (tracks.length === 1) {
              return tracks[0];
            }
            const nonAutoTracks = tracks.filter(track => !track.vssId.startsWith('a.'));
            return nonAutoTracks.length > 0 ? nonAutoTracks[0] : tracks[0];
          }

          function captionsLookAvailable() {
            try {
              const player = document.getElementById('movie_player');
              return !!getCaptionTrack(player?.getAudioTrack?.());
            } catch {
              return false;
            }
          }

          function ensureSubtitlesEnabled(retryIndex = 0) {
            if (window.unwatchedAttemptedSubtitleEnable) {
              return;
            }
            const subtitleButton = findSubtitleButton();
            const video = document.querySelector('video');
            if (!subtitleButton || !video) {
              if (retryIndex < 5) {
                setTimeout(() => ensureSubtitlesEnabled(retryIndex + 1), 350 * (retryIndex + 1));
              }
              return;
            }
            if (subtitlesAreEnabled(subtitleButton)) {
              window.unwatchedAttemptedSubtitleEnable = true;
              return;
            }
            if (!subtitleButtonIsReady(subtitleButton)
              || !captionsLookAvailable()
              || video.paused
              || video.readyState < 2) {
              video.addEventListener('play', () => ensureSubtitlesEnabled(0), { once: true });
              if (retryIndex < 5) {
                setTimeout(() => ensureSubtitlesEnabled(retryIndex + 1), 350 * (retryIndex + 1));
              }
              return;
            }
            const subtitleEnableAttempts = window.unwatchedSubtitleEnableAttempts || 0;
            if (subtitleEnableAttempts >= 2) {
              window.unwatchedAttemptedSubtitleEnable = true;
              return;
            }
            window.unwatchedSubtitleEnableAttempts = subtitleEnableAttempts + 1;
            subtitleButton.click();
            setTimeout(() => {
              if (subtitlesAreEnabled()) {
                window.unwatchedAttemptedSubtitleEnable = true;
                return;
              }
              if ((window.unwatchedSubtitleEnableAttempts || 0) >= 2) {
                window.unwatchedAttemptedSubtitleEnable = true;
                return;
              }
              ensureSubtitlesEnabled(0);
            }, 900);
          }

          ensureSubtitlesEnabled();
        })();
        """
        webView.evaluateJavaScript(script + " undefined;") { _, error in
            if let error {
                applyStatus = "Couldn’t enable subtitles: \(error.localizedDescription)"
            }
        }
    }

    private func applyWebInspectorPreferenceIfPossible() {
        #if os(iOS) || os(visionOS)
        guard let webView = WebViewState.shared.webView else {
            return
        }
        if #available(iOS 16.4, visionOS 1.0, *) {
            if webView.responds(to: Selector(("setInspectable:"))) {
                webView.isInspectable = enableWebInspector
            }
        }
        #endif
    }
}
