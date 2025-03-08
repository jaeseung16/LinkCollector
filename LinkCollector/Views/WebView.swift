//
//  WebView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/24/20.
//

import SwiftUI
import WebKit
import os

struct WebView: UIViewRepresentable {
    @EnvironmentObject var viewModel: LinkCollectorViewModel
    
    private let logger = Logger()
    
    let url: URL
    
    func makeUIView(context: UIViewRepresentableContext<WebView>) -> WKWebView {
        logger.log("url = \(url, privacy: .public)")
        let webView = WKWebView(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        webView.load(URLRequest(url: url))
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate {
        private let logger = Logger()
        
        var parent: WebView
        
        var title: String?
        var ogTitle: String?
        
        private var url: URL?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
            //logger.log("navigationAction.request = \(navigationAction.request, privacy: .public)")
            return (.allow, preferences)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            logger.log("didStartProvisionalNavigation: title = \(String(describing: webView.title), privacy: .public), url = \(String(describing: webView.url), privacy: .public), navigation = \(String(describing: navigation),privacy: .public)")
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            logger.log("didCommit: title = \(String(describing: webView.title), privacy: .public), url = \(String(describing: webView.url), privacy: .public)")
        }
       
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            //logger.log("didFinish: title = \(webView.title), url = \(webView.url, privacy: .public)")
            webView.evaluateJavaScript("document.getElementsByTagName('title')[0].innerText", completionHandler: { (value: Any!, error: Error!) -> Void in
                if let error = error {
                    self.logger.log("didFinish: \(error.localizedDescription, privacy: .public)")
                    return
                }

                if let result = value as? String {
                    //logger.log("didFinish: title = \(result, privacy: .public), url = \(webView.url, privacy: .public)")
                    self.title = result
                }
            })
            
        /*
            webView.evaluateJavaScript("document.getElementsByTagName('meta')[0].innerText", completionHandler: { (value: Any!, error: Error!) -> Void in
                if let error = error {
                    logger.log("didFinish: \(error.localizedDescription, privacy: .public))")
                    return
                }

                if let result = value as? String {
                    logger.log("didFinish: ogTitle = \(result, privacy: .public)")
                    self.ogTitle = result
                }
            })
        */
        }
    }
}

