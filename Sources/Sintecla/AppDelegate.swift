import AppKit
import SinteclaCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let settings = AppSettings()
  private var controller: DictationController!
  private var menuBar: MenuBarController!
  private var onboardingWindow: NSWindow?
  private let meetings = MeetingLibrary(store: MeetingStore(directory: AppPaths.meetingsDirectory))
  private lazy var mainWindow = MainWindowController { [unowned self] navigation in
    AnyView(MainView(navigation: navigation, settings: settings, history: controller.history, usage: controller.usage,
                     meetings: meetings,
                     meetingActions: MeetingActions(toggle: { [unowned self] in controller.toggleMeeting() },
                                                    retry: { [unowned self] in controller.retryMeeting($0) }),
                     showPermissions: { [unowned self] in showOnboarding() },
                     onSettingsChange: { [unowned self] in
                       controller.applySettings()
                       LoginItem.set(settings.launchAtLogin)
                     }))
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Reuniones que quedaron a medias (la app se cerró grabando o procesando): pasan a pendientes.
    meetings.store.recoverInterrupted()
    meetings.reload()
    controller = DictationController(settings: settings, meetings: meetings)
    NSApp.mainMenu = MainMenu.make { [weak self] in self?.mainWindow.show(.general) }
    menuBar = MenuBarController(settings: settings, actions: MenuActions(
      pasteLast: { [weak self] in self?.controller.pasteLastResult() },
      addToDictionary: { [weak self] in self?.controller.addSelectionToDictionary() },
      pendingNotes: { [weak self] in self?.controller.drafts.pending().count ?? 0 },
      showPendingNotes: { NSWorkspace.shared.open(AppPaths.draftsDirectory) },
      showMain: { [weak self] in self?.mainWindow.show() },
      meetingSince: { [weak self] in self?.meetings.recordingSince },
      toggleMeeting: { [weak self] in self?.controller.toggleMeeting() },
      pendingMeetings: { [weak self] in self?.meetings.records.filter { $0.status == .pending }.count ?? 0 },
      showMeetings: { [weak self] in self?.mainWindow.show(.page(.meetings)) },
      showHistory: { [weak self] in self?.mainWindow.show(.page(.history)) },
      showSettings: { [weak self] in self?.mainWindow.show(.general) },
      showPermissions: { [weak self] in self?.showOnboarding() },
      settingsChanged: { [weak self] in self?.controller.applySettings() }))
    controller.onRecordingChange = { [weak self] recording in self?.menuBar.setRecording(recording) }
    LoginItem.set(settings.launchAtLogin)

    if Permissions.essentialsGranted, controller.start() {
      menuBar.isReady = true
    } else {
      showOnboarding()
    }
  }

  private func showOnboarding() {
    if onboardingWindow == nil {
      onboardingWindow = WindowFactory.make(title: "Sintecla", content: OnboardingView { [weak self] in
        guard let self else { return }
        if self.controller.start() {
          self.menuBar.isReady = true
          self.onboardingWindow?.close()
        } else {
          // Hay Accesibilidad pero macOS no deja leer el teclado: falta Monitorización de entrada.
          Permissions.requestInputMonitoring()
          Permissions.open(.inputMonitoring)
        }
      })
    }
    WindowFactory.present(onboardingWindow!)
  }

}
