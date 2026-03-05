//
//  TunnelConfigValidatorTests.swift
//  tnl_ctrl_tests
//
//  Tests for TunnelConfigValidator covering all validation paths.
//

@testable import tnl_ctrl
import XCTest

@MainActor
final class TunnelConfigValidatorTests: XCTestCase {
    func testEmptyServicesReturnsError() {
        let config = TunnelConfig()
        let result = TunnelConfigValidator.validate(config: config, services: [])

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertTrue(result.errors[0].message.contains("No services"))
    }

    func testSelectedServiceNotFoundReturnsError() {
        let config = TunnelConfig(selectedServiceId: UUID())
        let service = Service(name: "Test", protocol: .vless, server: "example.com", port: 443)
        let result = TunnelConfigValidator.validate(config: config, services: [service])

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors[0].message.contains("no longer exists"))
    }

    func testValidFullTunnelNoIssues() {
        let service = Service(name: "Test", protocol: .vless, server: "example.com", port: 443)
        let config = TunnelConfig(mode: .full, selectedServiceId: service.id)
        let result = TunnelConfigValidator.validate(config: config, services: [service])

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testChainEnabledEmptyChainReturnsWarning() {
        let service = Service(name: "Test", protocol: .vless, server: "example.com", port: 443)
        let config = TunnelConfig(chainEnabled: true, chain: [])
        let result = TunnelConfigValidator.validate(config: config, services: [service])

        XCTAssertTrue(result.isValid) // Warning, not error
        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.warnings[0].message.contains("empty"))
    }

    func testChainWithMissingServiceReturnsError() {
        let service = Service(name: "Test", protocol: .vless, server: "example.com", port: 443)
        let missingId = UUID()
        let config = TunnelConfig(chainEnabled: true, chain: [service.id, missingId])
        let result = TunnelConfigValidator.validate(config: config, services: [service])

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors[0].message.contains("no longer exists"))
    }

    func testChainWithDuplicatesReturnsWarning() {
        let service = Service(name: "Test", protocol: .vless, server: "example.com", port: 443)
        let config = TunnelConfig(chainEnabled: true, chain: [service.id, service.id])
        let result = TunnelConfigValidator.validate(config: config, services: [service])

        XCTAssertTrue(result.hasWarnings)
        XCTAssertTrue(result.warnings.contains { $0.message.contains("duplicate") })
    }

    func testSplitTunnelEmptyRulesReturnsInfo() {
        let service = Service(name: "Test", protocol: .vless, server: "example.com", port: 443)
        let config = TunnelConfig(mode: .split, rules: [])
        let result = TunnelConfigValidator.validate(config: config, services: [service])

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertTrue(result.issues[0].message.contains("No routing rules"))
    }

    func testSplitTunnelWithConflictingRules() {
        let service = Service(name: "Test", protocol: .vless, server: "example.com", port: 443)
        let rules = [
            RoutingRule(type: .domain, value: "test.com", outbound: .proxy),
            RoutingRule(type: .domain, value: "test.com", outbound: .proxy)
        ]
        let config = TunnelConfig(mode: .split, rules: rules)
        let result = TunnelConfigValidator.validate(config: config, services: [service])

        // Should include conflict detection issues
        XCTAssertFalse(result.issues.isEmpty)
        XCTAssertTrue(result.errors.contains { $0.message.contains("Duplicate") })
    }

    func testValidationResultComputedProperties() {
        let issues = [
            TunnelConfigValidator.ValidationIssue(severity: .error, message: "Error 1"),
            TunnelConfigValidator.ValidationIssue(severity: .warning, message: "Warning 1"),
            TunnelConfigValidator.ValidationIssue(severity: .info, message: "Info 1"),
        ]
        let result = TunnelConfigValidator.ValidationResult(issues: issues)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertEqual(result.errors.count, 1)
        XCTAssertEqual(result.warnings.count, 1)
    }

    func testEmptyValidationResultIsValid() {
        let result = TunnelConfigValidator.ValidationResult.valid

        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.hasWarnings)
        XCTAssertTrue(result.errors.isEmpty)
    }
}
