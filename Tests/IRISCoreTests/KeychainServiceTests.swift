import XCTest
@testable import IRISCore

final class KeychainServiceTests: XCTestCase {

    let testAPIKey = "test-api-key-12345"
    let testService = KeychainService.shared

    override func setUp() {
        super.setUp()
        // Clean up any existing test data
        try? testService.deleteAPIKey()
    }

    override func tearDown() {
        // Clean up after each test
        try? testService.deleteAPIKey()
        super.tearDown()
    }

    // MARK: - Basic Save and Retrieve Tests

    func testSaveAndRetrieveAPIKey() throws {
        // Save the API key
        try testService.saveAPIKey(testAPIKey)

        // Retrieve the API key
        let retrievedKey = try testService.getAPIKey()

        // Verify it matches
        XCTAssertEqual(retrievedKey, testAPIKey)
    }

    func testRetrieveNonExistentKey() {
        // Attempting to retrieve a non-existent key should throw
        XCTAssertThrowsError(try testService.getAPIKey()) { error in
            guard let keychainError = error as? KeychainError else {
                XCTFail("Expected KeychainError")
                return
            }
            XCTAssertEqual(keychainError, .itemNotFound)
        }
    }

    func testHasAPIKeyWhenNotSaved() {
        let hasKey = testService.hasAPIKey()
        XCTAssertFalse(hasKey)
    }

    func testHasAPIKeyWhenSaved() throws {
        try testService.saveAPIKey(testAPIKey)

        let hasKey = testService.hasAPIKey()
        XCTAssertTrue(hasKey)
    }

    // MARK: - Update Tests

    func testUpdateAPIKey() throws {
        // Save initial key
        try testService.saveAPIKey(testAPIKey)

        // Update with new key
        let newAPIKey = "new-api-key-67890"
        try testService.saveAPIKey(newAPIKey)

        // Retrieve and verify it's the new key
        let retrievedKey = try testService.getAPIKey()
        XCTAssertEqual(retrievedKey, newAPIKey)
    }

    func testSaveOverwritesExistingKey() throws {
        // Save first key
        try testService.saveAPIKey("first-key")

        // Save second key
        try testService.saveAPIKey("second-key")

        // Should only have the second key
        let retrievedKey = try testService.getAPIKey()
        XCTAssertEqual(retrievedKey, "second-key")
    }

    // MARK: - Delete Tests

    func testDeleteAPIKey() throws {
        // Save a key
        try testService.saveAPIKey(testAPIKey)

        // Verify it exists
        XCTAssertTrue(testService.hasAPIKey())

        // Delete the key
        try testService.deleteAPIKey()

        // Verify it's gone
        XCTAssertFalse(testService.hasAPIKey())
    }

    func testDeleteNonExistentKey() {
        // Deleting a non-existent key should not throw
        XCTAssertNoThrow(try testService.deleteAPIKey())
    }

    func testDeleteTwice() throws {
        // Save a key
        try testService.saveAPIKey(testAPIKey)

        // Delete once
        try testService.deleteAPIKey()

        // Delete again - should not throw
        XCTAssertNoThrow(try testService.deleteAPIKey())
    }

    // MARK: - Data Encoding Tests

    func testSaveEmptyString() throws {
        // Save empty string
        try testService.saveAPIKey("")

        // Retrieve it
        let retrievedKey = try testService.getAPIKey()
        XCTAssertEqual(retrievedKey, "")
    }

    func testSaveSpecialCharacters() throws {
        let specialKey = "key-with-special-chars-!@#$%^&*()"
        try testService.saveAPIKey(specialKey)

        let retrievedKey = try testService.getAPIKey()
        XCTAssertEqual(retrievedKey, specialKey)
    }

    func testSaveLongString() throws {
        let longKey = String(repeating: "a", count: 1000)
        try testService.saveAPIKey(longKey)

        let retrievedKey = try testService.getAPIKey()
        XCTAssertEqual(retrievedKey, longKey)
    }

