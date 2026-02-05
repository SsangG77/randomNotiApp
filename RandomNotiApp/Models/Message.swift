//
//  Message.swift
//  RandomNotiApp
//

import Foundation

struct Message: Identifiable, Codable {
    var id: UUID = UUID()
    var content: String
    var isFromUser: Bool      // true: 사용자가 보낸 메시지, false: AI가 보낸 메시지
    var timestamp: Date = Date()
    var isLoading: Bool = false  // AI 메시지 생성 중 로딩 상태

    enum CodingKeys: String, CodingKey {
        case id, content, isFromUser, timestamp, isLoading
    }

    init(id: UUID = UUID(), content: String, isFromUser: Bool, timestamp: Date = Date(), isLoading: Bool = false) {
        self.id = id
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.isLoading = isLoading
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        isFromUser = try container.decode(Bool.self, forKey: .isFromUser)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isLoading = try container.decodeIfPresent(Bool.self, forKey: .isLoading) ?? false
    }
}
