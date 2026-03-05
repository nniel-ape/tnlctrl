//
//  TunnelConfigValidator.swift
//  tnl_ctrl
//

import Foundation

enum TunnelConfigValidator {
    // MARK: - Types

    enum ValidationSeverity {
        case error
        case warning
        case info
    }

    struct ValidationIssue: Identifiable {
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

    struct ValidationResult {
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

        // Check services exist
        if services.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                message: "No services available",
                suggestion: "Add at least one service in the Services tab"
            ))
        } else if let selectedId = config.selectedServiceId {
            if !services.contains(where: { $0.id == selectedId }) {
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
                // Check each service in chain exists
                for (index, serviceId) in config.chain.enumerated()
                    where !services.contains(where: { $0.id == serviceId }) {
                    issues.append(ValidationIssue(
                        severity: .error,
                        message: "Chain service #\(index + 1) no longer exists",
                        suggestion: "Remove the missing service from the chain"
                    ))
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
                // Check for conflicts using the conflict detector
                let conflicts = RuleConflictDetector.detectConflicts(in: config.rules)
                for conflict in conflicts {
                    issues.append(ValidationIssue(
                        severity: conflict.severity.validationSeverity,
                        message: conflict.explanation,
                        suggestion: conflict.suggestion
                    ))
                }
            }
        }

        return ValidationResult(issues: issues)
    }

    // MARK: - Helpers

    private static func findDuplicates(in array: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return array.filter { !seen.insert($0).inserted }
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
