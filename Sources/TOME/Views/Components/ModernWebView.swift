import SwiftUI
import WebKit

struct ModernWebView: NSViewRepresentable {
    let url: String
    @Binding var isLoading: Bool
    let onURLChange: (String) -> Void
    let onTitleChange: (String) -> Void
    let onContentLoad: (String) -> Void
    let webViewManager: WebViewManager?
    
    // WebView reference for navigation controls
    @State private var webViewRef: WKWebView?
    
    init(url: String, isLoading: Binding<Bool>, onURLChange: @escaping (String) -> Void, onTitleChange: @escaping (String) -> Void, onContentLoad: @escaping (String) -> Void = { _ in }, webViewManager: WebViewManager? = nil) {
        self.url = url
        self._isLoading = isLoading
        self.onURLChange = onURLChange
        self.onTitleChange = onTitleChange
        self.onContentLoad = onContentLoad
        self.webViewManager = webViewManager
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Enable essential web features for modern compatibility
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // Enable modern web standards and security
        if #available(macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            configuration.upgradeKnownHostsToHTTPS = true
        }
        
        // Enable developer features for better debugging
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        configuration.preferences.setValue(true, forKey: "fullScreenEnabled")
        configuration.preferences.setValue(true, forKey: "DOMPasteAllowed")
        configuration.preferences.setValue(true, forKey: "javaScriptCanAccessClipboard")
        
        // Set up user content controller for JavaScript injection
        let contentController = WKUserContentController()
        injectCompatibilityScripts(contentController: contentController)
        configuration.userContentController = contentController
        
        // Create webview with enhanced configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Store reference for navigation controls
        DispatchQueue.main.async {
            self.webViewRef = webView
            // Connect to WebViewManager if provided
            self.webViewManager?.setWebView(webView)
        }
        
        // Use Safari user agent for maximum compatibility (Google prefers Safari to Chrome UA on macOS)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15"
        
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Enable modern browser features
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.allowsLinkPreview = true
        
        // Additional compatibility settings
        if #available(macOS 11.0, *) {
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Configure for best performance
        webView.configuration.processPool = WKProcessPool()
        webView.configuration.suppressesIncrementalRendering = false
        
