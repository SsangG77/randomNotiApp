//
//  NotificationManager.swift
//  RandomNotiApp
//

import Foundation
import UserNotifications
import Combine
import UIKit

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var items: [NotificationItem] = [] {
        didSet {
            saveItems()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let itemsKey = "notificationItems"

    // 전체 읽지 않은 메시지 수
    var totalUnreadCount: Int {
        items.reduce(0) { $0 + $1.unreadCount }
    }

    override init() {
        super.init()
        loadItems()
        UNUserNotificationCenter.current().delegate = self
        updateBadge()
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
            let oldItem = items[index]
            items[index] = item

            // 간격이 변경되었고 활성화 상태면 알림 재예약
            if (oldItem.minInterval != item.minInterval || oldItem.maxInterval != item.maxInterval) && item.isEnabled {
                // 기존 알림 취소
                cancelNotifications(for: item.id)
                // pendingMessage 삭제하고 새 간격으로 다시 예약
                items[index].pendingMessage = nil
                items[index].isWaitingForReply = false
                scheduleNextNotification(for: item.id)
            }
        }
    }

    func deleteItem(_ item: NotificationItem) {
        cancelNotifications(for: item.id)
        items.removeAll { $0.id == item.id }
    }

    func toggleItem(_ item: NotificationItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isEnabled.toggle()

            if items[index].isEnabled {
                // 활성화: pendingMessage가 있으면 알림 재예약
                if let pending = items[index].pendingMessage {
                    let now = Date()
                    if pending.scheduledTime > now {
                        // 아직 시간이 안 됐으면 남은 시간으로 알림 재예약
                        let remainingSeconds = pending.scheduledTime.timeIntervalSince(now)
                        rescheduleNotification(for: items[index].id, content: pending.content, seconds: remainingSeconds)
                    } else {
                        // 시간이 지났으면 바로 메시지 추가
                        deliverPendingMessage(for: items[index].id)
                    }
                } else if !items[index].isWaitingForReply {
                    // pendingMessage가 없고 답변 대기 중이 아니면 새 알림 예약
                    scheduleNextNotification(for: items[index].id)
                }
            } else {
                // 비활성화: 알림 취소
                cancelNotifications(for: items[index].id)
            }
        }
    }

    // 기존 pendingMessage로 알림 재예약
    private func rescheduleNotification(for itemId: UUID, content: String, seconds: TimeInterval) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }

        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = items[index].title
        notificationContent.body = content
        notificationContent.sound = .default
        notificationContent.badge = NSNumber(value: totalUnreadCount + 1)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(itemId.uuidString)-0",
            content: notificationContent,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
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
        guard let index = items.firstIndex(where: { $0.id == itemId }),
              items[index].isEnabled,
              !items[index].isWaitingForReply else { return }

        // 기존 알림 취소
        cancelNotifications(for: itemId)

        // 랜덤 간격 계산 (분 -> 초)
        let randomMinutes = Int.random(in: items[index].minInterval...items[index].maxInterval)
        let seconds = TimeInterval(randomMinutes * 60)
        let itemTitle = items[index].title

        // AI 메시지 생성
        Task {
            let messageContent = await generateAIMessage(for: items[index])

            // pendingMessage 저장 및 알림 예약
            let shouldSchedule = await MainActor.run { () -> Bool in
                guard let idx = items.firstIndex(where: { $0.id == itemId }) else { return false }
                items[idx].pendingMessage = PendingMessage(
                    content: messageContent,
                    scheduledTime: Date().addingTimeInterval(seconds)
                )
                items[idx].isWaitingForReply = true
                return true
            }

            guard shouldSchedule else { return }

            // 알림 내용 설정
            let content = UNMutableNotificationContent()
            content.title = itemTitle
            content.body = messageContent
            content.sound = .default
            content.badge = NSNumber(value: self.totalUnreadCount + 1)

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(itemId.uuidString)-0",
                content: content,
                trigger: trigger
            )

            try? await UNUserNotificationCenter.current().add(request)
            print("\(itemTitle): \(randomMinutes)분 후 알림 예약")
        }
    }

    // MARK: - 예약된 메시지를 채팅에 추가
    func deliverPendingMessage(for itemId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }),
              let pending = items[index].pendingMessage else { return }

        // UI 업데이트 보장
        objectWillChange.send()

        let message = Message(
            content: pending.content,
            isFromUser: false,
            timestamp: Date()
        )
        items[index].messages.append(message)
        items[index].pendingMessage = nil
        items[index].unreadCount += 1
        updateBadge()
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
        // 시간이 지난 pendingMessage 처리
        processPendingMessages()

        for item in items where item.isEnabled && !item.isWaitingForReply {
            scheduleNextNotification(for: item.id)
        }
        updateBadge()
    }

    // 시간이 지난 pendingMessage들을 채팅에 추가
    private func processPendingMessages() {
        let now = Date()
        var hasChanges = false
        for index in items.indices {
            if let pending = items[index].pendingMessage,
               pending.scheduledTime <= now {
                let message = Message(
                    content: pending.content,
                    isFromUser: false,
                    timestamp: pending.scheduledTime
                )
                items[index].messages.append(message)
                items[index].pendingMessage = nil
                items[index].unreadCount += 1
                hasChanges = true
            }
        }
        if hasChanges {
            objectWillChange.send()
        }
    }

    // MARK: - 뱃지 관리
    func updateBadge() {
        DispatchQueue.main.async {
            UNUserNotificationCenter.current().setBadgeCount(self.totalUnreadCount)
        }
    }

    // 채팅 읽음 처리
    func markAsRead(itemId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }
        items[index].unreadCount = 0
        updateBadge()
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
        let identifier = response.notification.request.identifier
        if let itemId = extractItemId(from: identifier) {
            DispatchQueue.main.async {
                self.deliverPendingMessage(for: itemId)
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
        let identifier = notification.request.identifier
        if let itemId = extractItemId(from: identifier) {
            DispatchQueue.main.async {
                self.deliverPendingMessage(for: itemId)
            }
        }
        completionHandler([.banner, .sound, .badge])
    }

    private func extractItemId(from identifier: String) -> UUID? {
        // identifier 형식: "UUID-0"
        let parts = identifier.split(separator: "-")
        if parts.count >= 5 {
            let uuidString = parts[0...4].joined(separator: "-")
            return UUID(uuidString: uuidString)
        }
        return nil
    }
}
