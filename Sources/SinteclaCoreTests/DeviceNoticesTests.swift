import Foundation
import Testing
@testable import SinteclaCore

@Suite struct DeviceNoticesTests {
  // MARK: Carga

  private func battery(_ percent: Int, minutes: Int? = nil) -> PowerState {
    PowerState(percent: percent, pluggedIn: false, charging: false, minutesLeft: minutes)
  }

  private func plugged(_ percent: Int, charging: Bool = true) -> PowerState {
    PowerState(percent: percent, pluggedIn: true, charging: charging)
  }

  @Test func theFirstStateDoesNotNotify() {
    var power = PowerNotices()
    let notices = power.update(battery(80))
    #expect(notices.isEmpty)
  }

  @Test func pluggingInSaysChargingOrPluggedIn() {
    var power = PowerNotices()
    _ = power.update(battery(80))
    var notices = power.update(plugged(80))
    #expect(notices == [.pluggedIn(percent: 80, charging: true)])
    notices = power.update(plugged(81))
    #expect(notices.isEmpty)
    _ = power.update(battery(81))
    notices = power.update(plugged(81, charging: false))
    #expect(notices == [.pluggedIn(percent: 81, charging: false)])
  }

  @Test func unpluggingGivesPercentAndTimeLeft() {
    var power = PowerNotices()
    _ = power.update(plugged(80))
    var notices = power.update(battery(80, minutes: 380))
    #expect(notices == [.unplugged(percent: 80, minutesLeft: 380)])
    _ = power.update(plugged(80))
    notices = power.update(battery(80))
    #expect(notices == [.unplugged(percent: 80, minutesLeft: nil)])
  }

  @Test func lowBatteryWarnsOncePerThreshold() {
    var power = PowerNotices()
    _ = power.update(battery(25))
    var notices = power.update(battery(21))
    #expect(notices.isEmpty)
    notices = power.update(battery(20))
    #expect(notices == [.lowBattery(percent: 20)])
    notices = power.update(battery(15))
    #expect(notices.isEmpty)
    notices = power.update(battery(10))
    #expect(notices == [.lowBattery(percent: 10)])
    notices = power.update(battery(5))
    #expect(notices.isEmpty)
  }

  @Test func pluggingInRearmsTheThresholds() {
    var power = PowerNotices()
    _ = power.update(battery(21))
    _ = power.update(battery(20))
    _ = power.update(plugged(20))
    _ = power.update(plugged(25))
    _ = power.update(battery(25))
    let notices = power.update(battery(20))
    #expect(notices == [.lowBattery(percent: 20)])
  }

  @Test func startingOrUnpluggingBelowAThresholdDoesNotWarnForIt() {
    var power = PowerNotices()
    _ = power.update(battery(15))
    var notices = power.update(battery(14))
    #expect(notices.isEmpty)
    notices = power.update(battery(10))
    #expect(notices == [.lowBattery(percent: 10)])
  }

  @Test func aJumpAcrossBothThresholdsWarnsOnce() {
    var power = PowerNotices()
    _ = power.update(battery(30))
    var notices = power.update(battery(9))
    #expect(notices == [.lowBattery(percent: 9)])
    notices = power.update(battery(8))
    #expect(notices.isEmpty)
  }

  @Test func textsAndSymbols() {
    #expect(DeviceNotice.pluggedIn(percent: 80, charging: true).text == "Cargando · 80 %")
    #expect(DeviceNotice.pluggedIn(percent: 80, charging: false).text == "Enchufado · 80 %")
    #expect(DeviceNotice.unplugged(percent: 80, minutesLeft: 380).text == "80 % · 6 h 20 min")
    #expect(DeviceNotice.unplugged(percent: 80, minutesLeft: nil).text == "80 %")
    #expect(DeviceNotice.lowBattery(percent: 10).text == "Batería baja · 10 %")
    #expect(DeviceNotice.duration(45) == "45 min")
    #expect(DeviceNotice.duration(120) == "2 h")
    #expect(DeviceNotice.pluggedIn(percent: 80, charging: true).tint == .green)
    #expect(DeviceNotice.lowBattery(percent: 10).tint == .red)
    #expect(DeviceNotice.unplugged(percent: 80, minutesLeft: nil).tint == .plain)
    #expect(DeviceNotice.lowBattery(percent: 10).isUrgent)
    #expect(!DeviceNotice.pluggedIn(percent: 80, charging: true).isUrgent)
  }

  // MARK: AirPods

  private let json = Data("""
  {"SPBluetoothDataType":[{"device_connected":[
    {"AirPods de prueba":{"device_address":"00:11:22:33:44:55","device_batteryLevelCase":"52\\u00a0%",
      "device_batteryLevelLeft":"64\\u00a0%","device_batteryLevelRight":"65 %","device_minorType":"Headphones",
      "device_vendorID":"0x004C"}},
    {"Teclado":{"device_address":"AA:BB:CC:DD:EE:FF","device_minorType":"Keyboard","device_vendorID":"0x046D"}},
    {"Otros cascos":{"device_address":"11:11:11:11:11:11","device_minorType":"Headphones","device_vendorID":"0x0A12"}}
  ]}]}
  """.utf8)

