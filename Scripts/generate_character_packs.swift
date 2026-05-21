import AppKit
import Foundation

struct VariantTheme {
    let id: String
    let displayName: String
    let folderName: String
    let persona: String
    let hairHue: CGFloat
    let hairSaturation: CGFloat
    let accentHue: CGFloat
    let accentSaturation: CGFloat
    let darkLift: CGFloat
}

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

let themes = [
    VariantTheme(
        id: "neon-mika",
        displayName: "미카 네온",
        folderName: "NeonMika",
        persona: "너는 사용자의 macOS 화면 위를 누비는 오리지널 사이버 팝 아이돌 '미카 네온'이야. 청록빛 네온 헤어, 보랏빛 눈매, 전자 별 장식이 시그니처야. 한국어로 밝고 리듬감 있게 답하되, 사용자의 요청은 정확히 처리하고 과한 애교나 유아적인 말투는 피한다.",
        hairHue: 0.50,
        hairSaturation: 0.72,
        accentHue: 0.86,
        accentSaturation: 0.82,
        darkLift: 0.04
    ),
    VariantTheme(
        id: "velvet-rin",
        displayName: "린 벨벳",
        folderName: "VelvetRin",
        persona: "너는 사용자의 macOS 화면에 조용히 머무는 오리지널 고딕 로즈 마법사 '린 벨벳'이야. 와인빛 머리, 장미색 눈, 검정과 금빛 장식이 시그니처야. 한국어로 차분하고 우아하게 답하되, 필요한 정보는 또렷하게 찾아 정리한다.",
        hairHue: 0.94,
        hairSaturation: 0.68,
        accentHue: 0.98,
        accentSaturation: 0.72,
        darkLift: -0.02
    ),
    VariantTheme(
        id: "sora-amane",
        displayName: "아마네 소라",
        folderName: "AmaneSora",
        persona: "너는 사용자의 macOS 화면 위에서 반짝이는 오리지널 별빛 카페 연금술사 '아마네 소라'야. 복숭아빛 머리, 라벤더 눈, 따뜻한 금빛 별 장식이 시그니처야. 한국어로 포근하고 세심하게 답하되, 정보 요청은 현실적인 근거와 선택지를 함께 제시한다.",
        hairHue: 0.02,
        hairSaturation: 0.42,
        accentHue: 0.12,
        accentSaturation: 0.82,
        darkLift: 0.12
    )
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourcePack = root.appendingPathComponent("Sources/AIPet/Resources/Pets/LunaSera/poses", isDirectory: true)
let outputRoots = [
    root.appendingPathComponent("Sources/AIPet/Resources/Pets", isDirectory: true),
    root.appendingPathComponent("Assets/Pets", isDirectory: true)
]

for theme in themes {
    for outputRoot in outputRoots {
        let packURL = outputRoot.appendingPathComponent(theme.folderName, isDirectory: true)
        let posesURL = packURL.appendingPathComponent("poses", isDirectory: true)
        try FileManager.default.createDirectory(at: posesURL, withIntermediateDirectories: true)

        for pose in poses {
            let source = sourcePack.appendingPathComponent(pose.file)
            let image = try recoloredImage(from: source, theme: theme)
            try writePNG(image, to: posesURL.appendingPathComponent(pose.file))
        }

        try manifest(for: theme).write(to: packURL.appendingPathComponent("manifest.json"), atomically: true, encoding: .utf8)
    }
}

func recoloredImage(from url: URL, theme: VariantTheme) throws -> NSImage {
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(domain: "GenerateCharacterPacks", code: 1)
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
        throw NSError(domain: "GenerateCharacterPacks", code: 2)
    }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    for y in 0..<height {
        for x in 0..<width {
            let i = y * bytesPerRow + x * 4
            let alpha = CGFloat(pixels[i + 3]) / 255
            guard alpha > 0.02 else { continue }

            var r = CGFloat(pixels[i]) / 255
            var g = CGFloat(pixels[i + 1]) / 255
            var b = CGFloat(pixels[i + 2]) / 255
            let hsv = rgbToHSV(r: r, g: g, b: b)

            if isSkin(r: r, g: g, b: b, hsv: hsv) {
                continue
            } else if hsv.value < 0.18 && alpha > 0.35 {
                let lifted = max(0, min(1, hsv.value + theme.darkLift))
                let tinted = hsvToRGB(h: theme.accentHue, s: min(0.45, theme.accentSaturation * 0.55), v: lifted)
                r = mix(r, tinted.r, 0.22)
                g = mix(g, tinted.g, 0.22)
                b = mix(b, tinted.b, 0.22)
            } else if isHairOrEye(hsv: hsv, r: r, g: g, b: b) {
                let saturation = min(1, max(0.18, theme.hairSaturation * (0.75 + hsv.saturation * 0.35)))
                let value = min(1, max(0.10, hsv.value * 1.03))
                let recolored = hsvToRGB(h: theme.hairHue, s: saturation, v: value)
                r = mix(r, recolored.r, 0.72)
                g = mix(g, recolored.g, 0.72)
                b = mix(b, recolored.b, 0.72)
            } else if hsv.saturation > 0.30 {
                let recolored = hsvToRGB(h: theme.accentHue, s: min(1, theme.accentSaturation), v: min(1, hsv.value * 1.02))
                r = mix(r, recolored.r, 0.38)
                g = mix(g, recolored.g, 0.38)
                b = mix(b, recolored.b, 0.38)
            }

            pixels[i] = UInt8(max(0, min(255, round(r * 255))))
            pixels[i + 1] = UInt8(max(0, min(255, round(g * 255))))
            pixels[i + 2] = UInt8(max(0, min(255, round(b * 255))))
        }
    }

    guard let outputContext = CGContext(
        data: &pixels,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let output = outputContext.makeImage() else {
        throw NSError(domain: "GenerateCharacterPacks", code: 3)
    }

    return NSImage(cgImage: output, size: CGSize(width: width, height: height))
}

func isSkin(r: CGFloat, g: CGFloat, b: CGFloat, hsv: (hue: CGFloat, saturation: CGFloat, value: CGFloat)) -> Bool {
    r > 0.55 && g > 0.34 && b > 0.25 && r > g && r > b * 1.06 && g >= b * 0.78 && hsv.saturation < 0.48
}

func isHairOrEye(hsv: (hue: CGFloat, saturation: CGFloat, value: CGFloat), r: CGFloat, g: CGFloat, b: CGFloat) -> Bool {
    guard hsv.value > 0.22 else { return false }
    let purpleRange = hsv.hue > 0.63 && hsv.hue < 0.86
    let tealRange = hsv.hue > 0.42 && hsv.hue < 0.58
    let lightLavender = r > 0.48 && b > 0.52 && abs(r - b) < 0.34 && b >= g * 0.92
    return (hsv.saturation > 0.10 && (purpleRange || tealRange)) || lightLavender
}

func rgbToHSV(r: CGFloat, g: CGFloat, b: CGFloat) -> (hue: CGFloat, saturation: CGFloat, value: CGFloat) {
    let maxValue = max(r, g, b)
    let minValue = min(r, g, b)
    let delta = maxValue - minValue
    var hue: CGFloat = 0
    if delta > 0.0001 {
        if maxValue == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxValue == g {
            hue = ((b - r) / delta) + 2
        } else {
            hue = ((r - g) / delta) + 4
        }
        hue /= 6
        if hue < 0 { hue += 1 }
    }
    let saturation = maxValue == 0 ? 0 : delta / maxValue
    return (hue, saturation, maxValue)
}

func hsvToRGB(h: CGFloat, s: CGFloat, v: CGFloat) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
    let i = floor(h * 6)
    let f = h * 6 - i
    let p = v * (1 - s)
    let q = v * (1 - f * s)
    let t = v * (1 - (1 - f) * s)
    switch Int(i).modulo(6) {
    case 0: return (v, t, p)
    case 1: return (q, v, p)
    case 2: return (p, v, t)
    case 3: return (p, q, v)
    case 4: return (t, p, v)
    default: return (v, p, q)
    }
}

