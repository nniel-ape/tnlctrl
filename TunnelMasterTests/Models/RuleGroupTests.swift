//
//  RuleGroupTests.swift
//  TunnelMasterTests
//
//  Tests for RuleGroup model.
//

@testable import TunnelMaster
import XCTest

final class RuleGroupTests: XCTestCase {
    func testGroupInitialization() {
        let group = RuleGroup(
            name: "Test Group",
            description: "Test Description",
            icon: "folder",
            color: .blue,
            position: 0
        )

        XCTAssertEqual(group.name, "Test Group")
        XCTAssertEqual(group.description, "Test Description")
        XCTAssertEqual(group.icon, "folder")
        XCTAssertEqual(group.color, .blue)
        XCTAssertTrue(group.isExpanded)
        XCTAssertEqual(group.position, 0)
    }

    func testGroupCodable() throws {
        let group = RuleGroup(
            name: "Test Group",
            description: "Test Description",
            icon: "star",
            color: .purple,
            position: 1
        )

        let data = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(RuleGroup.self, from: data)

        XCTAssertEqual(group.id, decoded.id)
        XCTAssertEqual(group.name, decoded.name)
        XCTAssertEqual(group.description, decoded.description)
        XCTAssertEqual(group.icon, decoded.icon)
        XCTAssertEqual(group.color, decoded.color)
        XCTAssertEqual(group.isExpanded, decoded.isExpanded)
        XCTAssertEqual(group.position, decoded.position)
    }

    func testGroupMigration() throws {
        // Simulate old JSON without optional fields
        let oldJSON = """
        {
            "id": "test-id",
            "name": "Test Group"
        }
        """

        let data = try XCTUnwrap(oldJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(RuleGroup.self, from: data)

        XCTAssertEqual(decoded.name, "Test Group")
        XCTAssertEqual(decoded.description, "") // Should default to empty
        XCTAssertEqual(decoded.icon, "folder") // Should default to folder
        XCTAssertEqual(decoded.color, .blue) // Should default to blue
        XCTAssertTrue(decoded.isExpanded) // Should default to true
        XCTAssertEqual(decoded.position, 0) // Should default to 0
    }

    func testGroupColorSwiftUIColor() {
        XCTAssertNotNil(GroupColor.blue.swiftUIColor)
        XCTAssertNotNil(GroupColor.purple.swiftUIColor)
        XCTAssertNotNil(GroupColor.green.swiftUIColor)
    }
}
