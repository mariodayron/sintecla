import AppKit
import Observation
import QuickLookThumbnailing
import SinteclaCore

/// El estante guardado (spec «Estante y avisos» §3.4): la lista en `estante.json`, con un marcador por archivo para
/// encontrarlo aunque se mueva o se renombre, y la miniatura de cada uno.
@MainActor @Observable
final class ShelfStore {
  private(set) var shelf: Shelf
  private(set) var thumbnails: [UUID: NSImage] = [:]
  @ObservationIgnored private let url: URL

  init(url: URL = AppPaths.shelfURL) {
    self.url = url
    shelf = JSONFileStore.load(Shelf.self, from: url) ?? Shelf()
    refresh()
  }

  var items: [ShelfItem] { shelf.items }

  /// Los archivos soltados en la isla, al final y sin repetir.
  func add(_ urls: [URL]) {
    let items = urls.compactMap { url -> ShelfItem? in
      guard let bookmark = try? url.bookmarkData() else { return nil }
      return ShelfItem(path: url.path, name: url.lastPathComponent, bookmark: bookmark)
    }
    guard shelf.add(items) > 0 else { return }
    save()
  }

  func remove(_ id: UUID) {
    shelf.remove(id)
    thumbnails[id] = nil
    save()
  }

  func clear() {
    shelf.clear()
    thumbnails.removeAll()
    save()
  }

  /// Sacado arrastrando: fuera, salvo que no se soltara en ningún sitio o se mantuviera ⌥.
  func dragEnded(_ id: UUID, dropped: Bool, keep: Bool) {
    shelf.dragEnded(id, dropped: dropped, keep: keep)
    if !shelf.items.contains(where: { $0.id == id }) { thumbnails[id] = nil }
    save()
  }

  /// Dónde está ahora el archivo, o nil si ya no se encuentra (borrado o en la Papelera).
  func url(of item: ShelfItem) -> URL? {
    var stale = false
    guard let url = try? URL(resolvingBookmarkData: item.bookmark, bookmarkDataIsStale: &stale),
          FileManager.default.fileExists(atPath: url.path),
          !url.path.contains("/.Trash/") else { return nil }
    return url
  }

  func open(_ item: ShelfItem) {
    guard let url = url(of: item) else { return refresh() }
    NSWorkspace.shared.open(url)
  }

  /// Al arrancar y al abrir la desplegada: quita los que faltan y sigue a los que se movieron.
  func refresh() {
    if shelf.refresh({ [self] item in url(of: item).map { (path: $0.path, name: $0.lastPathComponent) } }) { save() }
    loadThumbnails()
  }

  private func save() {
    try? JSONFileStore.save(shelf, to: url)
    loadThumbnails()
  }

  /// El icono de Finder al momento y, cuando llega, la miniatura (de una imagen o un PDF, por ejemplo).
  private func loadThumbnails() {
    for item in shelf.items where thumbnails[item.id] == nil {
      thumbnails[item.id] = NSWorkspace.shared.icon(forFile: item.path)
      let request = QLThumbnailGenerator.Request(fileAt: URL(fileURLWithPath: item.path),
                                                 size: CGSize(width: 64, height: 64), scale: 2,
                                                 representationTypes: .thumbnail)
      let id = item.id
      QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] thumbnail, _ in
        guard let image = thumbnail?.nsImage else { return }
        Task { @MainActor in
          if self?.thumbnails[id] != nil { self?.thumbnails[id] = image }
        }
      }
    }
  }
}
