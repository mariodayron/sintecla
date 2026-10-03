import Testing
@testable import SinteclaCore

@Suite struct SmokeTests {
  @Test func appInfoIsSet() {
    #expect(AppInfo.version == "0.15.1")
    #expect(AppInfo.bundleID == "local.sintecla.app")
  }
}
