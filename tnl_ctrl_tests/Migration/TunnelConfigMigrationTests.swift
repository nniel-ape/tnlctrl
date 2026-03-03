//
//  TunnelConfigMigrationTests.swift
//  tnl_ctrl_tests
//
//  Tests for backward compatibility with old tunnel-config.json files.
//

@testable import tnl_ctrl
import XCTest

final class TunnelConfigMigrationTests: XCTestCase {
    func testMigrateConfigWithoutGroupsField() throws {
        // Simulate old config JSON without 'groups' field
        let oldJSON = """
        {
            "mode": "split",
            "rules": [
                {
                    "id": "\(UUID().uuidString)",
                    "type": "domain",
                    "value": "example.com",
                    "outbound": "proxy",
                    "isEnabled": true
                }
            ],
            "finalOutbound": "direct"
        }
        """

        let data = try XCTUnwrap(oldJSON.data(using: .utf8))
        let config = try JSONDecoder().decode(TunnelConfig.self, from: data)

        XCTAssertEqual(config.groups.count, 0) // Should default to empty array
        XCTAssertEqual(config.rules.count, 1)
        XCTAssertNil(config.rules[0].groupId) // Should default to nil
    }

    func testMigrateRuleWithoutOrganizationFields() throws {
        // Simulate old rule JSON without groupId, timestamps
        let oldRuleJSON = """
        {
            "id": "\(UUID().uuidString)",
            "type": "domain",
            "value": "example.com",
            "outbound": "proxy",
            "isEnabled": true,
            "note": "Test note"
        }
        """

        let data = try XCTUnwrap(oldRuleJSON.data(using: .utf8))
        let rule = try JSONDecoder().decode(RoutingRule.self, from: data)

        XCTAssertNil(rule.groupId)
        XCTAssertNotNil(rule.createdAt)
        XCTAssertNotNil(rule.lastModified)
    }

    func testMigrateConfigWithGroups() throws {
        // Config with groups should decode properly
        let newJSON = """
        {
            "mode": "split",
            "rules": [
                {
                    "id": "\(UUID().uuidString)",
                    "type": "domain",
                    "value": "example.com",
                    "outbound": "proxy",
                    "isEnabled": true,
                    "groupId": "\(UUID().uuidString)",
                    "tags": ["streaming", "video"],
                    "createdAt": \(Date().timeIntervalSince1970),
                    "lastModified": \(Date().timeIntervalSince1970)
                }
            ],
            "finalOutbound": "direct",
            "groups": [
                {
                    "id": "\(UUID().uuidString)",
                    "name": "Streaming",
                    "description": "Streaming services",
                    "icon": "play.tv",
                    "color": "purple",
                    "isExpanded": true,
                    "position": 0
                }
            ]
        }
        """

        let data = try XCTUnwrap(newJSON.data(using: .utf8))
        let config = try JSONDecoder().decode(TunnelConfig.self, from: data)

        XCTAssertEqual(config.groups.count, 1)
        XCTAssertEqual(config.groups[0].name, "Streaming")
        XCTAssertNotNil(config.rules[0].groupId)
        // tags field in JSON is read & discarded — verifies old data with tags still decodes
    }

    func testOldDataWithTagsStillDecodes() throws {
        let ruleJSON = """
        {
            "id": "\(UUID().uuidString)",
            "type": "domain_suffix",
            "value": "netflix.com",
            "outbound": "proxy",
            "isEnabled": true,
            "tags": ["streaming", "video", "entertainment"]
        }
        """

        let data = try XCTUnwrap(ruleJSON.data(using: .utf8))
        let rule = try JSONDecoder().decode(RoutingRule.self, from: data)

        XCTAssertEqual(rule.value, "netflix.com")
        XCTAssertEqual(rule.type, .domainSuffix)
        // Tags field is silently discarded during decoding
    }

    func testTagsNotEncodedAfterRoundTrip() throws {
        let rule = RoutingRule(type: .domain, value: "example.com", outbound: .proxy)

        let encoded = try JSONEncoder().encode(rule)
        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        // The encoded JSON should not contain a "tags" key
        XCTAssertFalse(json.contains("\"tags\""))
    }

    func testConfigHelperMethods() {
        let groupId = UUID()
        let group = RuleGroup(id: groupId, name: "Test", position: 0)

        let rule1 = RoutingRule(type: .domain, value: "example.com", outbound: .proxy, groupId: groupId)
        let rule2 = RoutingRule(type: .domain, value: "test.com", outbound: .direct)

        var config = TunnelConfig()
        config.groups = [group]
        config.rules = [rule1, rule2]

        // Test ungroupedRules
        XCTAssertEqual(config.ungroupedRules.count, 1)
        XCTAssertEqual(config.ungroupedRules[0].value, "test.com")

        // Test rules(in:)
        XCTAssertEqual(config.rules(in: groupId).count, 1)
        XCTAssertEqual(config.rules(in: groupId)[0].value, "example.com")

        // Test sortedGroups
        XCTAssertEqual(config.sortedGroups.count, 1)
        XCTAssertEqual(config.sortedGroups[0].id, groupId)
    }
}
