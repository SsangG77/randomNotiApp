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
    private var generatingMessageIds = Set<UUID>()  // AI 생성 중복 방지
    @Published var navigateToItemId: UUID?           // 알림 탭 시 채팅방 이동용

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
                        rescheduleNotification(for: items[index].id, seconds: remainingSeconds)
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
    private func rescheduleNotification(for itemId: UUID, seconds: TimeInterval) {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }

        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = items[index].title
        notificationContent.body = "새로운 메시지가 도착했어요"
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

    // MARK: - 알림 스케줄링 (동기, 백그라운드 안전)
    private func scheduleNextNotification(for itemId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }),
              items[index].isEnabled,
              !items[index].isWaitingForReply else { return }

        // 랜덤 간격 계산 (분 -> 초)
        // (같은 identifier로 add하면 iOS가 기존 알림을 자동 교체)
        let randomMinutes = Int.random(in: items[index].minInterval...items[index].maxInterval)
        let seconds = TimeInterval(randomMinutes * 60)

        // pendingMessage 저장 (AI 컨텐츠 없이 스케줄 시간만)
        items[index].pendingMessage = PendingMessage(scheduledTime: Date().addingTimeInterval(seconds))
        items[index].isWaitingForReply = true

        // iOS 알림 즉시 등록 (동기)
        let content = UNMutableNotificationContent()
        content.title = items[index].title
        content.body = "새로운 메시지가 도착했어요"
        content.sound = .default
        content.badge = NSNumber(value: totalUnreadCount + 1)

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(itemId.uuidString)-0",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 예약 실패: \(error)")
            }
        }
        print("\(items[index].title): \(randomMinutes)분 후 알림 예약")
    }

    // MARK: - 예약된 메시지를 채팅에 추가 (로딩 버블 + AI 생성)
    func deliverPendingMessage(for itemId: UUID) {
        guard let index = items.firstIndex(where: { $0.id == itemId }),
              let pending = items[index].pendingMessage else { return }

        objectWillChange.send()

        // 레거시: 이미 content가 있으면 바로 전달
        if let content = pending.content, !content.isEmpty {
            let message = Message(content: content, isFromUser: false, timestamp: Date())
            items[index].messages.append(message)
            items[index].pendingMessage = nil
            items[index].unreadCount += 1
            updateBadge()
            return
        }

        // 새 플로우: 로딩 메시지 생성 후 AI 생성 트리거
        let loadingMessage = Message(content: "", isFromUser: false, timestamp: Date(), isLoading: true)
        let messageId = loadingMessage.id
        items[index].messages.append(loadingMessage)
        items[index].pendingMessage = nil
        items[index].unreadCount += 1
        updateBadge()

        let itemData = items[index]
        generateAndReplaceMessage(itemId: itemId, messageId: messageId, itemData: itemData)
    }

    // MARK: - AI 메시지 생성 후 로딩 메시지 교체 (포그라운드)
    private func generateAndReplaceMessage(itemId: UUID, messageId: UUID, itemData: NotificationItem) {
        // 이미 생성 중이면 중복 실행 방지
        guard !generatingMessageIds.contains(messageId) else { return }
        generatingMessageIds.insert(messageId)

        Task {
            // 25% 확률로 두 개의 메시지 보내기
            let shouldSendDouble = Int.random(in: 1...4) == 1

            if shouldSendDouble {
                // 첫 번째 메시지: 짧은 반응
                let shortReactions = [
                    "ㅋㅋㅋㅋ", "ㅋㅋㅋㅋㅋㅋ", "ㅎㅎㅎ", "아ㅋㅋㅋ",
                    "헐ㅋㅋ", "ㅋㅋ", "ㅎㅎ", "아 ㅋㅋㅋㅋ",
                    "엥ㅋㅋ", "오ㅋㅋㅋ", "아니ㅋㅋㅋ", "잠만ㅋㅋ"
                ]
                let shortMessage = shortReactions.randomElement() ?? "ㅋㅋㅋㅋ"

                await MainActor.run {
                    guard let itemIndex = items.firstIndex(where: { $0.id == itemId }),
                          let msgIndex = items[itemIndex].messages.firstIndex(where: { $0.id == messageId })
                    else { return }

                    objectWillChange.send()
                    items[itemIndex].messages[msgIndex].content = shortMessage
                    items[itemIndex].messages[msgIndex].isLoading = false
                }

                // 잠시 대기 후 두 번째 메시지 추가
                try? await Task.sleep(nanoseconds: UInt64.random(in: 500_000_000...1_500_000_000))

                // 두 번째 로딩 메시지 추가
                let secondLoadingMessage = Message(content: "", isFromUser: false, timestamp: Date(), isLoading: true)
                let secondMessageId = secondLoadingMessage.id

                await MainActor.run {
                    guard let itemIndex = items.firstIndex(where: { $0.id == itemId }) else { return }
                    objectWillChange.send()
                    items[itemIndex].messages.append(secondLoadingMessage)
                }

                // 두 번째 메시지 AI 생성
                let content = await generateAIMessage(for: itemData)

                await MainActor.run {
                    generatingMessageIds.remove(messageId)
                    guard let itemIndex = items.firstIndex(where: { $0.id == itemId }),
                          let msgIndex = items[itemIndex].messages.firstIndex(where: { $0.id == secondMessageId })
                    else { return }

                    objectWillChange.send()
                    items[itemIndex].messages[msgIndex].content = content
                    items[itemIndex].messages[msgIndex].isLoading = false
                }
            } else {
                // 일반적인 경우: 하나의 메시지만
                let content = await generateAIMessage(for: itemData)

                await MainActor.run {
                    generatingMessageIds.remove(messageId)
                    guard let itemIndex = items.firstIndex(where: { $0.id == itemId }),
                          let msgIndex = items[itemIndex].messages.firstIndex(where: { $0.id == messageId })
                    else { return }

                    objectWillChange.send()
                    items[itemIndex].messages[msgIndex].content = content
                    items[itemIndex].messages[msgIndex].isLoading = false
                }
            }
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

    func cancelNotifications(for itemId: UUID) {
        Task {
            await cancelNotificationsAsync(for: itemId)
        }
    }

    private func cancelNotificationsAsync(for itemId: UUID) async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let identifiersToRemove = requests
            .filter { $0.identifier.hasPrefix(itemId.uuidString) }
            .map { $0.identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }

    // 앱 시작 시 대기 중이 아닌 아이템들 알림 재스케줄링
    func rescheduleAllNotifications() {
        // 이전 세션에서 로딩 중이던 메시지 복구
        recoverStaleLoadingMessages()

        // 시간이 지난 pendingMessage 처리
        processPendingMessages()

        for item in items where item.isEnabled && !item.isWaitingForReply {
            scheduleNextNotification(for: item.id)
        }
        updateBadge()
    }

    // 앱 재시작 시 isLoading 상태로 남아있는 메시지 AI 재생성
    private func recoverStaleLoadingMessages() {
        for index in items.indices {
            for msgIndex in items[index].messages.indices {
                if items[index].messages[msgIndex].isLoading {
                    let messageId = items[index].messages[msgIndex].id
                    let itemId = items[index].id
                    let itemData = items[index]
                    generateAndReplaceMessage(itemId: itemId, messageId: messageId, itemData: itemData)
                }
            }
        }
    }

    // 시간이 지난 pendingMessage들을 채팅에 추가
    private func processPendingMessages() {
        let now = Date()
        var hasChanges = false
        for index in items.indices {
            if let pending = items[index].pendingMessage,
               pending.scheduledTime <= now {

                // 레거시: content가 있으면 바로 전달
                if let content = pending.content, !content.isEmpty {
                    let message = Message(
                        content: content,
                        isFromUser: false,
                        timestamp: pending.scheduledTime
                    )
                    items[index].messages.append(message)
                    items[index].pendingMessage = nil
                    items[index].unreadCount += 1
                    hasChanges = true
                    continue
                }

                // 새 플로우: 로딩 메시지 생성 + AI 생성 트리거
                let loadingMessage = Message(
                    content: "",
                    isFromUser: false,
                    timestamp: pending.scheduledTime,
                    isLoading: true
                )
                let messageId = loadingMessage.id
                let itemId = items[index].id
                items[index].messages.append(loadingMessage)
                items[index].pendingMessage = nil
                items[index].unreadCount += 1
                hasChanges = true

                let itemData = items[index]
                generateAndReplaceMessage(itemId: itemId, messageId: messageId, itemData: itemData)
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
                self.navigateToItemId = itemId
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
