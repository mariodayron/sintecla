import AppKit
import WebKit

/// HTML → PDF paginado en A4. WebKit imprime a un archivo desde una ventana fuera de pantalla (createPDF daría
/// una sola página larga). Todo en el hilo principal.
@MainActor
final class PDFRenderer: NSObject, WKNavigationDelegate {
  struct Failure: Error {}

  /// Ancho de la zona imprimible en píxeles CSS (A4 menos 1,5 cm por lado: 510 pt = 680 px), para imprimir a escala 1:1.
  static let contentWidth: CGFloat = 680
  private var loaded: CheckedContinuation<Void, Error>?
  private var printed: CheckedContinuation<Bool, Never>?

  func render(html: String, to url: URL) async throws {
    _ = NSApplication.shared
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: Self.contentWidth, height: 900))
    web.navigationDelegate = self
    let window = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = web
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      loaded = continuation
      web.loadHTMLString(html, baseURL: nil)
    }
    let info = NSPrintInfo()
    info.paperSize = NSSize(width: 595.28, height: 841.89)
    info.topMargin = 42.5
    info.bottomMargin = 42.5
    info.leftMargin = 42.5
    info.rightMargin = 42.5
    info.horizontalPagination = .fit
    info.verticalPagination = .automatic
    info.jobDisposition = .save
    info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url
    let operation = web.printOperation(with: info)
    operation.showsPrintPanel = false
    operation.showsProgressPanel = false
    operation.view?.frame = web.bounds
    let ok = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
      printed = continuation
      operation.runModal(for: window, delegate: self,
                         didRun: #selector(printOperationDidRun(_:success:contextInfo:)), contextInfo: nil)
    }
    guard ok, FileManager.default.fileExists(atPath: url.path) else { throw Failure() }
  }

  @objc private func printOperationDidRun(_ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?) {
    printed?.resume(returning: success)
    printed = nil
  }

  nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    MainActor.assumeIsolated {
      loaded?.resume()
      loaded = nil
    }
  }

  nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    MainActor.assumeIsolated {
      loaded?.resume(throwing: error)
      loaded = nil
    }
  }
}