        // Load initial URL with proper headers
        if let url = URL(string: url) {
            var request = URLRequest(url: url)
            
            // Add comprehensive headers for Safari compatibility (better than Chrome headers for Google)
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
            request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
            request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
            request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
            request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
            request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
            
            webView.load(request)
        }
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url?.absoluteString != url,
           let newURL = URL(string: url) {
            var request = URLRequest(url: newURL)
            
            // Add the same Safari-compatible headers for consistency
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
            request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")
            request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
            request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
            request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
            
            webView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - JavaScript and CSS Injection for Modern Web Compatibility
    
    private func injectCompatibilityScripts(contentController: WKUserContentController) {
        // CSS injection for modern styling compatibility
        let cssScript = """
        var style = document.createElement('style');
        style.innerHTML = `
            * {
                -webkit-font-smoothing: antialiased;
                -moz-osx-font-smoothing: grayscale;
            }
            
            body {
                zoom: 1;
                -webkit-text-size-adjust: 100%;
            }
            
            /* Enable modern CSS features */
            .modern-layout {
                display: -webkit-box;
                display: -webkit-flex;
                display: flex;
            }
            
            /* Fix potential rendering issues */
            input, textarea, select {
                -webkit-appearance: none;
                border-radius: 0;
            }
            
            /* Ensure proper viewport handling */
            @viewport {
                width: device-width;
                zoom: 1.0;
            }
        `;
        document.head.appendChild(style);
        """
        
        let cssInjection = WKUserScript(
            source: cssScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        // JavaScript polyfills for modern web features
        let jsPolyfills = """
        // Modern JavaScript polyfills
        if (!window.fetch) {
            window.fetch = function(url, options) {
                return new Promise(function(resolve, reject) {
                    var xhr = new XMLHttpRequest();
                    xhr.open(options?.method || 'GET', url);
                    xhr.onload = function() {
                        resolve({
                            ok: xhr.status >= 200 && xhr.status < 300,
                            status: xhr.status,
                            text: function() { return Promise.resolve(xhr.responseText); },
                            json: function() { return Promise.resolve(JSON.parse(xhr.responseText)); }
                        });
                    };
                    xhr.onerror = reject;
                    if (options?.body) xhr.send(options.body);
                    else xhr.send();
                });
            };
        }
        
        // Element.matches polyfill
        if (!Element.prototype.matches) {
            Element.prototype.matches = Element.prototype.msMatchesSelector;
        }
        
        // CustomEvent polyfill for older web content
        if (typeof window.CustomEvent !== 'function') {
            function CustomEvent(event, params) {
                params = params || { bubbles: false, cancelable: false, detail: undefined };
                var evt = document.createEvent('CustomEvent');
                evt.initCustomEvent(event, params.bubbles, params.cancelable, params.detail);
                return evt;
            }
            CustomEvent.prototype = window.Event.prototype;
            window.CustomEvent = CustomEvent;
        }
        
        // Viewport meta tag injection for responsive design
        if (!document.querySelector('meta[name="viewport"]')) {
            var viewport = document.createElement('meta');
            viewport.name = 'viewport';
            viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.head.appendChild(viewport);
        }
        """
        
        let jsInjection = WKUserScript(
            source: jsPolyfills,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        contentController.addUserScript(cssInjection)
        contentController.addUserScript(jsInjection)
    }
    
    // MARK: - Navigation Methods
    
    func goBack() {
        webViewRef?.goBack()
    }
    
    func goForward() {
        webViewRef?.goForward()
    }
    
    func reload() {
        webViewRef?.reload()
    }
    
    func canGoBack() -> Bool {
        return webViewRef?.canGoBack ?? false
    }
    
    func canGoForward() -> Bool {
        return webViewRef?.canGoForward ?? false
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: ModernWebView
        
        init(_ parent: ModernWebView) {
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
                
                // Extract page content for AI analysis
                let script = """
                    document.body.innerText || document.documentElement.innerText || '';
                """
                
                webView.evaluateJavaScript(script) { result, error in
                    if let content = result as? String {
                        DispatchQueue.main.async {
                            self.parent.onContentLoad(content)
                        }
                    }
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                print("❌ Navigation cancelled: No URL provided")
                decisionHandler(.cancel)
                return
            }
            
            let urlString = url.absoluteString
            
            // Log navigation for debugging
            print("🌐 Navigation to: \(urlString)")
            print("🔄 Navigation type: \(navigationAction.navigationType.rawValue)")
            
            // Block empty, blank, or malformed URLs
            if urlString.isEmpty || urlString == "about:blank" || urlString.hasPrefix("about:") {
                print("❌ Blocked blank/about URL: \(urlString)")
                decisionHandler(.cancel)
                return
            }
            
            // Handle Google OAuth by redirecting to Safari (compliant approach)
            if urlString.contains("accounts.google.com/oauth") || 
               urlString.contains("accounts.google.com/signin") {
                print("🔐 Redirecting OAuth to Safari: \(urlString)")
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            // Block javascript: URLs for security
            if url.scheme == "javascript" {
                print("🚫 Blocked JavaScript URL")
                decisionHandler(.cancel)
                return
            }
            
            // Handle target="_blank" links (new window/tab requests)
            if navigationAction.targetFrame == nil {
                print("🎯 Target=_blank link detected, loading in current view: \(urlString)")
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            
            // Handle Google search redirects properly
            if urlString.contains("google.com") && urlString.contains("/url?") {
                // Extract the actual URL from Google's redirect wrapper
                if let actualURL = extractGoogleRedirectURL(from: urlString) {
                    print("🔗 Google redirect detected, extracting: \(actualURL)")
                    if let redirectURL = URL(string: actualURL) {
                        DispatchQueue.main.async {
                            webView.load(URLRequest(url: redirectURL))
                        }
                    }
                    decisionHandler(.cancel)
                    return
                }
            }
            
            // Allow all HTTP/HTTPS navigation
            if url.scheme == "http" || url.scheme == "https" {
                print("✅ Allowing HTTP/HTTPS navigation")
                decisionHandler(.allow)
                return
            }
            
            // Handle other schemes (mailto:, tel:, etc.) by opening externally
            if let scheme = url.scheme, scheme != "http" && scheme != "https" {
                print("📱 Opening external scheme: \(scheme)")
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            // Default: allow the navigation
            print("✅ Allowing navigation (default)")
            decisionHandler(.allow)
        }
        
        // Helper function to extract actual URL from Google redirect
        private func extractGoogleRedirectURL(from googleURL: String) -> String? {
            guard let urlComponents = URLComponents(string: googleURL),
                  let queryItems = urlComponents.queryItems else {
                return nil
            }
            
            // Look for various URL parameters in Google's redirect
            let urlParams = ["url", "q", "u", "target", "destination"]
            for param in urlParams {
                for item in queryItems where item.name == param {
                    if let value = item.value, !value.isEmpty {
                        // Decode URL encoding
                        let decodedURL = value.removingPercentEncoding ?? value
                        
                        // Ensure it's a valid HTTP/HTTPS URL
                        if decodedURL.hasPrefix("http://") || decodedURL.hasPrefix("https://") {
                            return decodedURL
                        }
                    }
                }
            }
            
            return nil
        }
        
        // Handle response policy for redirects
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            print("🔄 Response from: \(navigationResponse.response.url?.absoluteString ?? "unknown")")
            
            // Allow all HTTP responses including redirects
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
                
                // Handle redirects (3xx status codes)
                if (300...399).contains(httpResponse.statusCode) {
                    print("🔀 Redirect detected: \(httpResponse.statusCode)")
                    decisionHandler(.allow)
                    return
                }
            }
            
            // Default: allow the response
            decisionHandler(.allow)
        }
        
        // Handle popup windows
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Handle popup requests by navigating in the same webview
            if let url = navigationAction.request.url {
                let urlString = url.absoluteString
                print("🪟 Popup window requested for: \(urlString)")
                
                // Block blank or malformed popup URLs
                if urlString.isEmpty || urlString == "about:blank" || urlString.hasPrefix("about:") {
                    print("❌ Blocked blank popup URL")
                    return nil
                }
                
                // For valid URLs, load in the same webview instead of creating a popup
                if url.scheme == "http" || url.scheme == "https" {
                    print("🔄 Loading popup URL in current view: \(urlString)")
                    webView.load(URLRequest(url: url))
                } else {
                    print("📱 Opening popup URL externally: \(urlString)")
                    NSWorkspace.shared.open(url)
                }
            }
            return nil
        }
        
        // Handle JavaScript alerts
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = NSAlert()
            alert.messageText = "Website Alert"
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.runModal()
            completionHandler()
        }
    }
}