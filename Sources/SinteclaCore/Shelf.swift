import Foundation

/// Un archivo del estante (spec «Estante y avisos» §3.4): el marcador para encontrarlo aunque se mueva, y la última
/// ruta y el nombre conocidos.
public struct ShelfItem: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public var path: String
  public var name: String
  public var bookmark: Data

  public init(id: UUID = UUID(), path: String, name: String, bookmark: Data) {
    self.id = id
    self.path = path
    self.name = name
    self.bookmark = bookmark
  }
}

/// La lista del estante (spec «Estante y avisos» §3). Guarda enlaces a los originales, no copias.
public struct Shelf: Codable, Equatable, Sendable {
  public private(set) var items: [ShelfItem] = []

  public init(items: [ShelfItem] = []) {
    self.items = items
  }

  public var isEmpty: Bool { items.isEmpty }
  public var count: Int { items.count }

  /// Al final y sin repetir (misma ruta). Devuelve cuántos entraron.
  @discardableResult
  public mutating func add(_ new: [ShelfItem]) -> Int {
    var added = 0
    for item in new where !items.contains(where: { $0.path == item.path }) {
      items.append(item)
      added += 1
    }
    return added
  }

  public mutating func remove(_ id: UUID) {
    items.removeAll { $0.id == id }
  }

  public mutating func clear() {
    items.removeAll()
  }

  /// Al acabar de arrastrarlo fuera: si se soltó en algún sitio se quita, salvo que se mantuviera ⌥.
  public mutating func dragEnded(_ id: UUID, dropped: Bool, keep: Bool) {
    guard dropped, !keep else { return }
    remove(id)
  }

  /// Vuelve a buscar cada archivo (`locate` da su ruta y nombre de ahora, o nil si ya no está): quita los que faltan y
  /// pone al día los que se movieron o se renombraron. Devuelve si cambió algo.
  @discardableResult
  public mutating func refresh(_ locate: (ShelfItem) -> (path: String, name: String)?) -> Bool {
    let before = items
    items = items.compactMap { item in
      guard let found = locate(item) else { return nil }
      var item = item
      item.path = found.path
      item.name = found.name
      return item
    }
    return items != before
  }
}
