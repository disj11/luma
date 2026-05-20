import AppKit

struct CharacterPackValidationReport {
    var pack: LoadedCharacterPack?
    var errors: [String]
    var warnings: [String]
    var details: [String]

    var isValid: Bool {
        errors.isEmpty && pack != nil
    }

    var summary: String {
        var lines: [String] = []
        if let pack {
            lines.append("캐릭터: \(pack.manifest.displayName) (\(pack.manifest.id))")
            lines.append("포즈: \(pack.images.count)개")
        }
        if errors.isEmpty {
            lines.append("오류: 없음")
        } else {
            lines.append("오류:")
            lines.append(contentsOf: errors.map { "- \($0)" })
        }
        if !warnings.isEmpty {
            lines.append("주의:")
            lines.append(contentsOf: warnings.map { "- \($0)" })
        }
        if !details.isEmpty {
            lines.append("세부:")
            lines.append(contentsOf: details.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}

enum CharacterPackValidator {
    static let requiredPoses: [PoseKey] = [.idle, .walk, .jump, .fall, .sit, .sleep, .alert]
    static let recommendedPoses: [PoseKey] = [.walkAlt, .groom, .happy, .play, .peek]

    static func validate(folder url: URL) -> CharacterPackValidationReport {
        var errors: [String] = []
        var warnings: [String] = []
        var details: [String] = []

        let manifestURL = url.appendingPathComponent("manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path) else {
            return CharacterPackValidationReport(
                pack: nil,
                errors: ["manifest.json이 없습니다."],
                warnings: [],
                details: []
            )
        }

        guard let pack = LoadedCharacterPack(manifestURL: manifestURL, isBundled: false) else {
            return CharacterPackValidationReport(
                pack: nil,
                errors: ["manifest.json 또는 포즈 PNG를 읽을 수 없습니다."],
                warnings: [],
                details: []
            )
        }

        for pose in requiredPoses where pack.images[pose] == nil {
            errors.append("필수 포즈 \(pose.rawValue)가 없습니다.")
        }

        for pose in recommendedPoses where pack.images[pose] == nil {
            warnings.append("권장 포즈 \(pose.rawValue)가 없습니다.")
        }

        if pack.manifest.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("displayName이 비어 있습니다.")
        }

        let supportOffsets = PoseKey.allCases.compactMap { pose -> CGFloat? in
            guard pack.images[pose] != nil else { return nil }
            return pack.visibleBoundsInPetWindow(for: pose, windowSize: CGSize(width: 220, height: 220))?.minY
        }
        if let minOffset = supportOffsets.min(), let maxOffset = supportOffsets.max() {
            let spread = maxOffset - minOffset
            details.append("포즈별 하단 기준점 편차: \(Int(spread.rounded()))px")
            if spread > 12 {
                warnings.append("포즈별 하단 기준점 편차가 큽니다. 걷기/앉기 중 떠 보일 수 있습니다.")
            }
        }

        for pose in PoseKey.allCases {
            guard let bounds = pack.alphaBounds[pose] else { continue }
            if bounds.width < 12 || bounds.height < 12 {
                warnings.append("\(pose.rawValue) 포즈의 실제 이미지 영역이 너무 작습니다.")
            }
            if bounds.minX <= 1 || bounds.minY <= 1 {
                warnings.append("\(pose.rawValue) 포즈가 캔버스 가장자리에 너무 가깝습니다.")
            }
        }

        return CharacterPackValidationReport(pack: pack, errors: errors, warnings: warnings, details: details)
    }
}
