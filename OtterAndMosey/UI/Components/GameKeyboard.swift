import SwiftUI
import UIKit

/// Heights the on-screen keys need, so scenes can keep gameplay clear of them.
enum KeyMetrics {
    static func trayHeight(compact: Bool) -> CGFloat { compact ? 76 : 104 }
    static func qwertyHeight(compact: Bool) -> CGFloat { compact ? 146 : 226 }
    static func numberHeight(compact: Bool) -> CGFloat { compact ? 76 : 104 }
}

private struct KeyCap: View {
    var label: String
    var width: CGFloat
    var height: CGFloat
    var fill: Color = Palette.cream
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.game(min(height * 0.5, 34)))
                .foregroundStyle(Palette.ink)
                .frame(width: width, height: height)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.ink).offset(y: 3)
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(fill)
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5)
                    }
                )
        }
        .buttonStyle(KeyPressStyle())
        .accessibilityLabel(label == "␣" ? "space" : label)
    }
}

private struct KeyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.12 : 1)
            .offset(y: configuration.isPressed ? -4 : 0)
            .animation(.spring(duration: 0.12), value: configuration.isPressed)
    }
}

/// The game's own keyboard, in whichever form the current question needs.
struct GameKeyboard: View {
    var kind: KeyboardKind
    var width: CGFloat
    var onKey: (Character) -> Void
    var onBackspace: () -> Void
    @Environment(\.compact) private var compact

    var body: some View {
        Group {
            switch kind {
            case .none: EmptyView()
            case .tray(let letters): tray(letters)
            case .qwerty(let space): qwerty(space: space)
            case .numbers: numbers
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(Palette.ink.opacity(0.82).ignoresSafeArea(edges: [.bottom, .horizontal]))
    }

    /// One row of large tiles: the answer's letters mixed with a few others.
    private func tray(_ letters: [Character]) -> some View {
        let spacing: CGFloat = compact ? 8 : 12
        let keyWidth = min((width - spacing * CGFloat(letters.count + 1)) / CGFloat(max(letters.count, 1)), compact ? 76 : 96)
        return HStack(spacing: spacing) {
            ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                KeyCap(label: String(letter), width: keyWidth, height: KeyMetrics.trayHeight(compact: compact) - 22) { onKey(letter) }
            }
        }
    }

    private func qwerty(space: Bool) -> some View {
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        let spacing: CGFloat = compact ? 5 : 8
        let usable = min(width, compact ? 720 : 900)
        let keyWidth = (usable - spacing * 11) / 10
        let keyHeight = (KeyMetrics.qwertyHeight(compact: compact) - 20 - spacing * 2) / 3
        return VStack(spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(Array(row), id: \.self) { letter in
                        KeyCap(label: String(letter), width: keyWidth, height: keyHeight) { onKey(letter) }
                    }
                    if row == "zxcvbnm", space {
                        KeyCap(label: "␣", width: keyWidth * 2.6, height: keyHeight, fill: Palette.gold) { onKey(" ") }
                    }
                }
            }
        }
    }

    private var numbers: some View {
        let spacing: CGFloat = compact ? 6 : 10
        let keyWidth = min((width - spacing * 12) / 11, compact ? 62 : 84)
        let height = KeyMetrics.numberHeight(compact: compact) - 22
        return HStack(spacing: spacing) {
            ForEach(Array("1234567890"), id: \.self) { digit in
                KeyCap(label: String(digit), width: keyWidth, height: height) { onKey(digit) }
            }
            KeyCap(label: "⌫", width: keyWidth, height: height, fill: Palette.coral.opacity(0.7), action: onBackspace)
        }
    }
}

/// Invisible view that listens for a hardware keyboard without ever raising the system keyboard.
struct HardwareKeys: UIViewRepresentable {
    var onKey: (Character) -> Void
    var onBackspace: () -> Void

    func makeUIView(context: Context) -> KeyView {
        let view = KeyView()
        view.onKey = onKey
        view.onBackspace = onBackspace
        return view
    }

    func updateUIView(_ view: KeyView, context: Context) {
        view.onKey = onKey
        view.onBackspace = onBackspace
        if view.window != nil, !view.isFirstResponder { view.becomeFirstResponder() }
    }

    final class KeyView: UIView {
        var onKey: ((Character) -> Void)?
        var onBackspace: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { becomeFirstResponder() }
        }

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            var handled = false
            for press in presses {
                guard let key = press.key else { continue }
                if key.keyCode == .keyboardDeleteOrBackspace {
                    onBackspace?()
                    handled = true
                } else if let character = key.characters.first, character.isLetter || character.isNumber || character == " " {
                    onKey?(character)
                    handled = true
                }
            }
            if !handled { super.pressesBegan(presses, with: event) }
        }
    }
}
