import CoreGraphics
import Foundation
import Testing
@testable import SinteclaCore

@Suite struct NowPlayingTests {
  private let t0 = Date(timeIntervalSince1970: 1_790_000_000)

  // MARK: Las líneas del ayudante

  @Test func readsAFullLine() throws {
    let line = #"{"playing":true,"title":"Mariposas Rojas","artist":"Delaossa","album":"La Madrugá","duration":195,"#
      + #""elapsed":17.5,"timestamp":1790000000,"pid":1463,"artworkID":"a1","artwork":"aGVsbG8="}"#
    let update = try #require(NowPlayingUpdate.parse(line))
    guard case .track(let track, let artwork) = update else {
      Issue.record("no es una canción")
      return
    }
    #expect(track == NowPlaying(title: "Mariposas Rojas", artist: "Delaossa", album: "La Madrugá", duration: 195,
                                elapsed: 17.5, timestamp: t0, isPlaying: true, pid: 1463, artworkID: "a1"))
    #expect(artwork == Data("hello".utf8))
  }

  @Test func aLineWithoutArtworkKeepsTheID() throws {
    let line = #"{"playing":false,"title":"Vídeo","duration":0,"elapsed":3,"timestamp":1790000000,"artworkID":"a1"}"#
    let update = try #require(NowPlayingUpdate.parse(line))
    guard case .track(let track, let artwork) = update else {
      Issue.record("no es una canción")
      return
    }
    #expect(track.artworkID == "a1" && artwork == nil && !track.isPlaying && track.artist.isEmpty)
  }

  @Test func nothingPlaying() {
    #expect(NowPlayingUpdate.parse(#"{"empty":true}"#) == .nothing)
  }

  @Test func brokenLinesChangeNothing() {
    #expect(NowPlayingUpdate.parse("") == nil)
    #expect(NowPlayingUpdate.parse(#"{"playing":true,"title":"#) == nil)
    #expect(NowPlayingUpdate.parse(#"{"playing":true,"timestamp":1790000000}"#) == nil)  // sin título
  }

  // MARK: El punto de la canción

  private func track(playing: Bool, elapsed: TimeInterval = 10, duration: TimeInterval = 100) -> NowPlaying {
    NowPlaying(title: "x", duration: duration, elapsed: elapsed, timestamp: t0, isPlaying: playing)
  }

  @Test func positionAdvancesOnlyWhilePlaying() {
    #expect(track(playing: true).position(at: t0 + 5) == 15)
    #expect(track(playing: false).position(at: t0 + 5) == 10)
    #expect(track(playing: true).progress(at: t0 + 40) == 0.5)
  }

  @Test func positionNeverPassesTheDuration() {
    #expect(track(playing: true).position(at: t0 + 500) == 100)
    // Sin duración, sigue contando y el progreso es 0.
    #expect(track(playing: true, duration: 0).position(at: t0 + 500) == 510)
    #expect(track(playing: true, duration: 0).progress(at: t0 + 5) == 0)
  }

  @Test func clock() {
    #expect(NowPlaying.clock(68.9) == "1:08")
    #expect(NowPlaying.clock(5) == "0:05")
    #expect(NowPlaying.clock(3725) == "1:02:05")
    #expect(NowPlaying.clock(-3) == "0:00")
  }

  // MARK: Cuándo se enseña

  @Test func pausedMusicStaysFiveMinutes() {
    var presence = MusicPresence()
    let paused = track(playing: false)
    presence.update(paused, at: t0)
    #expect(presence.isShown(paused, at: t0 + 299))
    #expect(!presence.isShown(paused, at: t0 + 300))
    // Vuelve a sonar: se enseña, y la pausa siguiente cuenta de nuevo.
    presence.update(track(playing: true), at: t0 + 400)
    #expect(presence.isShown(track(playing: true), at: t0 + 400))
    presence.update(paused, at: t0 + 500)
    #expect(presence.isShown(paused, at: t0 + 700))
    #expect(!presence.isShown(nil, at: t0))
  }

  // MARK: Pausar al dictar

  @Test func pausesWhilePlayingAndResumesAfter() {
    var pauser = MusicPauser()
    var command = pauser.listeningStarted(mode: .dictation, musicPlaying: true)
    #expect(command == .pause)
    pauser.musicChanged(isPlaying: false)  // la propia pausa
    command = pauser.listeningEnded()
    #expect(command == .play)
    command = pauser.listeningEnded()
    #expect(command == nil)
  }

  @Test func doesNotResumeWhatItDidNotPause() {
    var pauser = MusicPauser()
    var command = pauser.listeningStarted(mode: .translation, musicPlaying: false)
    #expect(command == nil)
    command = pauser.listeningEnded()
    #expect(command == nil)
  }

  @Test func doesNotResumeIfTheUserPlayedItMeanwhile() {
    var pauser = MusicPauser()
    _ = pauser.listeningStarted(mode: .ask, musicPlaying: true)
    pauser.musicChanged(isPlaying: true)
    let command = pauser.listeningEnded()
    #expect(command == nil)
  }

  @Test func meetingsLeaveTheMusicAlone() {
    var pauser = MusicPauser()
    var command = pauser.listeningStarted(mode: .meeting, musicPlaying: true)
    #expect(command == nil)
    command = pauser.listeningEnded()
    #expect(command == nil)
  }

  // MARK: Color de la carátula

  private func image(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGImage {
    let context = CGContext(data: nil, width: 40, height: 40, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
    return context.makeImage()!
  }

  @Test func aDarkRedCoverGivesABrightRed() {
    let tint = ArtworkTint(of: image(red: 0.5, green: 0, blue: 0))
    #expect(abs(tint.red - 1) < 0.01 && tint.green < 0.01 && tint.blue < 0.01)
  }

  @Test func aGreyOrBlackCoverGivesWhite() {
    #expect(ArtworkTint(of: image(red: 0.5, green: 0.5, blue: 0.5)) == .white)
    #expect(ArtworkTint(of: image(red: 0.02, green: 0, blue: 0)) == .white)
  }
}
