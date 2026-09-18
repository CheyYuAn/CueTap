/// Physical ANSI US layout shared by startup validation and native output.
enum USKeyboardLayout {
    struct Stroke {
        let keyCode: UInt16
        let shifted: Bool
    }
    private static let strokes: [Character: Stroke] = {
        let rows: [(String, String, [UInt16])] = [
            ("`1234567890-=", "~!@#$%^&*()_+", [50,18,19,20,21,23,22,26,28,25,29,27,24]),
            ("qwertyuiop[]\\", "QWERTYUIOP{}|", [12,13,14,15,17,16,32,34,31,35,33,30,42]),
            ("asdfghjkl;'", "ASDFGHJKL:\"", [0,1,2,3,5,4,38,40,37,41,39]),
            ("zxcvbnm,./", "ZXCVBNM<>?", [6,7,8,9,11,45,46,43,47,44])
        ]
        var result: [Character: Stroke] = [" ": Stroke(keyCode: 49, shifted: false)]
        for (plain, shifted, codes) in rows {
            for (character, code) in zip(plain, codes) { result[character] = Stroke(keyCode: code, shifted: false) }
            for (character, code) in zip(shifted, codes) { result[character] = Stroke(keyCode: code, shifted: true) }
        }
        return result
    }()
    static func stroke(for character: Character) -> Stroke? { strokes[character] }
}
