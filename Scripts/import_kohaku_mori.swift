import AppKit
import Foundation

struct PoseSpec {
    let key: String
    let file: String
    let motion: String
    let scale: Double?
    let yOffset: Double?
    let crossfade: Bool?
}

let poses: [PoseSpec] = [
    PoseSpec(key: "idle", file: "00-idle.png", motion: "breathe", scale: nil, yOffset: nil, crossfade: nil),
    PoseSpec(key: "walk", file: "01-walk-1.png", motion: "walk", scale: nil, yOffset: nil, crossfade: false),
    PoseSpec(key: "walkAlt", file: "02-walk-2.png", motion: "walk", scale: nil, yOffset: nil, crossfade: false),
    PoseSpec(key: "jump", file: "03-jump.png", motion: "jump", scale: 1.04, yOffset: 18, crossfade: false),
    PoseSpec(key: "fall", file: "04-fall.png", motion: "fall", scale: 1.04, yOffset: 6, crossfade: false),
    PoseSpec(key: "sit", file: "05-sit.png", motion: "sit", scale: nil, yOffset: nil, crossfade: nil),
    PoseSpec(key: "sleep", file: "06-sleep.png", motion: "sleep", scale: 0.94, yOffset: -3, crossfade: nil),
    PoseSpec(key: "groom", file: "07-wave.png", motion: "groom", scale: nil, yOffset: nil, crossfade: nil),
    PoseSpec(key: "happy", file: "08-happy.png", motion: "happy", scale: nil, yOffset: nil, crossfade: nil),
    PoseSpec(key: "alert", file: "09-alert.png", motion: "alert", scale: nil, yOffset: nil, crossfade: false),
    PoseSpec(key: "play", file: "10-play.png", motion: "play", scale: 1.04, yOffset: nil, crossfade: nil),
    PoseSpec(key: "peek", file: "11-peek.png", motion: "peek", scale: 1.02, yOffset: -8, crossfade: nil)
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sheetURL = root.appendingPathComponent("Assets/Pets/KohakuMori/kohaku-mori-pose-sheet-chroma.png")
let outputRoots = [
    root.appendingPathComponent("Assets/Pets/KohakuMori", isDirectory: true),
    root.appendingPathComponent("Sources/AIPet/Resources/Pets/KohakuMori", isDirectory: true)
]

guard let sheet = NSImage(contentsOf: sheetURL),
      let cgImage = sheet.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Could not load Kohaku Mori pose sheet")
}

for outputRoot in outputRoots {
    let posesURL = outputRoot.appendingPathComponent("poses", isDirectory: true)
    try FileManager.default.createDirectory(at: posesURL, withIntermediateDirectories: true)

    for (index, pose) in poses.enumerated() {
        let cropped = try cropPose(from: cgImage, index: index)
        try writePNG(cropped, to: posesURL.appendingPathComponent(pose.file))
    }
}

func cropPose(from image: CGImage, index: Int) throws -> NSImage {
    let columns = 4
    let rows = 3
    let cellWidth = image.width / columns
    let cellHeight = image.height / rows
    let column = index % columns
    let row = index / columns
    let cropRect = CGRect(
        x: column * cellWidth,
        y: row * cellHeight,
        width: cellWidth,
        height: cellHeight
    )

    guard let cell = image.cropping(to: cropRect) else {
        throw NSError(domain: "KohakuMoriImport", code: 1)
    }

    let transparent = try removeSmallComponents(from: removeGreen(from: cell), minimumArea: 1_200)
    let bounds = alphaBounds(in: transparent) ?? CGRect(x: 0, y: 0, width: transparent.width, height: transparent.height)
    let padded = bounds.insetBy(dx: -28, dy: -28).intersection(CGRect(x: 0, y: 0, width: transparent.width, height: transparent.height))
    guard let subject = transparent.cropping(to: padded) else {
        throw NSError(domain: "KohakuMoriImport", code: 2)
    }

    let canvasSize = 512
    let bytesPerRow = canvasSize * 4
    var pixels = [UInt8](repeating: 0, count: canvasSize * bytesPerRow)
    guard let context = CGContext(
        data: &pixels,
        width: canvasSize,
        height: canvasSize,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "KohakuMoriImport", code: 3)
    }

    context.interpolationQuality = .high
    let maxSide: CGFloat = index == 11 ? 330 : 390
    let scale = min(maxSide / CGFloat(subject.width), maxSide / CGFloat(subject.height))
    let drawSize = CGSize(width: CGFloat(subject.width) * scale, height: CGFloat(subject.height) * scale)
    let x = (CGFloat(canvasSize) - drawSize.width) / 2
    let y: CGFloat = index == 11 ? 122 : 72
    context.draw(subject, in: CGRect(x: x, y: y, width: drawSize.width, height: drawSize.height))

    guard let output = context.makeImage() else {
        throw NSError(domain: "KohakuMoriImport", code: 4)
    }
    return NSImage(cgImage: output, size: CGSize(width: canvasSize, height: canvasSize))
}

