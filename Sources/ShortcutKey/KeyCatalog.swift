import Foundation

enum KeyCatalog {
    // macOS virtual key codes. Store codes so shortcuts remain stable across input methods.
    private static let names: [UInt32: String] = [
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V", 11:"B",
        12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 31:"O", 32:"U", 34:"I", 35:"P",
        37:"L", 38:"J", 40:"K", 45:"N", 46:"M",
        18:"1", 19:"2", 20:"3", 21:"4", 22:"6", 23:"5", 25:"9", 26:"7", 28:"8", 29:"0",
        24:"=", 27:"-", 30:"]", 33:"[", 39:"'", 41:";", 42:"\\", 43:",", 44:"/", 47:".", 50:"`",
        36:"Return", 48:"Tab", 49:"Space", 51:"Delete", 53:"Escape",
        122:"F1", 120:"F2", 99:"F3", 118:"F4", 96:"F5", 97:"F6", 98:"F7", 100:"F8", 101:"F9", 109:"F10", 103:"F11", 111:"F12",
        105:"F13", 107:"F14", 113:"F15", 106:"F16", 64:"F17", 79:"F18", 80:"F19", 90:"F20",
        65:"Num .", 67:"Num *", 69:"Num +", 71:"Num Clear", 75:"Num /", 76:"Num Enter", 78:"Num -", 81:"Num =",
        82:"Num 0", 83:"Num 1", 84:"Num 2", 85:"Num 3", 86:"Num 4", 87:"Num 5", 88:"Num 6", 89:"Num 7", 91:"Num 8", 92:"Num 9",
        115:"Home", 116:"Page Up", 117:"Forward Delete", 119:"End", 121:"Page Down",
        123:"←", 124:"→", 125:"↓", 126:"↑"
    ]

    private static let modifierCodes: Set<UInt32> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    static func name(for keyCode: UInt32) -> String? {
        guard keyCode <= 127, !modifierCodes.contains(keyCode) else { return nil }
        return names[keyCode] ?? "Key \(keyCode)"
    }
}
