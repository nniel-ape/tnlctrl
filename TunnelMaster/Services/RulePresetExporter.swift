//
//  RulePresetExporter.swift
//  TunnelMaster
//
//  Export and import rule presets as .tmpreset files.
//

import Foundation
import OSLog
import UniformTypeIdentifiers

private let logger = Logger(subsystem: "nniel.TunnelMaster", category: "RulePresetExporter")

// MARK: - Export Format

/// The exported preset file format
struct PresetExportFile: Codable {
    let version: Int
    let type: String
    let metadata: PresetMetadata
    let rules: [ExportedRule]

    struct PresetMetadata: Codable {
        let name: String
        let description: String
        let icon: String
        let color: String
        let author: String?
        let created: Date
        let ruleCount: Int
    }

    struct ExportedRule: Codable {
        let type: String
        let value: String
        let outbound: String
        let isEnabled: Bool
        let note: String?
    }
}

// MARK: - UTType Extension

extension UTType {
    static let tmpreset = UTType(exportedAs: "nniel.tunnelmaster.preset", conformingTo: .json)
}

// MARK: - Exporter

enum RulePresetExporter {
    static let fileExtension = "tmpreset"
    static let currentVersion = 1

    // MARK: - Export

    /// Export a preset to JSON data
    static func export(_ preset: RulePreset, author: String? = nil) throws -> Data {
        let exportedRules = preset.rules.map { rule in
            PresetExportFile.ExportedRule(
                type: rule.type.rawValue,
                value: rule.value,
                outbound: rule.outbound.rawValue,
                isEnabled: rule.isEnabled,
                note: rule.note
            )
        }

        let exportFile = PresetExportFile(
            version: currentVersion,
            type: "tunnelmaster-preset",
            metadata: PresetExportFile.PresetMetadata(
                name: preset.name,
                description: preset.description,
                icon: preset.icon,
                color: preset.color.rawValue,
                author: author,
                created: Date(),
                ruleCount: preset.rules.count
            ),
            rules: exportedRules
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(exportFile)
    }

    /// Export a preset to a file URL
    static func export(_ preset: RulePreset, to url: URL, author: String? = nil) throws {
        let data = try export(preset, author: author)
        try data.write(to: url)
        logger.info("Exported preset '\(preset.name)' to \(url.path)")
    }

    // MARK: - Import

    /// Import a preset from JSON data
    static func importPreset(from data: Data) throws -> RulePreset {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportFile = try decoder.decode(PresetExportFile.self, from: data)

        // Validate version
        guard exportFile.version <= currentVersion else {
            throw ImportError.unsupportedVersion(exportFile.version)
        }

        guard exportFile.type == "tunnelmaster-preset" else {
            throw ImportError.invalidFileType(exportFile.type)
        }

        // Convert rules
        let rules = try exportFile.rules.map { exported -> RoutingRule in
            guard let type = RuleType(rawValue: exported.type) else {
                throw ImportError.invalidRuleType(exported.type)
            }
            guard let outbound = RuleOutbound(rawValue: exported.outbound) else {
                throw ImportError.invalidOutbound(exported.outbound)
            }
            return RoutingRule(
                type: type,
                value: exported.value,
                outbound: outbound,
                isEnabled: exported.isEnabled,
                note: exported.note
            )
        }

        // Convert color
        let color = PresetColor(rawValue: exportFile.metadata.color) ?? .blue

        return RulePreset(
            name: exportFile.metadata.name,
            description: exportFile.metadata.description,
            rules: rules,
            isBuiltIn: false,
            icon: exportFile.metadata.icon,
            color: color
        )
    }

    /// Import a preset from a file URL
    static func importPreset(from url: URL) throws -> RulePreset {
        let data = try Data(contentsOf: url)
        let preset = try importPreset(from: data)
        logger.info("Imported preset '\(preset.name)' from \(url.path)")
        return preset
    }

    // MARK: - Validation

    /// Validate preset data without fully importing
    static func validate(data: Data) -> ValidationResult {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let exportFile = try decoder.decode(PresetExportFile.self, from: data)

            if exportFile.version > currentVersion {
                return ValidationResult(
                    isValid: false,
                    error: "Preset version \(exportFile.version) is newer than supported version \(currentVersion)"
                )
            }

            return ValidationResult(
                isValid: true,
                presetName: exportFile.metadata.name,
                ruleCount: exportFile.metadata.ruleCount,
                author: exportFile.metadata.author,
                created: exportFile.metadata.created
            )
        } catch {
            return ValidationResult(isValid: false, error: error.localizedDescription)
        }
    }

    struct ValidationResult {
        let isValid: Bool
        var presetName: String?
        var ruleCount: Int?
        var author: String?
        var created: Date?
        var error: String?
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case unsupportedVersion(Int)
        case invalidFileType(String)
        case invalidRuleType(String)
        case invalidOutbound(String)

        var errorDescription: String? {
            switch self {
            case let .unsupportedVersion(version):
                "Preset version \(version) is not supported. Please update TunnelMaster."
            case let .invalidFileType(type):
                "Invalid file type: \(type). Expected 'tunnelmaster-preset'."
            case let .invalidRuleType(type):
                "Unknown rule type: \(type)"
            case let .invalidOutbound(outbound):
                "Unknown outbound: \(outbound)"
            }
        }
    }
}

// MARK: - Export Multiple Rules

extension RulePresetExporter {
    /// Create a preset from selected rules for export
    static func createPreset(
        name: String,
        description: String,
        rules: [RoutingRule],
        icon: String = "list.bullet.rectangle",
        color: PresetColor = .blue
    ) -> RulePreset {
        RulePreset(
            name: name,
            description: description,
            rules: rules,
            isBuiltIn: false,
            icon: icon,
            color: color
        )
    }
}
