//
//  TunnelConfigValidator.swift
//  TunnelMaster
//

import Foundation

struct TunnelConfigValidator {
    // MARK: - Types

    enum ValidationSeverity: Sendable {
        case error
        case warning
        case info
    }

    struct ValidationIssue: Identifiable, Sendable {
        let id = UUID()
        let severity: ValidationSeverity
        let message: String
        let suggestion: String?

        init(severity: ValidationSeverity, message: String, suggestion: String? = nil) {
            self.severity = severity
            self.message = message
            self.suggestion = suggestion
        }

        var icon: String {
            switch severity {
            case .error: "xmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            }
        }
    }

    struct ValidationResult: Sendable {
        let issues: [ValidationIssue]

        var isValid: Bool {
            !issues.contains { $0.severity == .error }
        }

        var hasWarnings: Bool {
            issues.contains { $0.severity == .warning }
        }

        var errors: [ValidationIssue] {
            issues.filter { $0.severity == .error }
        }

        var warnings: [ValidationIssue] {
            issues.filter { $0.severity == .warning }
        }

        static let valid = ValidationResult(issues: [])
    }

    // MARK: - Validation

    static func validate(config: TunnelConfig, services: [Service]) -> ValidationResult {
        var issues: [ValidationIssue] = []

        // Check selected service
        let enabledServices = services.filter(\.isEnabled)

        if enabledServices.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "No enabled services available",
                suggestion: "Enable at least one service in the Services tab"
            ))
        } else if let selectedId = config.selectedServiceId {
            if let service = services.first(where: { $0.id == selectedId }) {
                if !service.isEnabled {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "Selected service \"\(service.name)\" is disabled",
                        suggestion: "Enable the service or select a different one"
                    ))
                }
            } else {
                issues.append(ValidationIssue(
                    severity: .error,
                    message: "Selected service no longer exists",
                    suggestion: "Select a different service"
                ))
            }
        }

        // Check chain configuration
        if config.chainEnabled {
            if config.chain.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    message: "Chain is enabled but empty",
                    suggestion: "Add services to the chain or disable chaining"
                ))
            } else {
                // Check each service in chain
                for (index, serviceId) in config.chain.enumerated() {
                    if let service = services.first(where: { $0.id == serviceId }) {
                        if !service.isEnabled {
                            issues.append(ValidationIssue(
                                severity: .warning,
                                message: "Chain service #\(index + 1) \"\(service.name)\" is disabled",
                                suggestion: "Enable the service or remove it from the chain"
                            ))
                        }
                    } else {
                        issues.append(ValidationIssue(
                            severity: .error,
                            message: "Chain service #\(index + 1) no longer exists",
                            suggestion: "Remove the missing service from the chain"
                        ))
                    }
                }

                // Check for duplicates in chain
                let duplicates = findDuplicates(in: config.chain)
                if !duplicates.isEmpty {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "Chain contains duplicate services",
                        suggestion: "Remove duplicate entries for cleaner configuration"
                    ))
                }
            }
        }

        // Check split tunnel rules
        if config.mode == .split {
            if config.rules.isEmpty {
                issues.append(ValidationIssue(
                    severity: .info,
                    message: "No routing rules configured",
                    suggestion: "Add rules to control which traffic goes through the proxy"
                ))
            } else {
                // Check for duplicate rules
                let duplicateRules = findDuplicateRules(in: config.rules)
                for rule in duplicateRules {
                    issues.append(ValidationIssue(
                        severity: .warning,
                        message: "Duplicate rule: \(rule.type.displayName) \"\(rule.value)\"",
                        suggestion: "Remove duplicate rules"
                    ))
                }
            }
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - Helpers

    private static func findDuplicates(in array: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var duplicates: [UUID] = []
        for item in array {
            if seen.contains(item) {
                duplicates.append(item)
            } else {
                seen.insert(item)
            }
        }
        return duplicates
    }

    private static func findDuplicateRules(in rules: [RoutingRule]) -> [RoutingRule] {
        var seen = Set<String>()
        var duplicates: [RoutingRule] = []
        for rule in rules {
            let key = "\(rule.type.rawValue):\(rule.value.lowercased())"
            if seen.contains(key) {
                duplicates.append(rule)
            } else {
                seen.insert(key)
            }
        }
        return duplicates
    }
}
