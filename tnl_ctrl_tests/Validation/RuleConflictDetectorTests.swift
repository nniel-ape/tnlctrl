//
//  RuleConflictDetectorTests.swift
//  tnl_ctrl_tests
//
//  Tests for RuleConflictDetector.
//

@testable import tnl_ctrl
import XCTest

@MainActor
final class RuleConflictDetectorTests: XCTestCase {
    func testDetectExactDuplicate() {
        let rules = [
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy),
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy)
        ]

        let conflicts = RuleConflictDetector.detectConflicts(in: rules)

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0].type, .exactDuplicate)
        XCTAssertEqual(conflicts[0].severity, .error)
    }

    func testDetectOutboundConflict() {
        let rules = [
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy),
            RoutingRule(type: .domain, value: "example.com", outbound: .direct)
        ]

        let conflicts = RuleConflictDetector.detectConflicts(in: rules)

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0].type, .outboundConflict)
        XCTAssertEqual(conflicts[0].severity, .warning)
    }

    func testDetectDomainShadowing() {
        let rules = [
            RoutingRule(type: .domainSuffix, value: "google.com", outbound: .proxy),
            RoutingRule(type: .domain, value: "mail.google.com", outbound: .direct)
        ]

        let conflicts = RuleConflictDetector.detectConflicts(in: rules)

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0].type, .shadowedRule)
        XCTAssertEqual(conflicts[0].severity, .info)
    }

    func testDetectOverlappingDomain() {
        let rules = [
            RoutingRule(type: .domain, value: "google.com", outbound: .direct),
            RoutingRule(type: .domainSuffix, value: "google.com", outbound: .proxy)
        ]

        let conflicts = RuleConflictDetector.detectConflicts(in: rules)

        XCTAssertEqual(conflicts.count, 1)
        XCTAssertEqual(conflicts[0].type, .overlappingDomain)
        XCTAssertEqual(conflicts[0].severity, .info)
    }

    func testNoConflictsForDifferentRules() {
        let rules = [
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy),
            RoutingRule(type: .domain, value: "different.com", outbound: .direct),
            RoutingRule(type: .ipCidr, value: "192.168.0.0/16", outbound: .direct)
        ]

        let conflicts = RuleConflictDetector.detectConflicts(in: rules)

        XCTAssertEqual(conflicts.count, 0)
    }

    func testDisabledRulesIgnored() {
        let rules = [
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy, isEnabled: true),
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy, isEnabled: false)
        ]

        let conflicts = RuleConflictDetector.detectConflicts(in: rules)

        XCTAssertEqual(conflicts.count, 0) // Disabled rules should be ignored
    }

    func testDetectConflictForNewRule() {
        let existingRules = [
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy)
        ]

        let newRule = RoutingRule(type: .domain, value: "example.com", outbound: .proxy)

        let conflict = RuleConflictDetector.detectConflictForNewRule(newRule, in: existingRules)

        XCTAssertNotNil(conflict)
        XCTAssertEqual(conflict?.type, .exactDuplicate)
    }

    func testNoConflictForNewRule() {
        let existingRules = [
            RoutingRule(type: .domain, value: "example.com", outbound: .proxy)
        ]

        let newRule = RoutingRule(type: .domain, value: "different.com", outbound: .proxy)

        let conflict = RuleConflictDetector.detectConflictForNewRule(newRule, in: existingRules)

        XCTAssertNil(conflict)
    }
}
