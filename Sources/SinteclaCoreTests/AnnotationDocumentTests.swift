import CoreGraphics
import Testing
@testable import SinteclaCore

@Suite struct AnnotationDocumentTests {
  private let red = AnnotationStyle()
  private func arrow(_ x: CGFloat = 100) -> AnnotationShape {
    .arrow(from: CGPoint(x: x, y: 100), to: CGPoint(x: x + 200, y: 100))
  }

  @Test func addMoveAndDelete() {
    var document = AnnotationDocument(scale: 2)
    let id = document.add(arrow(), style: red)
    document.move(id, by: CGVector(dx: 10, dy: 5))
    #expect(document.annotation(id)?.shape == .arrow(from: CGPoint(x: 110, y: 105), to: CGPoint(x: 310, y: 105)))
    document.select(id)
    document.delete(id)
    #expect(document.annotations.isEmpty)
    #expect(document.selection == nil)
  }

  @Test func undoAndRedoSeveralInARow() {
    var document = AnnotationDocument()
    let first = document.add(arrow(0), style: red)
    document.add(arrow(300), style: red)
    document.move(first, by: CGVector(dx: 0, dy: 50))
    document.undo()
    document.undo()
    #expect(document.annotations.map(\.id) == [first])
    #expect(document.annotation(first)?.shape == arrow(0))
    document.redo()
    #expect(document.annotations.count == 2)
    #expect(document.canRedo)
    document.add(.step(at: .zero), style: red)  // un cambio nuevo borra lo que se podía rehacer
    #expect(!document.canRedo)
    document.undo()
    document.undo()
    document.undo()
    #expect(document.annotations.isEmpty)
    #expect(!document.canUndo)
  }

  @Test func undoDropsASelectionThatNoLongerExists() {
    var document = AnnotationDocument()
    let id = document.add(arrow(), style: red)
    document.select(id)
    document.undo()
    #expect(document.selection == nil)
  }

  @Test func stepsRenumberWhenOneIsDeleted() {
    var document = AnnotationDocument()
    let one = document.add(.step(at: CGPoint(x: 10, y: 10)), style: red)
    document.add(arrow(), style: red)
    let two = document.add(.step(at: CGPoint(x: 50, y: 10)), style: red)
    let three = document.add(.step(at: CGPoint(x: 90, y: 10)), style: red)
    #expect([one, two, three].map { document.stepNumber(of: $0) } == [1, 2, 3])
    document.delete(two)
    #expect(document.stepNumber(of: three) == 2)
    document.undo()
    #expect(document.stepNumber(of: two) == 2)
    #expect(document.stepNumber(of: three) == 3)
    #expect(document.stepNumber(of: 2) == nil)  // la flecha no es un paso
  }

  @Test func arrowIsHitNearItsLineOnly() {
    var document = AnnotationDocument(scale: 2)
    let id = document.add(arrow(), style: red)
    #expect(document.hit(CGPoint(x: 200, y: 110)) == id)  // a 10 px: el margen es 6 pt × 2 más medio trazo (4 px)
    #expect(document.hit(CGPoint(x: 200, y: 150)) == nil)
    #expect(document.hit(CGPoint(x: 330, y: 100)) == nil)  // más allá de la punta
  }

  @Test func topmostAnnotationWinsAndRectanglesAreHitOnTheBorder() {
    var document = AnnotationDocument()
    document.add(arrow(), style: red)
    let box = document.add(.rectangle(CGRect(x: 150, y: 50, width: 100, height: 100)), style: red)
    #expect(document.hit(CGPoint(x: 150, y: 100)) == box)  // borde izquierdo, encima de la flecha
    #expect(document.hit(CGPoint(x: 200, y: 75)) == nil)  // dentro, lejos del borde
  }

  @Test func changingTheStyleOfTheSelectedOneCanBeUndone() {
    var document = AnnotationDocument()
    let id = document.add(arrow(), style: red)
    document.select(id)
    document.setStyle(AnnotationStyle(color: .blue, width: .thick), of: id)
    #expect(document.annotation(id)?.style == AnnotationStyle(color: .blue, width: .thick))
    document.undo()
    #expect(document.annotation(id)?.style == red)
    #expect(document.selection == id)
  }

  @Test func textIsEditedAndEmptyTextIsDeleted() {
    var document = AnnotationDocument()
    let id = document.add(.text("Hola", at: CGPoint(x: 5, y: 5)), style: red)
    document.setText("Hola", of: id)
    document.undo()  // sin cambios no hay paso de deshacer: se deshace el añadido
    #expect(document.annotations.isEmpty)
    document.redo()
    document.setText("Adiós", of: id)
    #expect(document.annotation(id)?.shape == .text("Adiós", at: CGPoint(x: 5, y: 5)))
    document.setText("  ", of: id)
    #expect(document.annotation(id) == nil)
  }

  @Test func rulerMeasuresTotalHorizontalAndVertical() {
    let measure = RulerMeasure(from: CGPoint(x: 10, y: 410), to: CGPoint(x: 310, y: 10))
    #expect(measure == RulerMeasure(from: CGPoint(x: 310, y: 10), to: CGPoint(x: 10, y: 410)))
    #expect([measure.total, measure.horizontal, measure.vertical] == [500, 300, 400])
    #expect(measure.label == "500 px · ↔ 300 · ↕ 400")
  }

  @Test func clicksWithoutDraggingLeaveNothing() {
    #expect(AnnotationShape.arrow(from: .zero, to: CGPoint(x: 5, y: 0)).isTooSmall(scale: 2))
    #expect(!AnnotationShape.arrow(from: .zero, to: CGPoint(x: 9, y: 0)).isTooSmall(scale: 2))
    #expect(AnnotationShape.pen([CGPoint(x: 1, y: 1)]).isTooSmall(scale: 1))
    #expect(!AnnotationShape.rectangle(CGRect(x: 0, y: 0, width: -30, height: 1)).isTooSmall(scale: 2))
    #expect(!AnnotationShape.step(at: .zero).isTooSmall(scale: 2))
  }

  @Test func toolsKeysAndColors() {
    #expect(AnnotationTool.allCases.map(\.key).joined() == "VATRPHNM")
    #expect(AnnotationTool.tool(forKey: "a") == .arrow)
    #expect(AnnotationTool.tool(forKey: "M") == .ruler)
    #expect(AnnotationTool.tool(forKey: "x") == nil)
    #expect(AnnotationColor.allCases.map(\.name) == ["Rojo", "Amarillo", "Verde", "Azul", "Negro", "Blanco"])
    #expect(AnnotationColor.yellow.contrast == .black)
    #expect(AnnotationColor.red.contrast == .white)
    #expect(AnnotationStyle() == AnnotationStyle(color: .red, width: .medium))
  }
}
