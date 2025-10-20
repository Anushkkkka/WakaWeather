import SwiftUI

// Small model for chat messages
struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let date = Date()
}

// ViewModel: handles networking and messages
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isSending = false
    @Published var errorMessage: String?

    // Change this for device testing:
    // - simulator: use 127.0.0.1
    // - physical device: use your Mac's LAN IP, e.g. http://192.168.1.106:8000/chat
    private var endpointString = "http://127.0.0.1:8000/chat"

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // append user message immediately
        let userMsg = ChatMessage(text: trimmed, isUser: true)
        messages.append(userMsg)

        isSending = true
        errorMessage = nil

        defer { isSending = false }

        do {
            let reply = try await postChatRequest(message: trimmed)
            let ai = ChatMessage(text: reply, isUser: false)
            messages.append(ai)
        } catch {
            errorMessage = error.localizedDescription
            let failReply = ChatMessage(text: "Could not reach server. Tap Retry.", isUser: false)
            messages.append(failReply)
        }
    }

    private func postChatRequest(message: String) async throws -> String {
        guard let url = URL(string: endpointString) else {
            throw URLError(.badURL)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["message": message]
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: req, delegate: nil)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "ChatHTTP", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }

        // Expect: { "reply": "..." }
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let reply = decoded?["reply"] as? String {
            return reply
        } else {
            // fallback: return raw data as string
            return String(data: data, encoding: .utf8) ?? "No response"
        }
    }

    // Convenience for retrying the last user message
    func retryLastUserMessage() async {
        guard let lastUser = messages.last(where: { $0.isUser }) else { return }
        await send(lastUser.text)
    }
}

// MARK: - Chat View
struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @State private var inputText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(vm.messages) { msg in
                            messageRow(msg)
                                .id(msg.id)
                        }

                        if vm.isSending {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .background(Color(UIColor.systemGroupedBackground))
                .onChange(of: vm.messages.count) { _ in
                    // scroll to bottom
                    if let last = vm.messages.last {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // error banner
            if let err = vm.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(err).font(.caption)
                    Spacer()
                    Button("Retry") {
                        Task { await vm.retryLastUserMessage() }
                    }
                }
                .padding(8)
                .background(Color.yellow.opacity(0.9))
            }

            // input area
            inputBar
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemBackground).opacity(0.98))
        }
        .navigationTitle("AI Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack {
            Image(systemName: "sparkles")
            Text("Ask WakaWeather")
                .font(.headline)
            Spacer()
            Button(action: {
                // clear chat
                vm.messages.removeAll()
            }) {
                Image(systemName: "trash")
            }
            .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private func messageRow(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.isUser {
                Spacer()
                TextBubble(text: msg.text, isUser: true)
            } else {
                TextBubble(text: msg.text, isUser: false)
                Spacer()
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask about the weather...", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .disabled(vm.isSending)
                .onSubmit {
                    Task {
                        await sendAndClear()
                    }
                }

            Button(action: {
                Task {
                    await sendAndClear()
                }
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.title2)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSending)
        }
    }

    private func sendAndClear() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        await vm.send(text)
    }
}

// MARK: - Reusable bubble view
struct TextBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        Text(text)
            .padding(12)
            .foregroundColor(isUser ? Color.white : Color.primary)
            .background(isUser ? Color.accentColor : Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isUser ? .trailing : .leading)
            .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Preview
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatView()
        }
    }
}

