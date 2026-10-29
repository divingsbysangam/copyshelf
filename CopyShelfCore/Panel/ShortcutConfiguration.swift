import Foundation

public struct ShortcutConfiguration: Equatable, Sendable {
    public static let command = 1 << 8
    public static let shift = 1 << 9
    public static let option = 1 << 11
    public static let control = 1 << 12
    public static let allowedModifiers = command | shift | option | control
    public static let standard = ShortcutConfiguration(keyCode: 9, modifiers: control | command | shift)

    public var keyCode: Int
    public var modifiers: Int
    public init(keyCode: Int, modifiers: Int) { self.keyCode = keyCode; self.modifiers = modifiers }
    public var isValid: Bool { (0...127).contains(keyCode) && modifiers > 0 && modifiers & ~Self.allowedModifiers == 0 }

    public static func load(from defaults: UserDefaults) -> ShortcutConfiguration {
        let candidate = ShortcutConfiguration(keyCode: defaults.object(forKey: "shortcutKeyCode") as? Int ?? standard.keyCode,
                                              modifiers: defaults.object(forKey: "shortcutModifiers") as? Int ?? standard.modifiers)
        return candidate.isValid ? candidate : standard
    }
    public func save(to defaults: UserDefaults) {
        defaults.set(keyCode, forKey: "shortcutKeyCode")
        defaults.set(modifiers, forKey: "shortcutModifiers")
    }
}
