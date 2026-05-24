import Testing
@testable import AssetCore

@Test func schemaVersionIsOne() {
    #expect(AssetCore.schemaVersion == 1)
}
