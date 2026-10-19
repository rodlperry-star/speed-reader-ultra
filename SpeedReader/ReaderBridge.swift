import SwiftUI
import UIKit
import WebKit
import UniformTypeIdentifiers

/// Connects the reader page to iPadOS: hands it books opened from other apps,
/// keeps the screen awake while reading, and opens web links in Safari.
@MainActor
final class ReaderBridge: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate, UIDocumentPickerDelegate {
    weak var webView: WKWebView?
    private var pageLoaded = false
    private var pending: [(name: String, data: Data)] = []
    private var syncing = false

    // MARK: Books opened from Files, Books, Mail and other apps

    func open(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var data: Data?
        var coordError: NSError?
        // Coordinated read so files still in iCloud are downloaded first
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readURL in
            data = try? Data(contentsOf: readURL)
        }
        guard let bytes = data else {
            showError("Couldn’t open \(url.lastPathComponent).")
            return
        }
        pending.append((url.lastPathComponent, bytes))
        flush()
    }

    private func flush() {
        guard pageLoaded, let webView else { return }
        let items = pending
        pending.removeAll()
        for item in items {
            let js = "window.ssruIncoming && window.ssruIncoming(\(jsString(item.name)), '\(item.data.base64EncodedString())')"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    private func showError(_ message: String) {
        webView?.evaluateJavaScript("window.ssruError && window.ssruError(\(jsString(message)))", completionHandler: nil)
    }

    private func jsString(_ s: String) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: [s]),
              var str = String(data: d, encoding: .utf8) else { return "''" }
        str.removeFirst(); str.removeLast()   // strip the [ ] around the one-item array
        return str
    }

    // MARK: Messages from the page

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "wake":
            UIApplication.shared.isIdleTimerDisabled = (body["on"] as? Bool) ?? false
        case "pickFolder":
            pickFolder()
        case "syncNow":
            syncFolder(manual: true)
        case "forgetFolder":
            FolderSync.forget()
            sendSyncState("Sync folder removed.")
        default:
            break
        }
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoaded = true
        flush()
        syncFolder(manual: false)
    }

    // MARK: Sync folder (iCloud Drive → Speed Reader, filled by the Mac app)

    func pickFolder() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        topViewController()?.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            try FolderSync.save(folder: url)
            sendSyncState("Syncing from “\(url.lastPathComponent)”…")
            syncFolder(manual: true)
        } catch {
            sendSyncState("Couldn’t use that folder. Try choosing it again.")
        }
    }

    /// Called when the page loads and whenever the app comes back to the foreground.
    func syncFolder(manual: Bool) {
        guard pageLoaded, !syncing else { return }
        guard let folder = FolderSync.savedFolder() else {
            sendSyncState(nil)
            return
        }
        syncing = true
        if manual { sendSyncState("Checking “\(folder.lastPathComponent)”…") }
        Task {
            let result = await Task.detached(priority: .userInitiated) { FolderSync.newBooks(in: folder) }.value
            for book in result.books { pending.append((book.name, book.data)) }
            flush()
            FolderSync.markImported(result.books.map(\.key))
            var msg: String
            if let err = result.error { msg = err }
            else if result.books.isEmpty { msg = "Up to date with “\(folder.lastPathComponent)”." }
            else { msg = "Added \(result.books.count) new book\(result.books.count == 1 ? "" : "s") from “\(folder.lastPathComponent)”." }
            if result.waiting > 0 { msg += " \(result.waiting) still downloading from iCloud — they’ll come in next time." }
            sendSyncState(msg, folder: folder.lastPathComponent)
            syncing = false
        }
    }

    private func sendSyncState(_ message: String?, folder: String? = nil) {
        let name = folder ?? FolderSync.savedFolder()?.lastPathComponent
        let js = "window.ssruSyncState && window.ssruSyncState(\(name.map { jsString($0) } ?? "null"), \(message.map { jsString($0) } ?? "null"))"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func topViewController() -> UIViewController? {
        var vc = webView?.window?.rootViewController
        while let next = vc?.presentedViewController { vc = next }
        return vc
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if let url = navigationAction.request.url, let scheme = url.scheme, scheme == "http" || scheme == "https" {
            _ = await UIApplication.shared.open(url)
            return .cancel
        }
        return .allow
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        pageLoaded = false
        webView.reload()
    }
}
