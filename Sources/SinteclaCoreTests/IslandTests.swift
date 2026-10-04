import CoreGraphics
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct IslandTests {
  // MARK: Formas

  @Test func withNothingItIsTheNotch() {
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false) == .notch)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: true, fullScreen: false) == .notch)
  }

  @Test func musicIsCompactAndExpandsWithTheMouse() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: false) == .compact)
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false)
              == .expanded(music: true, shelf: false))
  }

  @Test func sinteclaWinsAndMusicGoesToTheBubble() {
    #expect(IslandLayout.form(activity: .listening, music: false, hovering: true, fullScreen: false)
              == .activity(.listening, bubble: false))
    #expect(IslandLayout.form(activity: .meeting, music: true, hovering: true, fullScreen: false)
              == .activity(.meeting, bubble: true))
  }

  @Test func fullScreenHidesTheRestButNotSintecla() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: true) == .hidden)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: true) == .hidden)
    #expect(IslandLayout.form(activity: .notice, music: false, hovering: false, fullScreen: true)
              == .activity(.notice, bubble: false))
  }

  @Test func withoutNotchOnlySinteclaShows() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false, hasNotch: false) == .hidden)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, hasNotch: false) == .hidden)
    #expect(IslandLayout.form(activity: .listening, music: true, hovering: false, fullScreen: false, hasNotch: false)
              == .activity(.listening, bubble: false))
  }

  // MARK: Estante y avisos

  @Test func withFilesAndNoMusicItIsTheShelf() {
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, shelf: 3) == .shelf)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: true, fullScreen: false, shelf: 3)
              == .expanded(music: false, shelf: true))
  }

  @Test func withMusicTheCompactIsTheMusicsAndTheExpandedHasBoth() {
    #expect(IslandLayout.form(activity: nil, music: true, hovering: false, fullScreen: false, shelf: 3) == .compact)
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false, shelf: 3)
              == .expanded(music: true, shelf: true))
  }

  @Test func draggingFilesOpensTheTrayOverEverything() {
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, dragging: true) == .tray)
    #expect(IslandLayout.form(activity: .listening, music: true, hovering: false, fullScreen: true, dragging: true)
              == .tray)
    #expect(IslandLayout.form(activity: nil, music: false, hovering: false, fullScreen: false, hasNotch: false,
                              shelf: 3, dragging: true) == .hidden)
  }

  @Test func deviceNoticesAreActivitiesAlsoWithoutNotch() {
    #expect(IslandLayout.form(activity: .device, music: true, hovering: false, fullScreen: false)
              == .activity(.device, bubble: true))
    #expect(IslandLayout.form(activity: .device, music: true, hovering: false, fullScreen: false, hasNotch: false)
              == .activity(.device, bubble: false))
    #expect(IslandActivity.device.isTall)
  }

  @Test func onlyMusicAndShelfFormsExpand() {
    #expect(IslandLayout.isHoverable(.compact) && IslandLayout.isHoverable(.shelf))
    #expect(IslandLayout.isHoverable(.expanded(music: false, shelf: true)))
    #expect(!IslandLayout.isHoverable(.tray) && !IslandLayout.isHoverable(.notch))
    #expect(!IslandLayout.isHoverable(.activity(.device, bubble: false)))
  }

  @Test func theDropZoneSurroundsTheNotch() {
    let rect = CGRect(x: 751, y: 1074.5, width: 208, height: 37.5)
    #expect(IslandLayout.dropZone(around: rect) == CGRect(x: 631, y: 964.5, width: 448, height: 147.5))
  }

  // MARK: Medidas

  private let notch = CGSize(width: 208, height: 37.5)

  @Test func sizesGrowFromTheNotch() {
    #expect(IslandLayout.size(of: .hidden, notch: notch) == .zero)
    #expect(IslandLayout.size(of: .notch, notch: notch) == notch)
    #expect(IslandLayout.size(of: .compact, notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.size(of: .expanded(music: true, shelf: false), notch: notch) == CGSize(width: 420, height: 185.5))
    #expect(IslandLayout.size(of: .activity(.listening, bubble: true), notch: notch) == CGSize(width: 380, height: 67.5))
    // «Hecho» cabe en los lados, como la compacta.
    #expect(IslandLayout.size(of: .activity(.done, bubble: false), notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.bubbleDiameter(notch: notch) == 37.5)
  }

  @Test func shelfSizes() {
    #expect(IslandLayout.size(of: .shelf, notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.size(of: .expanded(music: false, shelf: true), notch: notch) == CGSize(width: 420, height: 121.5))
    #expect(IslandLayout.size(of: .expanded(music: true, shelf: true), notch: notch) == CGSize(width: 420, height: 263.5))
    #expect(IslandLayout.size(of: .tray, notch: notch) == CGSize(width: 420, height: 133.5))
  }

  @Test func withoutNotchActivitiesAreOneRow() {
    let virtual = CGSize(width: 180, height: 24)
    #expect(IslandLayout.size(of: .activity(.listening, bubble: false), notch: virtual, hasNotch: false)
              == CGSize(width: 352, height: 38))
    #expect(IslandLayout.size(of: .activity(.done, bubble: false), notch: virtual, hasNotch: false)
              == CGSize(width: 260, height: 24))
  }

  @Test func onlyDoneStaysShort() {
    #expect(IslandActivity.listening.isTall && IslandActivity.meeting.isTall && IslandActivity.processing.isTall)
    #expect(IslandActivity.notice.isTall)
    #expect(!IslandActivity.done.isTall)
  }

  // MARK: Ratón

  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  @Test func expandsAfterAShortHover() {
    var hover = IslandHover()
    var changed = hover.update(inside: true, at: t0)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 0.1)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 0.15)
    #expect(changed)
    #expect(hover.isExpanded)
  }

  @Test func passingByDoesNotExpand() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: false, at: t0 + 0.1)
    let changed = hover.update(inside: true, at: t0 + 0.2)
    #expect(!changed)
    #expect(!hover.isExpanded)
  }

  @Test func collapsesAfterLeavingAndComingBackKeepsIt() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: true, at: t0 + 0.2)
    var changed = hover.update(inside: false, at: t0 + 1)
    #expect(!changed)
    changed = hover.update(inside: true, at: t0 + 1.2)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.3)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.5)
    #expect(!changed)
    changed = hover.update(inside: false, at: t0 + 1.6)
    #expect(changed)
    #expect(!hover.isExpanded)
  }

  @Test func resetCollapses() {
    var hover = IslandHover()
    hover.update(inside: true, at: t0)
    hover.update(inside: true, at: t0 + 0.2)
    hover.reset()
    #expect(!hover.isExpanded)
  }
}
