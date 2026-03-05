//
//  RuleConflictDetector.swift
//  tnl_ctrl
//
//  Detects conflicts and overlaps in routing rules.
//

import Foundation

@MainActor
enum RuleConflictDetector {
    // MARK: - Types

    enum ConflictType: String, Codable {
        case exactDuplicate // Same type+value+outbound
        case outboundConflict // Same type+value, different outbound
        case shadowedRule // Rule will never match (earlier rule catches all)
        case overlappingDomain // e.g., "google.com" + "*.google.com"
    }

    enum Severity {
        case error // Must fix (exact duplicates)
        case warning // Should review (outbound conflicts)
        case info // Nice to know (potential shadowing)

        var validationSeverity: TunnelConfigValidator.ValidationSeverity {
            switch self {
            case .error: .error
            case .warning: .warning
            case .info: .info
            }
        }
    }

    struct Conflict: Identifiable {
        let id = UUID()
        let type: ConflictType
        let rule1: RoutingRule
        let rule2: RoutingRule
        let severity: Severity
        let explanation: String
        let suggestion: String
    }

    // MARK: - Detection

    static func detectConflicts(in rules: [RoutingRule]) -> [Conflict] {
        var conflicts: [Conflict] = []
        let enabledRules = rules.filter(\.isEnabled)

        // Check for duplicates and conflicts
        for i in 0 ..< enabledRules.count {
            for j in (i + 1) ..< enabledRules.count {
                let r1 = enabledRules[i]
                let r2 = enabledRules[j]

                // Exact duplicate
                if r1.type == r2.type, r1.value == r2.value, r1.outbound == r2.outbound {
                    conflicts.append(Conflict(
                        type: .exactDuplicate,
                        rule1: r1,
                        rule2: r2,
                        severity: .error,
                        explanation: "Duplicate rule: both rules match '\(r1.value)' and route to \(r1.outbound.displayName)",
                        suggestion: "Delete one of these rules"
                    ))
                }

                // Outbound conflict
                else if r1.type == r2.type, r1.value == r2.value, r1.outbound != r2.outbound {
                    conflicts.append(Conflict(
                        type: .outboundConflict,
                        rule1: r1,
                        rule2: r2,
                        severity: .warning,
                        explanation: "Conflicting outbounds: '\(r1.value)' routes to both "
                            + "\(r1.outbound.displayName) and \(r2.outbound.displayName)",
                        suggestion: "First matching rule wins. Consider merging or disabling one."
                    ))
                }

                // Domain shadowing (domainSuffix shadows domain)
                else if r1.type == .domainSuffix, r2.type == .domain {
                    if r2.value.hasSuffix(r1.value) || r2.value == r1.value {
                        conflicts.append(Conflict(
                            type: .shadowedRule,
                            rule1: r1,
                            rule2: r2,
                            severity: .info,
                            explanation: "Rule '\(r1.value)' (suffix) may shadow '\(r2.value)' (exact)",
                            suggestion: "Order matters: specific rules should come before broad rules"
                        ))
                    }
                }
                // Reverse: domain comes before domainSuffix that would match it
                else if r1.type == .domain, r2.type == .domainSuffix {
                    if r1.value.hasSuffix(r2.value) || r1.value == r2.value {
                        conflicts.append(Conflict(
                            type: .overlappingDomain,
                            rule1: r1,
                            rule2: r2,
                            severity: .info,
                            explanation: "Overlapping rules: exact '\(r1.value)' and suffix '\(r2.value)'",
                            suggestion: "This is OK: exact match comes first, suffix catches subdomains"
                        ))
                    }
                }
            }
        }

        return conflicts
    }

    /// Detect potential conflict for a new rule being added
    static func detectConflictForNewRule(_ newRule: RoutingRule, in existingRules: [RoutingRule]) -> Conflict? {
        guard newRule.isEnabled else { return nil }

        let enabledRules = existingRules.filter(\.isEnabled)

        for existingRule in enabledRules {
            // Exact duplicate
            if existingRule.type == newRule.type, existingRule.value == newRule.value, existingRule.outbound == newRule.outbound {
                return Conflict(
                    type: .exactDuplicate,
                    rule1: existingRule,
                    rule2: newRule,
                    severity: .error,
                    explanation: "Duplicate rule: this rule already exists",
                    suggestion: "This rule is identical to an existing rule"
                )
            }

            // Outbound conflict
            if existingRule.type == newRule.type, existingRule.value == newRule.value, existingRule.outbound != newRule.outbound {
                return Conflict(
                    type: .outboundConflict,
                    rule1: existingRule,
                    rule2: newRule,
                    severity: .warning,
                    explanation: "Conflicting outbounds: '\(newRule.value)' would route to both "
                        + "\(existingRule.outbound.displayName) and \(newRule.outbound.displayName)",
                    suggestion: "First matching rule wins"
                )
            }
        }

        return nil
    }
}