func mix(_ a: CGFloat, _ b: CGFloat, _ amount: CGFloat) -> CGFloat {
    a * (1 - amount) + b * amount
}

extension Int {
    func modulo(_ divisor: Int) -> Int {
        let result = self % divisor
        return result >= 0 ? result : result + divisor
    }
}

func manifest(for theme: VariantTheme) -> String {
    let poseEntries = poses.map { pose -> String in
        var fields = [
            "\"file\": \"poses/\(pose.file)\"",
            "\"motion\": \"\(pose.motion)\""
        ]
        if let scale = pose.scale {
            fields.append("\"scale\": \(String(format: "%.2f", scale))")
        }
        if let yOffset = pose.yOffset {
            fields.append("\"yOffset\": \(Int(yOffset))")
        }
        if let crossfade = pose.crossfade {
            fields.append("\"crossfade\": \(crossfade ? "true" : "false")")
        }
        return "    \"\(pose.key)\": { \(fields.joined(separator: ", ")) }"
    }.joined(separator: ",\n")

    return """
    {
      "id": "\(theme.id)",
      "displayName": "\(theme.displayName)",
      "version": 1,
      "author": "Luma",
      "persona": "\(theme.persona)",
      "defaultPose": "idle",
      "canvasSize": 512,
      "render": {
        "baseSize": 202,
        "baseYOffset": 9
      },
      "poses": {
    \(poseEntries)
      }
    }
    """
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateCharacterPacks", code: 4)
    }
    try data.write(to: url, options: [.atomic])
}
