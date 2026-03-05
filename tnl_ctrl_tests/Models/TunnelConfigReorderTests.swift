//
//  TunnelConfigReorderTests.swift
//  tnl_ctrl_tests
//
//  Tests for TunnelConfig drag-and-drop reordering logic.
//

@testable import tnl_ctrl
import XCTest

final class TunnelConfigReorderTests: XCTestCase {
    // MARK: - moveRule

    func testMoveRuleToDifferentGroup() {
        let groupA = UUID()
        let groupB = UUID()
        let rule = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, groupId: groupA)
        var config = TunnelConfig(
            rules: [rule],
            groups: [
                RuleGroup(id: groupA, name: "A", position: 0),
                RuleGroup(id: groupB, name: "B", position: 1),
            ]
        )

        config.moveRule(rule.id, toGroup: groupB, atGroupIndex: 0)

        XCTAssertEqual(config.rules[0].groupId, groupB)
    }

    func testMoveRuleWithinSameGroup() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, groupId: groupId)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy, groupId: groupId)
        let rule3 = RoutingRule(type: .domain, value: "c.com", outbound: .proxy, groupId: groupId)
        var config = TunnelConfig(
            rules: [rule1, rule2, rule3],
            groups: [RuleGroup(id: groupId, name: "G", position: 0)]
        )

        // Move rule3 to index 0 within the group
        config.moveRule(rule3.id, toGroup: groupId, atGroupIndex: 0)

        XCTAssertEqual(config.rules[0].value, "c.com")
        XCTAssertEqual(config.rules.count, 3)
    }

    func testMoveRuleToUngrouped() {
        let groupId = UUID()
        let rule = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, groupId: groupId)
        let ungrouped = RoutingRule(type: .domain, value: "b.com", outbound: .proxy)
        var config = TunnelConfig(
            rules: [rule, ungrouped],
            groups: [RuleGroup(id: groupId, name: "G", position: 0)]
        )

        config.moveRule(rule.id, toGroup: nil, atGroupIndex: 0)

        XCTAssertNil(config.rules.first(where: { $0.id == rule.id })?.groupId)
    }

    func testMoveRuleToEmptyGroup() {
        let groupA = UUID()
        let groupB = UUID()
        let rule = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, groupId: groupA)
        var config = TunnelConfig(
            rules: [rule],
            groups: [
                RuleGroup(id: groupA, name: "A", position: 0),
                RuleGroup(id: groupB, name: "B (empty)", position: 1),
            ]
        )

        config.moveRule(rule.id, toGroup: groupB, atGroupIndex: 0)

        XCTAssertEqual(config.rules[0].groupId, groupB)
    }

    func testMoveRuleInvalidIdNoOp() {
        let rule = RoutingRule(type: .domain, value: "a.com", outbound: .proxy)
        var config = TunnelConfig(rules: [rule])

        config.moveRule(UUID(), toGroup: nil, atGroupIndex: 0)

        XCTAssertEqual(config.rules.count, 1)
        XCTAssertEqual(config.rules[0].id, rule.id)
    }

    // MARK: - moveRules (multiple)

    func testMoveMultipleRulesPreservesRelativeOrder() {
        let groupId = UUID()
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy)
        let rule3 = RoutingRule(type: .domain, value: "c.com", outbound: .proxy)
        var config = TunnelConfig(
            rules: [rule1, rule2, rule3],
            groups: [RuleGroup(id: groupId, name: "G", position: 0)]
        )

        config.moveRules([rule1.id, rule3.id], toGroup: groupId, atGroupIndex: 0)

        let movedRules = config.rules.filter { $0.groupId == groupId }
        XCTAssertEqual(movedRules.count, 2)
        // rule1 should come before rule3 (original order preserved)
        XCTAssertEqual(movedRules[0].value, "a.com")
        XCTAssertEqual(movedRules[1].value, "c.com")
    }

    func testMoveMultipleRulesAppendAtEnd() {
        let groupId = UUID()
        let existing = RoutingRule(type: .domain, value: "existing.com", outbound: .proxy, groupId: groupId)
        let rule1 = RoutingRule(type: .domain, value: "a.com", outbound: .proxy)
        let rule2 = RoutingRule(type: .domain, value: "b.com", outbound: .proxy)
        var config = TunnelConfig(
            rules: [existing, rule1, rule2],
            groups: [RuleGroup(id: groupId, name: "G", position: 0)]
        )

        // Append at end of group (index >= group size)
        config.moveRules([rule1.id, rule2.id], toGroup: groupId, atGroupIndex: 999)

        let groupRules = config.rules.filter { $0.groupId == groupId }
        XCTAssertEqual(groupRules.count, 3)
        XCTAssertEqual(groupRules[0].value, "existing.com")
        XCTAssertEqual(groupRules[1].value, "a.com")
        XCTAssertEqual(groupRules[2].value, "b.com")
    }

    // MARK: - moveGroup

    func testMoveGroupReordersAndRenormalizes() {
        let groupA = UUID()
        let groupB = UUID()
        let groupC = UUID()
        var config = TunnelConfig(
            groups: [
                RuleGroup(id: groupA, name: "A", position: 0),
                RuleGroup(id: groupB, name: "B", position: 1),
                RuleGroup(id: groupC, name: "C", position: 2),
            ]
        )

        // Move C to position 0
        config.moveGroup(groupC, toPosition: 0)

        XCTAssertEqual(config.groups[0].id, groupC)
        XCTAssertEqual(config.groups[1].id, groupA)
        XCTAssertEqual(config.groups[2].id, groupB)
        // Positions renormalized
        XCTAssertEqual(config.groups[0].position, 0)
        XCTAssertEqual(config.groups[1].position, 1)
        XCTAssertEqual(config.groups[2].position, 2)
    }

    func testMoveGroupToLastPosition() {
        let groupA = UUID()
        let groupB = UUID()
        var config = TunnelConfig(
            groups: [
                RuleGroup(id: groupA, name: "A", position: 0),
                RuleGroup(id: groupB, name: "B", position: 1),
            ]
        )

        config.moveGroup(groupA, toPosition: 999) // Clamped

        XCTAssertEqual(config.groups[0].id, groupB)
        XCTAssertEqual(config.groups[1].id, groupA)
    }

    func testMoveGroupInvalidIdNoOp() {
        let groupA = UUID()
        var config = TunnelConfig(
            groups: [RuleGroup(id: groupA, name: "A", position: 0)]
        )

        config.moveGroup(UUID(), toPosition: 0) // Invalid ID

        XCTAssertEqual(config.groups.count, 1)
        XCTAssertEqual(config.groups[0].id, groupA)
    }

    // MARK: - insertionPointForEmptyGroup

    func testEmptyGroupBetweenGroupsWithRules() {
        let groupA = UUID()
        let groupB = UUID()
        let groupC = UUID()
        let ruleA = RoutingRule(type: .domain, value: "a.com", outbound: .proxy, groupId: groupA)
        let ruleC = RoutingRule(type: .domain, value: "c.com", outbound: .proxy, groupId: groupC)
        var config = TunnelConfig(
            rules: [ruleA, ruleC],
            groups: [
                RuleGroup(id: groupA, name: "A", position: 0),
                RuleGroup(id: groupB, name: "B (empty)", position: 1),
                RuleGroup(id: groupC, name: "C", position: 2),
            ]
        )

        // Move ruleA to empty groupB — should insert between A rules and C rules
        config.moveRule(ruleA.id, toGroup: groupB, atGroupIndex: 0)

        XCTAssertEqual(config.rules[0].groupId, groupB)
        XCTAssertEqual(config.rules[0].value, "a.com")
        // ruleC should follow
        XCTAssertEqual(config.rules[1].groupId, groupC)
    }
}
