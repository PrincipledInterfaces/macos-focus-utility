import Foundation
import EventKit
import Contacts

// MARK: - Message Models

enum MessageSource: String, Codable {
    case email = "Mail"
    case imessage = "Messages"
    case slack = "Slack"

    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .imessage: return "message.fill"
        case .slack: return "bubble.left.and.bubble.right.fill"
        }
    }
}

struct UnifiedMessage: Identifiable, Codable {
    let id: UUID
    let source: MessageSource
    let sender: String
    let subject: String?
    let preview: String
    let timestamp: Date
    let isRead: Bool
    let isStarred: Bool

    init(
        id: UUID = UUID(),
        source: MessageSource,
        sender: String,
        subject: String? = nil,
        preview: String,
        timestamp: Date = Date(),
        isRead: Bool = false,
        isStarred: Bool = false
    ) {
        self.id = id
        self.source = source
        self.sender = sender
        self.subject = subject
        self.preview = preview
        self.timestamp = timestamp
        self.isRead = isRead
        self.isStarred = isStarred
    }

    var timeAgo: String {
        let interval = Date().timeIntervalSince(timestamp)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 {
            return "Just now"
        } else if minutes < 60 {
            return "\(minutes)m"
        } else if hours < 24 {
            return "\(hours)h"
        } else if days < 7 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: timestamp)
        }
    }
}

// MARK: - Unified Inbox Service

class UnifiedInboxService: ObservableObject {
    @Published var messages: [UnifiedMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var emailCheckTimer: Timer?
    private var imessageCheckTimer: Timer?
    private var slackCheckTimer: Timer?

    init() {
        // Disabled automatic refresh to prevent AppleScript dialogs
        // startPeriodicRefresh()
        // refreshAllMessages()
    }

    deinit {
        stopPeriodicRefresh()
    }

    // MARK: - Public Methods

    func refreshAllMessages() {
        isLoading = true
        errorMessage = nil

        Task {
            await MainActor.run {
                var allMessages: [UnifiedMessage] = []

                // Fetch from all sources
                allMessages.append(contentsOf: fetchEmailMessages())
                allMessages.append(contentsOf: fetchiMessageMessages())
                allMessages.append(contentsOf: fetchSlackMessages())

                // Sort by timestamp
                self.messages = allMessages.sorted { $0.timestamp > $1.timestamp }
                self.isLoading = false
            }
        }
    }

    func markAsRead(_ message: UnifiedMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updatedMessage = message
            messages[index] = UnifiedMessage(
                id: updatedMessage.id,
                source: updatedMessage.source,
                sender: updatedMessage.sender,
                subject: updatedMessage.subject,
                preview: updatedMessage.preview,
                timestamp: updatedMessage.timestamp,
                isRead: true,
                isStarred: updatedMessage.isStarred
            )
        }
    }