  @Test func readsTheAppleHeadphonesFromSystemProfiler() {
    let devices = AirPodsDevice.parse(systemProfiler: json)
    #expect(devices == [AirPodsDevice(name: "AirPods de prueba", address: "00:11:22:33:44:55",
                                      battery: AirPodsBattery(left: 64, right: 65, case: 52))])
    #expect(AirPodsDevice.parse(systemProfiler: Data("no".utf8)).isEmpty)
  }

  @Test func missingBatteriesStayNil() {
    let data = Data("""
    {"SPBluetoothDataType":[{"device_connected":[{"AirPods de prueba":{"device_address":"00:11","device_batteryLevelLeft":"40 %",
      "device_minorType":"Headphones","device_vendorID":"0x004c"}}]}]}
    """.utf8)
    #expect(AirPodsDevice.parse(systemProfiler: data).first?.battery == AirPodsBattery(left: 40))
  }

  private func pods(_ left: Int?, _ right: Int?, case box: Int? = nil) -> AirPodsDevice {
    AirPodsDevice(name: "AirPods de prueba", address: "00:11", battery: AirPodsBattery(left: left, right: right, case: box))
  }

  @Test func connectingNotifiesWithTheBatteries() {
    var notices = AirPodsNotices()
    let device = pods(64, 65, case: 52)
    #expect(notices.connected(device) == [.airPods(name: "AirPods de prueba", battery: device.battery)])
    #expect(notices.isConnected(address: "00:11"))
    #expect(DeviceNotice.airPods(name: "AirPods de prueba", battery: device.battery).airPods == device.battery)
  }

  @Test func lowAirPodsWarnOncePerConnection() {
    var notices = AirPodsNotices()
    _ = notices.connected(pods(30, 30))
    var result = notices.batteryChanged(pods(11, 30))
    #expect(result.isEmpty)
    result = notices.batteryChanged(pods(10, 30))
    #expect(result == [.airPodsLow(name: "AirPods de prueba", battery: AirPodsBattery(left: 10, right: 30))])
    result = notices.batteryChanged(pods(8, 30))
    #expect(result.isEmpty)
    notices.disconnected(address: "00:11")
    #expect(!notices.isConnected(address: "00:11"))
    result = notices.connected(pods(8, 30))
    #expect(result == [.airPodsLow(name: "AirPods de prueba", battery: AirPodsBattery(left: 8, right: 30))])
  }

  @Test func theCaseDoesNotCountAsLow() {
    #expect(!AirPodsBattery(left: 50, right: 50, case: 5).isLow)
    #expect(AirPodsBattery(left: 50, right: 9).isLow)
    #expect(AirPodsBattery().isEmpty)
  }

  @Test func alreadyConnectedAtStartDoesNotNotify() {
    var notices = AirPodsNotices()
    notices.known(pods(30, 30))
    let result = notices.batteryChanged(pods(9, 30))
    #expect(result.count == 1)
    #expect(notices.batteryChanged(pods(64, 64)).isEmpty)
  }

  // MARK: Cola

  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func oneAfterAnotherThreeSecondsEach() {
    var queue = NoticeQueue()
    queue.push([.lowBattery(percent: 10), .pluggedIn(percent: 10, charging: true)], at: t0)
    var changed = queue.tick(at: t0, busy: false)
    #expect(changed)
    #expect(queue.current == .lowBattery(percent: 10))
    #expect(queue.nextTick == t0 + 3)
    changed = queue.tick(at: t0 + 2, busy: false)
    #expect(!changed)
    changed = queue.tick(at: t0 + 3, busy: false)
    #expect(changed)
    #expect(queue.current == .pluggedIn(percent: 10, charging: true))
    queue.tick(at: t0 + 6, busy: false)
    #expect(queue.current == nil)
    #expect(queue.isEmpty)
  }

  @Test func waitsWhileSinteclaIsBusyAndDropsStaleOnes() {
    var queue = NoticeQueue()
    queue.push([.pluggedIn(percent: 50, charging: true), .lowBattery(percent: 9)], at: t0)
    queue.tick(at: t0, busy: true)
    #expect(queue.current == nil)
    queue.tick(at: t0 + 5, busy: false)
    #expect(queue.current == .pluggedIn(percent: 50, charging: true))

    var late = NoticeQueue()
    late.push([.pluggedIn(percent: 50, charging: true), .lowBattery(percent: 9)], at: t0)
    late.tick(at: t0 + 11, busy: false)
    #expect(late.current == .lowBattery(percent: 9))
  }
}
