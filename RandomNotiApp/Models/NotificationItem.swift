//
//  NotificationItem.swift
//  RandomNotiApp
//

import Foundation

struct NotificationItem: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String                   // 상대방 이름
    var minInterval: Int                // 최소 간격 (분)
    var maxInterval: Int                // 최대 간격 (분)
    var isEnabled: Bool                 // 활성화 여부
    var messages: [Message] = []        // 채팅 메시지 히스토리
    var isWaitingForReply: Bool = true  // 답변 대기 상태 (true면 알림 안 보냄)
    var unreadCount: Int = 0            // 읽지 않은 메시지 수
    var createdAt: Date = Date()

    // 마지막 메시지
    var lastMessage: Message? {
        messages.last
    }

    static let sample = NotificationItem(
        title: "민지",
        minInterval: 5,
        maxInterval: 30,
        isEnabled: true
    )
}