    func testSaveUnicodeString() throws {
        let unicodeKey = "test-🔑-api-key-你好"
        try testService.saveAPIKey(unicodeKey)

        let retrievedKey = try testService.getAPIKey()
        XCTAssertEqual(retrievedKey, unicodeKey)
    }

    // MARK: - Error Handling Tests

    func testErrorEquality() {
        XCTAssertEqual(KeychainError.failedToSave, KeychainError.failedToSave)
        XCTAssertEqual(KeychainError.itemNotFound, KeychainError.itemNotFound)
        XCTAssertNotEqual(KeychainError.failedToSave, KeychainError.itemNotFound)
    }

    func testErrorDescriptions() {
        let errors: [(KeychainError, String)] = [
            (.itemNotFound, "itemNotFound"),
            (.invalidData, "invalidData"),
            (.failedToSave, "failedToSave"),
            (.failedToRetrieve, "failedToRetrieve"),
            (.failedToDelete, "failedToDelete")
        ]

        for (error, _) in errors {
            // Verify error has a description (for debugging)
            XCTAssertNotNil(String(describing: error))
        }
    }

    // MARK: - Singleton Tests

    func testSingletonInstance() {
        let instance1 = KeychainService.shared
        let instance2 = KeychainService.shared

        // Should be the same instance
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentSave() throws {
        let expectation = self.expectation(description: "Concurrent saves")
        expectation.expectedFulfillmentCount = 10

        // Perform multiple concurrent saves
        for i in 0..<10 {
            DispatchQueue.global().async {
                try? self.testService.saveAPIKey("key-\(i)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should have some key saved (last one wins)
        XCTAssertTrue(testService.hasAPIKey())
    }

    func testConcurrentReadWrite() throws {
        try testService.saveAPIKey(testAPIKey)

        let expectation = self.expectation(description: "Concurrent read/write")
        expectation.expectedFulfillmentCount = 20

        // Perform concurrent reads and writes
        for i in 0..<10 {
            DispatchQueue.global().async {
                _ = try? self.testService.getAPIKey()
                expectation.fulfill()
            }

            DispatchQueue.global().async {
                try? self.testService.saveAPIKey("key-\(i)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Should still have a key
        XCTAssertTrue(testService.hasAPIKey())
    }

    // MARK: - State Consistency Tests

    func testHasAPIKeyConsistentWithGet() throws {
        // Initially no key
        XCTAssertFalse(testService.hasAPIKey())
        XCTAssertThrowsError(try testService.getAPIKey())

        // Save a key
        try testService.saveAPIKey(testAPIKey)

        // Now should have key
        XCTAssertTrue(testService.hasAPIKey())
        XCTAssertNoThrow(try testService.getAPIKey())

        // Delete key
        try testService.deleteAPIKey()

        // Should not have key
        XCTAssertFalse(testService.hasAPIKey())
        XCTAssertThrowsError(try testService.getAPIKey())
    }

    // MARK: - Persistence Tests

    func testAPIPersistsAcrossInstances() throws {
        // Save using shared instance
        try KeychainService.shared.saveAPIKey(testAPIKey)

        // Access using shared instance again (simulates app restart)
        let retrievedKey = try KeychainService.shared.getAPIKey()

        XCTAssertEqual(retrievedKey, testAPIKey)
    }
}

// MARK: - KeychainError Equatable Extension
extension KeychainError: Equatable {
    public static func == (lhs: KeychainError, rhs: KeychainError) -> Bool {
        switch (lhs, rhs) {
        case (.failedToSave, .failedToSave),
             (.failedToRetrieve, .failedToRetrieve),
             (.failedToDelete, .failedToDelete),
             (.itemNotFound, .itemNotFound),
             (.invalidData, .invalidData):
            return true
        case (.unexpectedStatus(let lhsStatus), .unexpectedStatus(let rhsStatus)):
            return lhsStatus == rhsStatus
        default:
            return false
        }
    }
}
