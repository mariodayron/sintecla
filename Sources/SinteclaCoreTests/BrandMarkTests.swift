import Testing
@testable import SinteclaCore

@Suite struct BrandMarkTests {
  @Test(arguments: BrandMark.Variant.allCases)
  func everyPieceFitsInTheUnitSquare(_ variant: BrandMark.Variant) {
    for piece in BrandMark.pieces(variant) {
      #expect(piece.x >= 0 && piece.y >= 0 && piece.maxX <= 1 && piece.maxY <= 1, "\(variant): \(piece)")
    }
  }

  @Test(arguments: BrandMark.Variant.allCases)
  func barsGoLeftOfTheCursorWithoutOverlapping(_ variant: BrandMark.Variant) {
    let pieces = BrandMark.pieces(variant)
    let bars = pieces.filter { !$0.isCursor }
    let cursorStart = pieces.filter(\.isCursor).map(\.x).min() ?? 0
    for (left, right) in zip(bars, bars.dropFirst()) {
      #expect(left.maxX < right.x, "\(variant)")
    }
    #expect(bars.last!.maxX < cursorStart, "\(variant)")
  }

  @Test(arguments: BrandMark.Variant.allCases)
  func theCursorIsAlwaysSolid(_ variant: BrandMark.Variant) {
    #expect(BrandMark.pieces(variant).filter(\.isCursor).allSatisfy { $0.opacity == 1 })
  }

  @Test func theLargeWaveDarkensTowardsTheCursor() {
    let opacities = BrandMark.pieces(.large).filter { !$0.isCursor }.map(\.opacity)
    #expect(opacities.count == 5)
    #expect(zip(opacities, opacities.dropFirst()).allSatisfy { $0 < $1 })
  }

  @Test func theSmallWaveHasThreeSolidBars() {
    let bars = BrandMark.pieces(.small).filter { !$0.isCursor }
    #expect(bars.count == 3)
    #expect(bars.allSatisfy { $0.opacity == 1 })
  }

  @Test func recordingLightsUpAndRaisesTheBars() {
    let idle = BrandMark.pieces(.menuIdle).filter { !$0.isCursor }
    let recording = BrandMark.pieces(.menuRecording).filter { !$0.isCursor }
    #expect(idle.count == recording.count)
    #expect(idle.allSatisfy { $0.opacity == 0.45 })
    #expect(recording.allSatisfy { $0.opacity == 1 })
    #expect(zip(idle, recording).allSatisfy { $0.height < $1.height })
  }
}
