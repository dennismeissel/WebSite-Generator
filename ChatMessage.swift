//
//  ChatMessage.swift
//  WebSite Generator
//
//  Created by Dennis Meissel on 23.03.2025.
//


import Foundation

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}
