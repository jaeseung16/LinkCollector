//
//  WebView.swift
//  LinkCollector
//
//  Created by Jae Seung Lee on 12/24/20.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: UIViewRepresentableContext<WebView>) -> WKWebView {
        print("url = \(url)")
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
        var parent: WebView
        
        var title: String?
        var ogTitle: String?
        
        private var url: URL?
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences, decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
            //print("navigationAction.request = \(navigationAction.request)")
            decisionHandler(.allow, preferences)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("didStartProvisionalNavigation: title = \(String(describing: webView.title)), url = \(String(describing: webView.url)), navigation = \(String(describing: navigation))")
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            print("didCommit: title = \(String(describing: webView.title)), url = \(String(describing: webView.url))")
        }
       
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            //print("didFinish: title = \(webView.title), url = \(webView.url)")
            webView.evaluateJavaScript("document.getElementsByTagName('title')[0].innerText", completionHandler: { (value: Any!, error: Error!) -> Void in
                if error != nil {
                    print("didFinish: \(String(describing: error))")
                    return
                }

                if let result = value as? String {
                    //print("didFinish: title = \(result), url = \(webView.url)")
                    self.title = result
                }
            })
            
            /*
            webView.evaluateJavaScript("document.getElementsByTagName('meta')[0].innerText", completionHandler: { (value: Any!, error: Error!) -> Void in
                if error != nil {
                    print("didFinish: \(String(describing: error))")
                    return
                }

                if let result = value as? String {
                    print("didFinish: ogTitle = \(result)")
                    self.ogTitle = result
                }
            })
 */
        }
    }
}

