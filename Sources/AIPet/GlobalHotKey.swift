import Carbon
import Foundation

final class GlobalHotKey {
    private static var activeHandler: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func registerOptionShiftSpace(handler: @escaping () -> Void) {
        unregister()
        Self.activeHandler = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr, hotKeyID.id == 1 else {
                    return noErr
                }

                DispatchQueue.main.async {
                    GlobalHotKey.activeHandler?()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("AIPT"), id: 1)
        guard handlerStatus == noErr else {
            Self.activeHandler = nil
            return
        }

        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if hotKeyStatus != noErr {
            unregister()
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        Self.activeHandler = nil
    }

    deinit {
        unregister()
    }
}

private func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, byte in
        (result << 8) + OSType(byte)
    }
}