func removeGreen(from image: CGImage) throws -> CGImage {
    let width = image.width
    let height = image.height
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
        throw NSError(domain: "KohakuMoriImport", code: 5)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    for y in 0..<height {
        for x in 0..<width {
            let i = y * bytesPerRow + x * 4
            let r = Int(pixels[i])
            let g = Int(pixels[i + 1])
            let b = Int(pixels[i + 2])
            let greenDominance = g - max(r, b)
            let chromaLike = g > 130 && CGFloat(g) > CGFloat(max(r, b)) * 1.34
            if chromaLike && greenDominance > 24 {
                let alpha = max(0, min(255, 255 - (greenDominance - 24) * 7))
                pixels[i + 3] = UInt8(alpha)
                if alpha < 220 {
                    pixels[i] = UInt8(min(255, max(0, r + 24)))
                    pixels[i + 1] = UInt8(min(255, max(0, g - 72)))
                    pixels[i + 2] = UInt8(min(255, max(0, b + 20)))
                }
            } else if g > 90 && greenDominance > 18 && b < g - 12 {
                pixels[i + 1] = UInt8(max(0, g - min(38, greenDominance)))
            }
        }
    }

    guard let output = context.makeImage() else {
        throw NSError(domain: "KohakuMoriImport", code: 6)
    }
    return output
}

func alphaBounds(in image: CGImage) -> CGRect? {
    let width = image.width
    let height = image.height
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
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0..<height {
        for x in 0..<width {
            let alpha = pixels[y * bytesPerRow + x * 4 + 3]
            guard alpha > 24 else { continue }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { return nil }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func removeSmallComponents(from image: CGImage, minimumArea: Int) throws -> CGImage {
    let width = image.width
    let height = image.height
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
        throw NSError(domain: "KohakuMoriImport", code: 8)
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var visited = [Bool](repeating: false, count: width * height)
    let directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]

    for y in 0..<height {
        for x in 0..<width {
            let startIndex = y * width + x
            guard !visited[startIndex], pixels[y * bytesPerRow + x * 4 + 3] > 24 else { continue }

            var stack = [(x, y)]
            var component: [(Int, Int)] = []
            visited[startIndex] = true

            while let point = stack.popLast() {
                component.append(point)
                for direction in directions {
                    let nx = point.0 + direction.0
                    let ny = point.1 + direction.1
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let index = ny * width + nx
                    guard !visited[index] else { continue }
                    visited[index] = true
                    if pixels[ny * bytesPerRow + nx * 4 + 3] > 24 {
                        stack.append((nx, ny))
                    }
                }
            }

            if component.count < minimumArea {
                for point in component {
                    pixels[point.1 * bytesPerRow + point.0 * 4 + 3] = 0
                }
            }
        }
    }

    guard let output = context.makeImage() else {
        throw NSError(domain: "KohakuMoriImport", code: 9)
    }
    return output
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "KohakuMoriImport", code: 7)
    }
    try data.write(to: url, options: [.atomic])
}
