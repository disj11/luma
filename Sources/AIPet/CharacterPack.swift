import AppKit

enum PoseKey: String, Codable, CaseIterable {
    case idle
    case walk
    case walkAlt
    case jump
    case fall
    case sit
    case sleep
    case groom
    case happy
    case alert
    case play
    case peek
}

struct CharacterPack: Decodable {
    struct Render: Decodable {
        var baseSize: CGFloat
        var baseYOffset: CGFloat
    }

    struct Pose: Decodable {
        var file: String
        var motion: String?
        var scale: CGFloat?
        var yOffset: CGFloat?
        var crossfade: Bool?
    }

    var id: String
    var displayName: String
    var version: Int
    var author: String?
    var persona: String?
    var defaultPose: PoseKey
    var canvasSize: CGFloat?
    var render: Render
    var poses: [String: Pose]

    func pose(for key: PoseKey) -> Pose? {
        poses[key.rawValue]
    }

    static func bundledDefault() -> LoadedCharacterPack? {
        LoadedCharacterPack(
            manifestURL: Bundle.module.characterPackManifestURL(subdirectory: "Pets/LunaSera"),
            isBundled: true
        )
    }
}

extension Bundle {
    func characterPackManifestURL(subdirectory: String) -> URL? {
        url(forResource: "manifest", withExtension: "json", subdirectory: subdirectory)
            ?? url(forResource: "manifest", withExtension: "json", subdirectory: "Resources/\(subdirectory)")
    }
}

struct LoadedCharacterPack {
    let manifest: CharacterPack
    let baseURL: URL
    let images: [PoseKey: NSImage]
    let alphaBounds: [PoseKey: CGRect]
    let isBundled: Bool

    init?(manifestURL: URL?, isBundled: Bool) {
        guard let manifestURL else {
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(CharacterPack.self, from: data)
            let baseURL = manifestURL.deletingLastPathComponent()
            var images: [PoseKey: NSImage] = [:]
            var alphaBounds: [PoseKey: CGRect] = [:]

            for (rawKey, pose) in manifest.poses {
                guard let key = PoseKey(rawValue: rawKey) else {
                    continue
                }
                let imageURL = baseURL.appendingPathComponent(pose.file)
                guard let image = NSImage(contentsOf: imageURL) else {
                    return nil
                }
                images[key] = image
                alphaBounds[key] = Self.alphaBounds(for: image) ?? CGRect(origin: .zero, size: image.size)
            }

            guard images[manifest.defaultPose] != nil, manifest.pose(for: manifest.defaultPose) != nil else {
                return nil
            }

            self.manifest = manifest
            self.baseURL = baseURL
            self.images = images
            self.alphaBounds = alphaBounds
            self.isBundled = isBundled
        } catch {
            return nil
        }
    }

    func visibleBoundsInPetWindow(for key: PoseKey, windowSize: CGSize) -> CGRect? {
        guard let pose = manifest.pose(for: key),
              let image = images[key],
              let alphaBounds = alphaBounds[key],
              image.size.width > 0,
              image.size.height > 0 else {
            return nil
        }

        let target = renderedImageRect(for: pose, windowSize: windowSize)
        let scaleX = target.width / image.size.width
        let scaleY = target.height / image.size.height
        return CGRect(
            x: target.minX + alphaBounds.minX * scaleX,
            y: target.minY + alphaBounds.minY * scaleY,
            width: alphaBounds.width * scaleX,
            height: alphaBounds.height * scaleY
        )
    }

    func renderedImageRect(for key: PoseKey, windowSize: CGSize) -> CGRect? {
        guard let pose = manifest.pose(for: key), images[key] != nil else {
            return nil
        }
        return renderedImageRect(for: pose, windowSize: windowSize)
    }

    func renderedImageRect(for pose: CharacterPack.Pose, windowSize: CGSize) -> CGRect {
        let baseSize = min(windowSize.width - 20, windowSize.height - 20, manifest.render.baseSize)
        let size = baseSize * (pose.scale ?? 1)
        return CGRect(
            x: windowSize.width / 2 - size / 2,
            y: manifest.render.baseYOffset + (pose.yOffset ?? 0),
            width: size,
            height: size
        )
    }

    private static func alphaBounds(for image: NSImage) -> CGRect? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                let alpha = pixels[offset + 3]
                guard alpha > 8 else { continue }

                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: height - maxY - 1, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}

final class CharacterPackLibrary {
    private let settings: SettingsStore
    private let fileManager = FileManager.default

    init(settings: SettingsStore) {
        self.settings = settings
    }

    var userCharactersDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Luma/Characters", isDirectory: true)
    }

    private var legacyUserCharactersDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("AIPet/Characters", isDirectory: true)
    }

    func availablePacks() -> [LoadedCharacterPack] {
        var packs: [LoadedCharacterPack] = []
        if let bundled = CharacterPack.bundledDefault() {
            packs.append(bundled)
        }

        for directory in [userCharactersDirectory, legacyUserCharactersDirectory] {
            if let urls = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in urls {
                    let manifestURL = url.appendingPathComponent("manifest.json")
                    if let pack = LoadedCharacterPack(manifestURL: manifestURL, isBundled: false),
                       !packs.contains(where: { $0.manifest.id == pack.manifest.id }) {
                        packs.append(pack)
                    }
                }
            }
        }

        return packs
    }

    func selectedPack() -> LoadedCharacterPack? {
        let packs = availablePacks()
        if let selectedID = settings.selectedCharacterID,
           let selected = packs.first(where: { $0.manifest.id == selectedID }) {
            return selected
        }
        return packs.first
    }

    func select(_ pack: LoadedCharacterPack) {
        settings.selectedCharacterID = pack.manifest.id
    }

    func importPack(from sourceURL: URL) throws -> LoadedCharacterPack {
        try fileManager.createDirectory(at: userCharactersDirectory, withIntermediateDirectories: true)

        guard let sourcePack = LoadedCharacterPack(
            manifestURL: sourceURL.appendingPathComponent("manifest.json"),
            isBundled: false
        ) else {
            throw CharacterPackError.invalidManifest
        }

        let destination = userCharactersDirectory.appendingPathComponent(sourcePack.manifest.id, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)

        guard let imported = LoadedCharacterPack(
            manifestURL: destination.appendingPathComponent("manifest.json"),
            isBundled: false
        ) else {
            throw CharacterPackError.invalidManifest
        }
        settings.selectedCharacterID = imported.manifest.id
        return imported
    }
}

enum CharacterPackError: LocalizedError {
    case invalidManifest

    var errorDescription: String? {
        switch self {
        case .invalidManifest:
            return "manifest.json과 pose PNG를 읽을 수 없어요. 캐릭터 팩 구조를 확인해주세요."
        }
    }
}

extension PetMood {
    var poseKey: PoseKey {
        switch self {
        case .idle:
            return .idle
        case .walk:
            return .walk
        case .jump:
            return .jump
        case .fall:
            return .fall
        case .sit:
            return .sit
        case .alert:
            return .alert
        case .sleep:
            return .sleep
        case .groom:
            return .groom
        case .play:
            return .play
        case .happy:
            return .happy
        case .peek:
            return .peek
        }
    }
}