    func toggleStar(_ message: UnifiedMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            var updatedMessage = message
            messages[index] = UnifiedMessage(
                id: updatedMessage.id,
                source: updatedMessage.source,
                sender: updatedMessage.sender,
                subject: updatedMessage.subject,
                preview: updatedMessage.preview,
                timestamp: updatedMessage.timestamp,
                isRead: updatedMessage.isRead,
                isStarred: !updatedMessage.isStarred
            )
        }
    }

    // MARK: - Email Fetching

    private func fetchEmailMessages() -> [UnifiedMessage] {
        // Use AppleScript to fetch Mail.app messages
        let script = """
        tell application "Mail"
            set recentMessages to messages 1 thru 20 of inbox
            set messageList to ""
            repeat with theMessage in recentMessages
                set senderName to extract name from sender of theMessage
                set messageSubject to subject of theMessage
                set messageContent to content of theMessage
                set messageDate to date received of theMessage
                set isReadStatus to read status of theMessage

                -- Truncate content to first 150 characters
                if length of messageContent > 150 then
                    set messageContent to text 1 thru 150 of messageContent
                end if

                set messageList to messageList & senderName & "|||" & messageSubject & "|||" & messageContent & "|||" & (messageDate as string) & "|||" & (isReadStatus as string) & ":::"
            end repeat
            return messageList
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return []
        }

        var errorDict: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorDict)

        if errorDict != nil {
            return []
        }

        var messages: [UnifiedMessage] = []

        // Parse AppleScript result
        if let resultString = result.stringValue {
            let messageEntries = resultString.components(separatedBy: ":::")

            for entry in messageEntries {
                if entry.isEmpty { continue }

                let components = entry.components(separatedBy: "|||")
                guard components.count >= 5 else { continue }

                let sender = components[0]
                let subject = components[1]
                let preview = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let dateString = components[3]
                let isReadString = components[4]

                // Parse date (simplified)
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                let timestamp = formatter.date(from: dateString) ?? Date()

                let isRead = isReadString.lowercased().contains("true")

                let message = UnifiedMessage(
                    source: .email,
                    sender: sender,
                    subject: subject,
                    preview: preview,
                    timestamp: timestamp,
                    isRead: isRead
                )

                messages.append(message)
            }
        }

        return messages
    }

    // MARK: - iMessage Fetching

    private func fetchiMessageMessages() -> [UnifiedMessage] {
        // Use AppleScript to fetch Messages
        let script = """
        tell application "Messages"
            set recentChats to {}
            set chatList to {}

            try
                -- Get recent chats (last 10)
                repeat with i from 1 to 10
                    try
                        set theChat to chat i
                        set theMessages to messages of theChat
                        if (count of theMessages) > 0 then
                            set lastMessage to item 1 of theMessages
                            set chatParticipants to participants of theChat
                            if (count of chatParticipants) > 0 then
                                set senderHandle to item 1 of chatParticipants
                                set senderName to name of senderHandle
                                set messageText to text of lastMessage
                                set messageTime to time sent of lastMessage

                                -- Truncate message
                                if length of messageText > 150 then
                                    set messageText to text 1 thru 150 of messageText
                                end if

                                set chatList to chatList & senderName & "|||" & messageText & "|||" & (messageTime as string) & ":::"
                            end if
                        end if
                    end try
                end repeat
            end try

            return chatList as string
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else {
            return []
        }

        var errorDict: NSDictionary?
        let result = appleScript.executeAndReturnError(&errorDict)

        if errorDict != nil {
            return []
        }

        var messages: [UnifiedMessage] = []

        if let resultString = result.stringValue {
            let messageEntries = resultString.components(separatedBy: ":::")

            for entry in messageEntries {
                if entry.isEmpty { continue }

                let components = entry.components(separatedBy: "|||")
                guard components.count >= 3 else { continue }

                let sender = components[0]
                let preview = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let dateString = components[2]

                // Parse date
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                let timestamp = formatter.date(from: dateString) ?? Date()

                let message = UnifiedMessage(
                    source: .imessage,
                    sender: sender,
                    subject: nil,
                    preview: preview,
                    timestamp: timestamp,
                    isRead: true
                )

                messages.append(message)
            }
        }

        return messages
    }

    // MARK: - Slack Fetching

    private func fetchSlackMessages() -> [UnifiedMessage] {
        // Slack API integration
        // Would require Slack API token stored in UserDefaults or Keychain

        guard let slackToken = UserDefaults.standard.string(forKey: "slackAPIToken"),
              !slackToken.isEmpty else {
            return []
        }

        // Slack API endpoint for conversations.history
        guard let url = URL(string: "https://slack.com/api/conversations.history") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(slackToken)", forHTTPHeaderField: "Authorization")

        var messages: [UnifiedMessage] = []

        // Note: This should be async, but for simplicity keeping synchronous for now
        // In production, this would use async/await or completion handlers

        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            guard let data = data,
                  error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let messagesArray = json["messages"] as? [[String: Any]] else {
                return
            }

            for messageDict in messagesArray.prefix(10) {
                guard let text = messageDict["text"] as? String,
                      let user = messageDict["user"] as? String,
                      let tsString = messageDict["ts"] as? String,
                      let timestamp = Double(tsString) else {
                    continue
                }

                let date = Date(timeIntervalSince1970: timestamp)
                let preview = text.count > 150 ? String(text.prefix(150)) : text

                let message = UnifiedMessage(
                    source: .slack,
                    sender: user,
                    subject: nil,
                    preview: preview,
                    timestamp: date,
                    isRead: true
                )

                messages.append(message)
            }
        }.resume()

        semaphore.wait()

        return messages
    }

    // MARK: - Periodic Refresh

    private func startPeriodicRefresh() {
        // Refresh every 30 seconds
        emailCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshAllMessages()
        }

        imessageCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshAllMessages()
        }

        slackCheckTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.refreshAllMessages()
        }
    }

    private func stopPeriodicRefresh() {
        emailCheckTimer?.invalidate()
        imessageCheckTimer?.invalidate()
        slackCheckTimer?.invalidate()
    }
}
