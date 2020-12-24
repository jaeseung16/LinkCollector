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
        let configuration = WKWebViewConfiguration()
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        
    }
    
}

