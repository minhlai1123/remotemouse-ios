import XCTest
@testable import RemoteMouseCore

final class KeyboardManagerTests: XCTestCase {

    var client: RMPPClient!
    var keyboardManager: KeyboardManager!
    var lastModifierState: KeyboardManager.ModifierState?

    override func setUp() {
        super.setUp()
        client = RMPPClient()
        keyboardManager = KeyboardManager(client: client) { [weak self] state in
            self?.lastModifierState = state
        }
    }

    func testNFCNormalizationVietnamese() {
        let originalText = "Cộng hòa Xã hội Chủ nghĩa Việt Nam - 2026"
        let decomposedNFD = originalText.decomposedStringWithCanonicalMapping
        XCTAssertNotEqual(originalText, decomposedNFD)

        let normalizedNFC = KeyboardManager.normalizeToNFC(decomposedNFD)
        XCTAssertEqual(normalizedNFC, originalText.precomposedStringWithCanonicalMapping)

        // Verify specific accented characters
        let vietnameseWord = "Tiếng Việt"
        let wordNFD = vietnameseWord.decomposedStringWithCanonicalMapping
        let wordNFC = KeyboardManager.normalizeToNFC(wordNFD)
        XCTAssertEqual(wordNFC, vietnameseWord.precomposedStringWithCanonicalMapping)
    }

    func testVirtualKeyCodesMatchWin32() {
        XCTAssertEqual(KeyboardManager.vkBack, 0x08)
        XCTAssertEqual(KeyboardManager.vkTab, 0x09)
        XCTAssertEqual(KeyboardManager.vkReturn, 0x0D)
        XCTAssertEqual(KeyboardManager.vkShift, 0x10)
        XCTAssertEqual(KeyboardManager.vkControl, 0x11)
        XCTAssertEqual(KeyboardManager.vkMenu, 0x12)
        XCTAssertEqual(KeyboardManager.vkEscape, 0x1B)
        XCTAssertEqual(KeyboardManager.vkSpace, 0x20)
        XCTAssertEqual(KeyboardManager.vkDelete, 0x2E)
        XCTAssertEqual(KeyboardManager.vkLWin, 0x5B)
        XCTAssertEqual(KeyboardManager.vkF1, 0x70)
        XCTAssertEqual(KeyboardManager.vkF12, 0x7B)
    }

    func testStickyModifiersToggle() {
        XCTAssertFalse(keyboardManager.currentModifierState.isCtrlActive)

        // Toggle Ctrl
        let ctrlState = keyboardManager.toggleCtrl()
        XCTAssertTrue(ctrlState)
        XCTAssertTrue(keyboardManager.currentModifierState.isCtrlActive)
        XCTAssertEqual(lastModifierState?.isCtrlActive, true)

        // Toggle Alt
        let altState = keyboardManager.toggleAlt()
        XCTAssertTrue(altState)
        XCTAssertTrue(keyboardManager.currentModifierState.isAltActive)

        // Toggle Shift
        let shiftState = keyboardManager.toggleShift()
        XCTAssertTrue(shiftState)
        XCTAssertTrue(keyboardManager.currentModifierState.isShiftActive)

        // Toggle Win
        let winState = keyboardManager.toggleWin()
        XCTAssertTrue(winState)
        XCTAssertTrue(keyboardManager.currentModifierState.isWinActive)

        // Toggle Ctrl back off
        let ctrlStateOff = keyboardManager.toggleCtrl()
        XCTAssertFalse(ctrlStateOff)
        XCTAssertFalse(keyboardManager.currentModifierState.isCtrlActive)
        XCTAssertEqual(lastModifierState?.isCtrlActive, false)
    }

    func testReleaseAllModifiers() {
        keyboardManager.toggleCtrl()
        keyboardManager.toggleAlt()
        keyboardManager.toggleShift()
        keyboardManager.toggleWin()

        XCTAssertTrue(keyboardManager.currentModifierState.isCtrlActive)
        XCTAssertTrue(keyboardManager.currentModifierState.isAltActive)
        XCTAssertTrue(keyboardManager.currentModifierState.isShiftActive)
        XCTAssertTrue(keyboardManager.currentModifierState.isWinActive)

        keyboardManager.releaseAllModifiers()

        XCTAssertFalse(keyboardManager.currentModifierState.isCtrlActive)
        XCTAssertFalse(keyboardManager.currentModifierState.isAltActive)
        XCTAssertFalse(keyboardManager.currentModifierState.isShiftActive)
        XCTAssertFalse(keyboardManager.currentModifierState.isWinActive)
    }

    func testAdaptiveLabels() {
        keyboardManager.targetOS = .windows
        XCTAssertEqual(keyboardManager.ctrlLabel, "Ctrl")
        XCTAssertEqual(keyboardManager.altLabel, "Alt")
        XCTAssertEqual(keyboardManager.shiftLabel, "Shift")
        XCTAssertEqual(keyboardManager.winLabel, "Win")

        keyboardManager.targetOS = .macOS
        XCTAssertEqual(keyboardManager.ctrlLabel, "Control")
        XCTAssertEqual(keyboardManager.altLabel, "Option")
        XCTAssertEqual(keyboardManager.shiftLabel, "Shift")
        XCTAssertEqual(keyboardManager.winLabel, "Cmd")
    }
}
