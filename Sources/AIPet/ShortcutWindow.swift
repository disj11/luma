import AppKit

final class ShortcutWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            performClose(nil)
            return
        }
        super.keyDown(with: event)
    }
}
