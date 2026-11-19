import WebKit

final class LegacyStudyImport: NSObject, WKURLSchemeHandler, WKNavigationDelegate {
    private let progress: StudyProgress
    private var reader: WKWebView?

    init(progress: StudyProgress) {
        self.progress = progress
    }

    func start() {
        guard progress.needsLegacyMigration, reader == nil,
              let url = URL(string: "capacitor://localhost/") else { return }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.setURLSchemeHandler(self, forURLScheme: "capacitor")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        reader = webView
        webView.load(URLRequest(url: url))
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }
        let html = Data("<!doctype html><meta charset=utf-8><title>Alef data migration</title>".utf8)
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: "text/html", expectedContentLength: html.count, textEncodingName: "utf-8"))
        urlSchemeTask.didReceive(html)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("""
            Object.fromEntries(Object.keys(localStorage)
                .filter(key => key.startsWith('alef.'))
                .map(key => [key, localStorage.getItem(key)]))
            """) { [weak self] result, _ in
            if let values = result as? [String: String] { self?.progress.completeLegacyMigration(values) }
            self?.reader = nil
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reader = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        reader = nil
    }
}
