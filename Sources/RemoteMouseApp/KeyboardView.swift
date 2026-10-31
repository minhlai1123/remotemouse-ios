import SwiftUI
import RemoteMouseCore

public struct KeyboardView: View {
    public let keyboardManager: KeyboardManager
    @State private var inputText: String = ""
    @State private var modifierState: KeyboardManager.ModifierState = KeyboardManager.ModifierState()
    @FocusState private var isFieldFocused: Bool

    public init(keyboardManager: KeyboardManager) {
        self.keyboardManager = keyboardManager
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Modifiers Row
            HStack(spacing: 8) {
                // Toggle Soft Keyboard button
                Button(action: {
                    isFieldFocused.toggle()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                        Text(isFieldFocused ? "Hide" : "Keyboard")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .frame(height: 32)
                    .background(isFieldFocused ? Color.accentColor : Color(.tertiarySystemBackground))
                    .foregroundColor(isFieldFocused ? .white : .primary)
                    .cornerRadius(8)
                }

                // Sticky Modifiers: Ctrl, Alt/Option, Shift, Win/Cmd
                Button(action: {
                    keyboardManager.toggleCtrl()
                    modifierState = keyboardManager.currentModifierState
                }) {
                    Text(keyboardManager.ctrlLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, maxHeight: 32)
                        .background(modifierState.isCtrlActive ? Color.accentColor : Color(.tertiarySystemBackground))
                        .foregroundColor(modifierState.isCtrlActive ? .white : .primary)
                        .cornerRadius(8)
                }

                Button(action: {
                    keyboardManager.toggleAlt()
                    modifierState = keyboardManager.currentModifierState
                }) {
                    Text(keyboardManager.altLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, maxHeight: 32)
                        .background(modifierState.isAltActive ? Color.accentColor : Color(.tertiarySystemBackground))
                        .foregroundColor(modifierState.isAltActive ? .white : .primary)
                        .cornerRadius(8)
                }

                Button(action: {
                    keyboardManager.toggleShift()
                    modifierState = keyboardManager.currentModifierState
                }) {
                    Text(keyboardManager.shiftLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, maxHeight: 32)
                        .background(modifierState.isShiftActive ? Color.accentColor : Color(.tertiarySystemBackground))
                        .foregroundColor(modifierState.isShiftActive ? .white : .primary)
                        .cornerRadius(8)
                }

                Button(action: {
                    keyboardManager.toggleWin()
                    modifierState = keyboardManager.currentModifierState
                }) {
                    Text(keyboardManager.winLabel)
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity, maxHeight: 32)
                        .background(modifierState.isWinActive ? Color.accentColor : Color(.tertiarySystemBackground))
                        .foregroundColor(modifierState.isWinActive ? .white : .primary)
                        .cornerRadius(8)
                }
            }

            // Function Keys Scroll Row (Esc, Tab, Enter, Backspace, Del, F1-F12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    keyButton("Esc", vk: KeyboardManager.vkEscape)
                    keyButton("Tab", vk: KeyboardManager.vkTab)
                    keyButton("Enter", vk: KeyboardManager.vkReturn)
                    keyButton("⌫", vk: KeyboardManager.vkBack)
                    keyButton("Del", vk: KeyboardManager.vkDelete)
                    keyButton("F1", vk: KeyboardManager.vkF1)
                    keyButton("F2", vk: KeyboardManager.vkF2)
                    keyButton("F3", vk: KeyboardManager.vkF3)
                    keyButton("F4", vk: KeyboardManager.vkF4)
                    keyButton("F5", vk: KeyboardManager.vkF5)
                    keyButton("F6", vk: KeyboardManager.vkF6)
                    keyButton("F7", vk: KeyboardManager.vkF7)
                    keyButton("F8", vk: KeyboardManager.vkF8)
                    keyButton("F9", vk: KeyboardManager.vkF9)
                    keyButton("F10", vk: KeyboardManager.vkF10)
                    keyButton("F11", vk: KeyboardManager.vkF11)
                    keyButton("F12", vk: KeyboardManager.vkF12)
                }
            }

            // Text Input / Voice Dictation Field (Supports Vietnamese Telex, VNI & Apple Dictation)
            HStack(spacing: 8) {
                TextField("Type or dictate text here...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isFieldFocused)
                    .onSubmit {
                        sendCurrentText()
                    }

                Button(action: {
                    sendCurrentText()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? .secondary : .accentColor)
                }
                .disabled(inputText.isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .onAppear {
            modifierState = keyboardManager.currentModifierState
        }
    }

    private func keyButton(_ title: String, vk: UInt16) -> some View {
        Button(action: {
            keyboardManager.sendKey(vk)
        }) {
            Text(title)
                .font(.caption2.monospaced())
                .frame(minWidth: 40, minHeight: 28)
                .padding(.horizontal, 4)
                .background(Color(.tertiarySystemBackground))
                .foregroundColor(.primary)
                .cornerRadius(6)
        }
    }

    private func sendCurrentText() {
        guard !inputText.isEmpty else { return }
        keyboardManager.sendText(inputText)
        inputText = ""
    }
}
