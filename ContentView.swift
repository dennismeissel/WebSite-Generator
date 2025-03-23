//
//  ContentView.swift
//  WebSite Generator
//
//  Created by Dennis Meissel on 23.03.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var htmlContent = ""
    @State private var showHTMLCache = true

    var body: some View {
        HStack(spacing: 0) {
            ChatView(htmlContent: $htmlContent)
                .frame(width: 300)

            Divider()

            if showHTMLCache {
                VStack {
                    Text("HTML")
                        .font(.headline)
                        .padding(.top)

                    TextEditor(text: $htmlContent)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minWidth: 250, idealWidth: 300)

                Divider()
            }

            WebView(htmlContent: $htmlContent)
                .id(htmlContent) // erzwingt Reload
                .frame(minWidth: 400)
        }
        .frame(minWidth: 750, minHeight: 500)
        .toolbar {
            ToolbarItem {
                Button(action: {
                    showHTMLCache.toggle()
                }) {
                    Image(systemName: showHTMLCache ? "eye.slash.fill" : "eye.fill")
                }
                .help("HTML show/hide")
            }
        }
    }
}



#Preview {
    ContentView()
}
