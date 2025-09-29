import SwiftUI
import WebKit

struct ChromiumWebView: NSViewRepresentable {
    let url: String
    @Binding var isLoading: Bool
    let onURLChange: (String) -> Void
    let onTitleChange: (String) -> Void
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Configure for better Chromium-like behavior
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Add user agent that mimics Chrome
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36"
        webView.navigationDelegate = context.coordinator
        
        // Configure additional Chromium-like settings
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        
        // Load initial URL
        if let url = URL(string: url) {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString != url,
           let newURL = URL(string: url) {
            webView.load(URLRequest(url: newURL))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ChromiumWebView
        
        init(_ parent: ChromiumWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                
                if let url = webView.url?.absoluteString {
                    self.parent.onURLChange(url)
                }
                
                if let title = webView.title, !title.isEmpty {
                    self.parent.onTitleChange(title)
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation by default (Chromium-like behavior)
            decisionHandler(.allow)
        }
    }
}