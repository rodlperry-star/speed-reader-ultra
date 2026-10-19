import SwiftUI
import UIKit
import WebKit
import UniformTypeIdentifiers

/// Hosts the reader page. Everything is served from the app bundle through the app:// scheme,
/// so the reader works fully offline and keeps its library in the web view's storage.
struct ReaderWebView: UIViewRepresentable {
    let bridge: ReaderBridge

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: "app")
        config.userContentController.add(bridge, name: "native")
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = bridge
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }   // Safari → Develop menu, for debugging

        bridge.webView = webView
        webView.load(URLRequest(url: URL(string: "app://reader/index.html")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Serves files from the bundled Web folder.
@MainActor
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL = Bundle.main.resourceURL!.appendingPathComponent("Web").standardizedFileURL

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        var path = url.path
        if path.isEmpty || path == "/" { path = "/index.html" }
        let file = root.appendingPathComponent(String(path.dropFirst())).standardizedFileURL

        guard file.path.hasPrefix(root.path), let data = try? Data(contentsOf: file) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = Self.mimeType(for: file.pathExtension)
        let headers = ["Content-Type": mime, "Content-Length": String(data.count), "Access-Control-Allow-Origin": "*"]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json"
        case "woff2": return "font/woff2"
        case "png": return "image/png"
        default: return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        }
    }
}
