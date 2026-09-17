import AppKit

/// Parses the absolute-command subset used by
/// `Resources/Assets/battery-shield-icon.svg` (M, L, H, V, C, Z), so the path
/// data can be kept verbatim from the artwork instead of transcribed by hand.
enum SVGPath {
    static func path(_ definition: String) -> NSBezierPath {
        let path = NSBezierPath()
        var numbers: [CGFloat] = []
        var command: Character = "M"
        var start = NSPoint.zero
        var current = NSPoint.zero

        func flush() {
            guard !numbers.isEmpty else { return }
            switch command {
            case "M":
                for index in stride(from: 0, to: numbers.count - 1, by: 2) {
                    current = NSPoint(x: numbers[index], y: numbers[index + 1])
                    if index == 0 {
                        path.move(to: current)
                        start = current
                    } else {
                        path.line(to: current)
                    }
                }
            case "L":
                for index in stride(from: 0, to: numbers.count - 1, by: 2) {
                    current = NSPoint(x: numbers[index], y: numbers[index + 1])
                    path.line(to: current)
                }
            case "H":
                for value in numbers {
                    current = NSPoint(x: value, y: current.y)
                    path.line(to: current)
                }
            case "V":
                for value in numbers {
                    current = NSPoint(x: current.x, y: value)
                    path.line(to: current)
                }
            case "C":
                for index in stride(from: 0, to: numbers.count - 5, by: 6) {
                    let control1 = NSPoint(x: numbers[index], y: numbers[index + 1])
                    let control2 = NSPoint(x: numbers[index + 2], y: numbers[index + 3])
                    current = NSPoint(x: numbers[index + 4], y: numbers[index + 5])
                    path.curve(to: current, controlPoint1: control1, controlPoint2: control2)
                }
            default:
                break
            }
            numbers.removeAll(keepingCapacity: true)
        }

        var token = ""
        func takeNumber() {
            guard !token.isEmpty else { return }
            if let value = Double(token) { numbers.append(CGFloat(value)) }
            token = ""
        }

        for character in definition {
            switch character {
            case "M", "L", "H", "V", "C", "Z", "z":
                takeNumber()
                flush()
                if character == "Z" || character == "z" {
                    path.close()
                    current = start
                } else {
                    command = character
                }
            case " ", ",", "\n", "\t", "\r":
                takeNumber()
            case "-":
                // A minus starts a new number unless it is an exponent sign.
                if token.isEmpty || token.lowercased().hasSuffix("e") {
                    token.append(character)
                } else {
                    takeNumber()
                    token.append(character)
                }
            default:
                token.append(character)
            }
        }
        takeNumber()
        flush()
        return path
    }
}
