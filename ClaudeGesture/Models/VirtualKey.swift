import CoreGraphics

/// Action performed when a virtual key is triggered
enum VirtualKeyAction {
    case keyPress(code: UInt16, modifiers: CGEventFlags?)
    case voiceToggle
}

/// Defines a virtual keyboard key
struct VirtualKey: Identifiable {
    let id: String
    let label: String
    let action: VirtualKeyAction
    let widthFactor: CGFloat
}

/// Layout definition for the virtual keyboard
struct VirtualKeyboardLayout {
    let rows: [[VirtualKey]]

    static let defaultLayout: VirtualKeyboardLayout = {
        let row1: [VirtualKey] = [
            VirtualKey(id: "key1", label: "1", action: .keyPress(code: 18, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "key2", label: "2", action: .keyPress(code: 19, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "key3", label: "3", action: .keyPress(code: 20, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "key4", label: "4", action: .keyPress(code: 21, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "key5", label: "5", action: .keyPress(code: 23, modifiers: nil), widthFactor: 1)
        ]
        let row2: [VirtualKey] = [
            VirtualKey(id: "esc", label: "Esc", action: .keyPress(code: 53, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "shiftTab", label: "Shift+Tab", action: .keyPress(code: 48, modifiers: .maskShift), widthFactor: 1),
            VirtualKey(id: "tab", label: "Tab", action: .keyPress(code: 48, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "enter", label: "Enter", action: .keyPress(code: 36, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "pageUp", label: "Pg Up", action: .keyPress(code: 116, modifiers: nil), widthFactor: 1),
            VirtualKey(id: "pageDown", label: "Pg Dn", action: .keyPress(code: 121, modifiers: nil), widthFactor: 1)
        ]
        let row3: [VirtualKey] = [
            VirtualKey(id: "voice", label: "Voice", action: .voiceToggle, widthFactor: 6)
        ]
        return VirtualKeyboardLayout(rows: [row1, row2, row3])
    }()
}
