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
    #expect(IslandLayout.form(activity: nil, music: true, hovering: true, fullScreen: false) == .expanded)
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

  // MARK: Medidas

  private let notch = CGSize(width: 208, height: 37.5)

  @Test func sizesGrowFromTheNotch() {
    #expect(IslandLayout.size(of: .hidden, notch: notch) == .zero)
    #expect(IslandLayout.size(of: .notch, notch: notch) == notch)
    #expect(IslandLayout.size(of: .compact, notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.size(of: .expanded, notch: notch) == CGSize(width: 420, height: 185.5))
    #expect(IslandLayout.size(of: .activity(.listening, bubble: true), notch: notch) == CGSize(width: 380, height: 67.5))
    // «Hecho» cabe en los lados, como la compacta.
    #expect(IslandLayout.size(of: .activity(.done, bubble: false), notch: notch) == CGSize(width: 288, height: 37.5))
    #expect(IslandLayout.bubbleDiameter(notch: notch) == 37.5)
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
