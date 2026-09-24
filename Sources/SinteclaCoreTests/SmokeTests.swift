import Testing
@testable import SinteclaCore

@Suite struct SmokeTests {
  @Test func appInfoIsSet() {
    #expect(AppInfo.version == "0.7.0")
    #expect(AppInfo.bundleID == "local.sintecla.app")
  }
}
