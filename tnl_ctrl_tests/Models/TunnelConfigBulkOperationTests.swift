//
//  TunnelConfigBulkOperationTests.swift
//  tnl_ctrl_tests
//
//  Tests for TunnelConfig bulk mutation helpers.
//

@testable import tnl_ctrl
import XCTest

final class TunnelConfigBulkOperationTests: XCTestCase {
    func testUpdateRulesAppliesMutationAndUpdatesTimestamp() {
        let rule = RoutingRule(
            type: .domain, value: "example.com", outbound: .proxy,
            lastModified: Date.distantPast
        )
        var config = TunnelConfig(rules: [rule])

        config.updateRules(where: { $0.id == rule.id }, mutation: { $0.outbound = .direct })

        XCTAssertEqual(config.rules[0].outbound, .direct)
        XCTAssertTrue(config.rules[0].lastModified > Date.distantPast)
    }

    func testEnableDisableRules() {
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, isEnabled: false)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy, isEnabled: true)
        var config = TunnelConfig(rules: [rule1, rule2])

        config.enableRules(Set([rule1.id]))
        XCTAssertTrue(config.rules[0].isEnabled)
        XCTAssertTrue(config.rules[1].isEnabled)

        config.disableRules(Set([rule1.id, rule2.id]))
        XCTAssertFalse(config.rules[0].isEnabled)
        XCTAssertFalse(config.rules[1].isEnabled)
    }

    func testSetOutboundForRules() {
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .direct)
        var config = TunnelConfig(rules: [rule1, rule2])

        config.setOutbound(.block, for: Set([rule1.id, rule2.id]))

        XCTAssertEqual(config.rules[0].outbound, .block)
        XCTAssertEqual(config.rules[1].outbound, .block)
    }

    func testMoveRulesToGroup() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy)
        var config = TunnelConfig(rules: [rule1, rule2])

        config.moveRulesToGroup(groupId, ids: Set([rule1.id]))

        XCTAssertEqual(config.rules[0].groupId, groupId)
        XCTAssertNil(config.rules[1].groupId)
    }

    func testAllRulesEnabledInGroup() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, isEnabled: true, groupId: groupId)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy, isEnabled: true, groupId: groupId)
        let group = RuleGroup(id: groupId, name: "Test", position: 0)
        let config = TunnelConfig(rules: [rule1, rule2], groups: [group])

        XCTAssertTrue(config.allRulesEnabled(in: groupId))
    }

    func testAllRulesEnabledFalseWhenOneMixed() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, isEnabled: true, groupId: groupId)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy, isEnabled: false, groupId: groupId)
        let group = RuleGroup(id: groupId, name: "Test", position: 0)
        let config = TunnelConfig(rules: [rule1, rule2], groups: [group])

        XCTAssertFalse(config.allRulesEnabled(in: groupId))
    }

    func testAllRulesEnabledFalseForEmptyGroup() {
        let groupId = UUID()
        let group = RuleGroup(id: groupId, name: "Empty", position: 0)
        let config = TunnelConfig(rules: [], groups: [group])

        XCTAssertFalse(config.allRulesEnabled(in: groupId))
    }

    func testSetGroupOutbound() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, groupId: groupId)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy, groupId: groupId)
        let ungrouped = RoutingRule(type: .domain, value: "c.com", outbound: .proxy)
        let group = RuleGroup(id: groupId, name: "Test", position: 0)
        var config = TunnelConfig(rules: [rule1, rule2, ungrouped], groups: [group])

        config.setGroupOutbound(groupId, outbound: .direct)

        XCTAssertEqual(config.rules[0].outbound, .direct)
        XCTAssertEqual(config.rules[1].outbound, .direct)
        XCTAssertEqual(config.rules[2].outbound, .proxy) // Ungrouped unaffected
    }

    func testSetGroupEnabled() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, isEnabled: true, groupId: groupId)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy, isEnabled: true, groupId: groupId)
        let group = RuleGroup(id: groupId, name: "Test", position: 0)
        var config = TunnelConfig(rules: [rule1, rule2], groups: [group])

        config.setGroupEnabled(groupId, enabled: false)
        XCTAssertFalse(config.rules[0].isEnabled)
        XCTAssertFalse(config.rules[1].isEnabled)

        config.setGroupEnabled(groupId, enabled: true)
        XCTAssertTrue(config.rules[0].isEnabled)
        XCTAssertTrue(config.rules[1].isEnabled)
    }

    func testToggleGroupExpanded() {
        let groupId = UUID()
        let group = RuleGroup(id: groupId, name: "Test", isExpanded: true, position: 0)
        var config = TunnelConfig(groups: [group])

        config.toggleGroupExpanded(groupId)
        XCTAssertFalse(config.groups[0].isExpanded)

        config.toggleGroupExpanded(groupId)
        XCTAssertTrue(config.groups[0].isExpanded)
    }

    func testToggleGroupExpandedMissingGroupNoOp() {
        var config = TunnelConfig(groups: [])
        config.toggleGroupExpanded(UUID()) // Should not crash
        XCTAssertTrue(config.groups.isEmpty)
    }

    func testDeleteGroupUngroupsRules() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, groupId: groupId)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy, groupId: groupId)
        let ungrouped = RoutingRule(type: .domain, value: "c.com", outbound: .proxy)
        let group = RuleGroup(id: groupId, name: "Test", position: 0)
        var config = TunnelConfig(rules: [rule1, rule2, ungrouped], groups: [group])

        config.deleteGroup(groupId)

        XCTAssertTrue(config.groups.isEmpty)
        XCTAssertEqual(config.rules.count, 3)
        // All rules should be ungrouped now
        XCTAssertTrue(config.rules.allSatisfy { $0.groupId == nil })
    }
}
