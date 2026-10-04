import Foundation
import Testing
@testable import SinteclaCore

@Suite struct ShelfTests {
  private func item(_ path: String) -> ShelfItem {
    ShelfItem(path: path, name: (path as NSString).lastPathComponent, bookmark: Data(path.utf8))
  }

  @Test func addsAtTheEndWithoutRepeating() {
    var shelf = Shelf()
    var added = shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png")])
    #expect(added == 2)
    added = shelf.add([item("/tmp/c.zip"), item("/tmp/a.pdf")])
    #expect(added == 1)
    #expect(shelf.items.map(\.name) == ["a.pdf", "b.png", "c.zip"])
    #expect(shelf.count == 3)
  }

  @Test func removesOneAndClears() {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png")])
    shelf.remove(shelf.items[0].id)
    #expect(shelf.items.map(\.name) == ["b.png"])
    shelf.clear()
    #expect(shelf.isEmpty)
  }

  @Test func draggingOutRemovesUnlessOptionOrNotDropped() {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png"), item("/tmp/c.zip")])
    let (a, b, c) = (shelf.items[0].id, shelf.items[1].id, shelf.items[2].id)
    shelf.dragEnded(a, dropped: true, keep: false)
    shelf.dragEnded(b, dropped: true, keep: true)
    shelf.dragEnded(c, dropped: false, keep: false)
    #expect(shelf.items.map(\.name) == ["b.png", "c.zip"])
  }

  @Test func refreshDropsMissingAndFollowsMovedFiles() {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png"), item("/tmp/c.zip")])
    let changed = shelf.refresh { item in
      switch item.name {
      case "a.pdf": nil
      case "b.png": (path: "/tmp/fotos/foto.png", name: "foto.png")
      default: (path: item.path, name: item.name)
      }
    }
    #expect(changed)
    #expect(shelf.items.map(\.path) == ["/tmp/fotos/foto.png", "/tmp/c.zip"])
    let again = shelf.refresh { (path: $0.path, name: $0.name) }
    #expect(!again)
  }

  @Test func savesAndLoadsTheSameList() throws {
    var shelf = Shelf()
    shelf.add([item("/tmp/a.pdf"), item("/tmp/b.png")])
    let data = try JSONEncoder().encode(shelf)
    #expect(try JSONDecoder().decode(Shelf.self, from: data) == shelf)
  }
}
