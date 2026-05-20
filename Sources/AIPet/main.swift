import AppKit

if CommandLine.arguments.contains("--validate-character-packs") {
    let library = CharacterPackLibrary(settings: SettingsStore())
    let packs = library.availablePacks()
    print("Character packs: \(packs.count)")
    for pack in packs {
        print("- \(pack.manifest.id): \(pack.manifest.displayName), poses=\(pack.images.count)")
    }
    exit(packs.isEmpty ? 1 : 0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
