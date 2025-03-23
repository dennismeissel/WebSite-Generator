//
//  ChatView.swift
//  WebSite Generator
//
//  Created by Dennis Meissel on 23.03.2025.
//

import SwiftUI

struct ChatView: View {
    @Binding var htmlContent: String

    @State private var messages: [ChatMessage] = [
        ChatMessage(content: "Describe a website you want to build", isUser: false)
    ]

    @State private var inputText: String = ""
    @State private var currentStreamMessage: String = ""

    private let SYSTEM_PROMPT = """
    You are an AI that can edit HTML.
    The user's request refers only to the following HTML.
    Response format:
    First, write a short, helpful text response.
    Then, return the complete, updated HTML in a separate <html>...</html> block.
    Example:
    Of course! I’ve updated the headline.

    <html>
        <h1>Welcome to my page!</h1>
    </html>
    """

    var body: some View {
        VStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { message in
                            HStack {
                                if message.isUser { Spacer() }

                                Text(message.content)
                                    .padding(10)
                                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(message.isUser ? .white : .black)
                                    .cornerRadius(10)
                                    .frame(maxWidth: 300, alignment: message.isUser ? .trailing : .leading)

                                if !message.isUser { Spacer() }
                            }
                            .id(message.id)
                        }
                        if !currentStreamMessage.isEmpty {
                            HStack {
                                Text(currentStreamMessage)
                                    .padding(10)
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.black)
                                    .cornerRadius(10)
                                    .frame(maxWidth: 300, alignment: .leading)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation {
                            scrollProxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    TextField("Write a message...", text: $inputText)
                        .onSubmit { sendMessage() }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button(action: sendMessage) {
                        Text("Send")
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                HStack {
                    Button("Reset chat") {
                        messages = []
                        inputText = ""
                        htmlContent = "<h1>Welcome!</h1>"
                    }
                    .foregroundColor(.red)
                    Spacer()
                }
            }
            .padding()
        }
        .frame(minWidth: 300, idealWidth: 350)
    }

    private func extractHTML(from text: String) -> String? {
        let pattern = "<html[\\s\\S]*?</html>"
        if let range = text.range(of: pattern, options: .regularExpression) {
            return String(text[range])
        } else {
            print("HTML not found in text:\n\(text)")
            return nil
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let userMessage = ChatMessage(content: inputText, isUser: true)
        messages.append(userMessage)
        currentStreamMessage = ""

        let combinedSystemPrompt = SYSTEM_PROMPT + """

        Current HTML:
        \(htmlContent)
        """

        let payload: [String: Any] = [
            "messages": [
                ["role": "system", "content": combinedSystemPrompt],
                ["role": "user", "content": inputText]
            ],
            "model": getSecret("LLM_MODEL"),
            "max_tokens": 8192,
            "temperature": 0,
            "stream": true
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("Error creating JSON payload")
            return
        }

        let request = createRequest(jsonData: jsonData)

        let task = URLSession(configuration: .default, delegate: StreamingDelegate(
            onText: { delta in
                DispatchQueue.main.async {
                    self.currentStreamMessage += delta
                }
            },
            onFinish: {
                DispatchQueue.main.async {
                    let responseTextOnly = self.currentStreamMessage.components(separatedBy: "<html").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? self.currentStreamMessage
                    self.messages.append(ChatMessage(content: responseTextOnly, isUser: false))

                    if let extractedHTML = extractHTML(from: self.currentStreamMessage) {
                        self.htmlContent = extractedHTML
                    }

                    self.currentStreamMessage = ""
                }
            }
        ), delegateQueue: nil).dataTask(with: request)

        task.resume()
        inputText = ""
    }

    private func createRequest(jsonData: Data) -> URLRequest {
        let urlString = getSecret("LLM_URL")
        let apiKey = getSecret("LLM_KEY")

        guard let url = URL(string: urlString) else {
            fatalError("Invalid URL in Secrets.plist")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        return request
    }

    private func getSecret(_ key: String) -> String {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let value = dict[key] as? String else {
                fatalError("Secrets.plist or key \(key) not found!")
            }
        return value
    }
}

class StreamingDelegate: NSObject, URLSessionDataDelegate {
    private var buffer = Data()
    private let onText: (String) -> Void
    private let onFinish: () -> Void

    init(onText: @escaping (String) -> Void, onFinish: @escaping () -> Void) {
        self.onText = onText
        self.onFinish = onFinish
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        guard let string = String(data: data, encoding: .utf8) else { return }

        let lines = string.components(separatedBy: "\n")
        for line in lines {
            guard line.hasPrefix("data:") else { continue }
            let clean = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if clean == "[DONE]" {
                onFinish()
                return
            }
            if let jsonData = clean.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let delta = ((json["choices"] as? [[String: Any]])?.first?["delta"] as? [String: Any])?["content"] as? String {
                onText(delta)
            }
        }
    }
}
