//
//  WebView.swift
//  WebSite Generator
//
//  Created by Dennis Meissel on 23.03.2025.
//


import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    @Binding var htmlContent: String

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString("", baseURL: nil)
        // Dann kleinen Delay und HTML neu laden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            nsView.loadHTMLString(htmlContent, baseURL: nil)
        }
    }
}
