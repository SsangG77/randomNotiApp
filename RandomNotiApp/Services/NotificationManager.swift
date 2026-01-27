//
//  NotificationManager.swift
//  RandomNotiApp
//

import Foundation
import UserNotifications
import Combine

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var items: [NotificationItem] = [] {
        didSet {
            saveItems()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let itemsKey = "notificationItems"

    override init() {
        super.init()
        loadItems()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - 권한 요청
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("알림 권한 요청 오류: \(error.localizedDescription)")
            }
            if granted {
                print("알림 권한 허용됨")
            }
        }
    }

    // MARK: - 데이터 저장/로드
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            userDefaults.set(encoded, forKey: itemsKey)
        }
    }

    private func loadItems() {
        if let data = userDefaults.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([NotificationItem].self, from: data) {
            items = decoded
        }
    }

    // MARK: - 알림 아이템 관리
    func addItem(_ item: NotificationItem) {
        var newItem = item
        // 새 아이템은 첫 메시지를 보내기 위해 대기 상태를 false로 설정
        newItem.isWaitingForReply = false
        items.append(newItem)
        if newItem.isEnabled {
            scheduleNextNotification(for: newItem.id)
        }
    }

    func updateItem(_ item: NotificationItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }

    func deleteItem(_ item: NotificationItem) {
        cancelNotifications(for: item.id)
        items.removeAll { $0.id == item.id }
    }

    func toggleItem(_ item: NotificationItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isEnabled.toggle()
            if items[index].isEnabled && !items[index].isWaitingForReply {
                scheduleNextNotification(for: items[index].id)
            } else {
                cancelNotifications(for: items[index].id)
            }
        }
    }

    // MARK: - 사용자 메시지 전송
    func sendUserMessage(_ content: String, for itemId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }

        // 사용자 메시지 추가
        let userMessage = Message(content: content, isFromUser: true)
        items[index].messages.append(userMessage)

        // 답변 대기 상태 해제 -> 알림 스케줄링 시작
        items[index].isWaitingForReply = false

        // 알림 스케줄링 (활성화된 경우에만)
        if items[index].isEnabled {
            scheduleNextNotification(for: itemId)
        }
    }

    // MARK: - 알림 스케줄링 (한 번에 하나씩)
    private func scheduleNextNotification(for itemId: UUID) {
        guard let item = items.first(where: { $0.id == itemId }),
              item.isEnabled,
              !item.isWaitingForReply else { return }

        // 기존 알림 취소
        cancelNotifications(for: itemId)

        // 랜덤 간격 계산 (분 -> 초)
        let randomMinutes = Int.random(in: item.minInterval...item.maxInterval)
        let seconds = TimeInterval(randomMinutes * 60)

        // AI 메시지 생성
        Task {
            let messageContent = await generateAIMessage(for: item)

            // 알림 내용 설정
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = messageContent
            content.sound = .default
            content.userInfo = ["itemId": itemId.uuidString, "messageContent": messageContent]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(itemId.uuidString)-0",
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
            print("\(item.title): \(randomMinutes)분 후 알림 예약")
        }
    }

    // MARK: - AI 메시지 생성
    private func generateAIMessage(for item: NotificationItem) async -> String {
        if #available(iOS 26.0, *) {
            return await AIMessageGenerator.shared.generateMessage(
                name: item.title,
                conversationHistory: item.messages
            )
        } else {
            return AIMessageGeneratorFallback.shared.generateMessage(name: item.title)
        }
    }

    // MARK: - 알림 수신 처리 (AI 메시지를 채팅에 추가)
    func handleNotificationReceived(itemId: UUID, messageContent: String) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }

        // AI 메시지를 채팅에 추가
        let aiMessage = Message(content: messageContent, isFromUser: false)
        items[index].messages.append(aiMessage)

        // 답변 대기 상태로 변경 (다음 알림 보내지 않음)
        items[index].isWaitingForReply = true
    }

    func cancelNotifications(for itemId: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests
                .filter { $0.identifier.hasPrefix(itemId.uuidString) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }

    // 앱 시작 시 대기 중이 아닌 아이템들 알림 재스케줄링
    func rescheduleAllNotifications() {
        for item in items where item.isEnabled && !item.isWaitingForReply {
            scheduleNextNotification(for: item.id)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    // 사용자가 알림 탭했을 때
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let itemIdString = userInfo["itemId"] as? String,
           let itemId = UUID(uuidString: itemIdString),
           let messageContent = userInfo["messageContent"] as? String {
            DispatchQueue.main.async {
                self.handleNotificationReceived(itemId: itemId, messageContent: messageContent)
            }
        }
        completionHandler()
    }

    // 앱이 포그라운드일 때도 알림 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 알림이 표시될 때 메시지를 채팅에 추가
        let userInfo = notification.request.content.userInfo
        if let itemIdString = userInfo["itemId"] as? String,
           let itemId = UUID(uuidString: itemIdString),
           let messageContent = userInfo["messageContent"] as? String {
            DispatchQueue.main.async {
                self.handleNotificationReceived(itemId: itemId, messageContent: messageContent)
            }
        }
        completionHandler([.banner, .sound, .badge])
    }
}
