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
}
