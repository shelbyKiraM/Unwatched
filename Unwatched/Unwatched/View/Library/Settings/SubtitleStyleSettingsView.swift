import SwiftUI
import Combine

final class SubtitleStyleSettingsStore: ObservableObject {
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
            UserDefaults.standard.set(customScript, forKey: "SubtitleStyleCustomScript")
        }
    }

    init() {
        let storedFontFamily = UserDefaults.standard.integer(forKey: "SubtitleStyleFontFamily")
        fontFamily = (
            storedFontFamily == 0
                && UserDefaults.standard.object(forKey: "SubtitleStyleFontFamily") == nil
        ) ? 3 : storedFontFamily // default 3

        let storedSize = UserDefaults.standard.double(forKey: "SubtitleStyleFontSize")
        fontSize = storedSize == 0 ? 14.0 : storedSize

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

        customScript = UserDefaults.standard.string(forKey: "SubtitleStyleCustomScript")
    }

    var generatedScript: String {
        let fontSizeIncrement = Int(round((fontSize - 14) / 2))
        let colorString = fontColor.toHexString()
        let backgroundString = backgroundColor.toHexString()
        let windowColorString = windowColor.toHexString()

        return """
        (function() {
          localStorage.setItem('yt-player-caption-display-settings', JSON.stringify({
            data: JSON.stringify({
              fontFamily: \(fontFamily),
              fontSizeIncrement: \(fontSizeIncrement),
              color: "\(colorString)",
              fontOpacity: \(textOpacity),
              background: "\(backgroundString)",
              backgroundOpacity: \(backgroundOpacity),
              windowColor: "\(windowColorString)",
              windowOpacity: \(windowOpacity),
              charEdgeStyle: \(charEdgeStyle)
            }),
            expiration: Date.now() + 30 * 24 * 60 * 60 * 1000,
            creation: Date.now()
          }));
          window.location.reload();
        })();
        """
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
            return String(format: "rgba(%d, %d, %d, %.2f)", redComponent, greenComponent, blueComponent, alpha)
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

struct SubtitleStyleSettingsView: View {
    @ObservedObject var store: SubtitleStyleSettingsStore
    @State private var customScriptText: String = ""
    @State private var isEditingCustomScript = false

    let fontFamilyOptions: [(Int, String)] = [
        (0, "Monospaced Serif"),
        (1, "Proportional Serif"),
        (2, "Monospaced Sans-Serif"),
        (3, "Proportional Sans-Serif"),
        (4, "Casual"),
        (5, "Cursive"),
        (6, "Small Capitals")
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
            Section(header: Text("Subtitle Style")) {
                Picker("Font Family", selection: $store.fontFamily) {
                    ForEach(fontFamilyOptions, id: \.0) { key, label in
                        Text(label).tag(key)
                    }
                }
                Slider(value: $store.fontSize, in: 8...72, step: 1) {
                    Text("Font Size")
                }
                ColorPicker("Font Color", selection: $store.fontColor)
                Slider(value: $store.textOpacity, in: 0...1, step: 0.25) {
                    Text("Font Opacity")
                }
                Picker("Character Edge Style", selection: $store.charEdgeStyle) {
                    ForEach(charEdgeStyleOptions, id: \.0) { key, label in
                        Text(label).tag(key)
                    }
                }
            }

            Section(header: Text("Background")) {
                ColorPicker("Background Color", selection: $store.backgroundColor)
                Slider(value: $store.backgroundOpacity, in: 0...1, step: 0.25) {
                    Text("Background Opacity")
                }
                ColorPicker("Window Color", selection: $store.windowColor)
                Slider(value: $store.windowOpacity, in: 0...1, step: 0.25) {
                    Text("Window Opacity")
                }
            }

            Section(header: Text("Custom Userscript (overrides the generated script)")) {
                TextEditor(text: $customScriptText)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.5))
                    )
                    .onChange(of: customScriptText) {
                        isEditingCustomScript = true
                        store.customScript = customScriptText.isEmpty ? nil : customScriptText
                    }
                Button("Reset") {
                    isEditingCustomScript = false
                    store.customScript = nil
                    customScriptText = store.generatedScript
                }
                .padding(.top, 4)
                Text("Editing this will override the automatically generated userscript for captions.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .onAppear {
            if let savedScript = store.customScript, !savedScript.isEmpty {
                customScriptText = savedScript
                isEditingCustomScript = true
            } else {
                customScriptText = store.generatedScript
                isEditingCustomScript = false
            }
        }
        .onChange(of: store.fontFamily) { updateScriptIfNeeded() }
        .onChange(of: store.fontSize) { updateScriptIfNeeded() }
        .onChange(of: store.fontColor) { updateScriptIfNeeded() }
        .onChange(of: store.textOpacity) { updateScriptIfNeeded() }
        .onChange(of: store.charEdgeStyle) { updateScriptIfNeeded() }
        .onChange(of: store.backgroundColor) { updateScriptIfNeeded() }
        .onChange(of: store.backgroundOpacity) { updateScriptIfNeeded() }
        .onChange(of: store.windowColor) { updateScriptIfNeeded() }
        .onChange(of: store.windowOpacity) { updateScriptIfNeeded() }
    }

    private func updateScriptIfNeeded() {
        if !isEditingCustomScript {
            customScriptText = store.generatedScript
            store.customScript = nil
        }
    }
}
