//
//  AIMessageGenerator.swift
//  RandomNotiApp
//

import Foundation
import FoundationModels

@available(iOS 26.0, *)
class AIMessageGenerator {
    static let shared = AIMessageGenerator()

    private var session: LanguageModelSession?

    private init() {}

    func generateMessage(name: String, conversationHistory: [Message]) async -> String {
        do {
            // 세션이 없으면 생성
            if session == nil {
                session = LanguageModelSession()
            }

            guard let session = session else {
                return getRandomFallbackMessage(name: name)
            }

            // 프롬프트 생성
            let prompt = buildPrompt(name: name, history: conversationHistory)

            let response = try await session.respond(to: prompt)
            let generatedText = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            // 빈 응답이면 폴백
            if generatedText.isEmpty {
                return getRandomFallbackMessage(name: name)
            }

            return generatedText
        } catch {
            print("AI 메시지 생성 실패: \(error)")
            return getRandomFallbackMessage(name: name)
        }
    }

    private func buildPrompt(name: String, history: [Message]) -> String {
        var prompt = """
        You are a friendly person named '\(name)'. You're chatting casually with a close friend.
        Write a short, casual message in Korean (1-2 sentences).
        Be warm and friendly. You can use casual Korean speech (반말).

        """

        // 최근 대화 히스토리 추가 (최대 10개)
        let recentHistory = history.suffix(10)
        if !recentHistory.isEmpty {
            prompt += "\nRecent conversation:\n"
            for message in recentHistory {
                if message.isFromUser {
                    prompt += "Friend: \(message.content)\n"
                } else {
                    prompt += "\(name): \(message.content)\n"
                }
            }
        }

        prompt += "\n\(name)'s next message (in Korean):"

        return prompt
    }

    private func getRandomFallbackMessage(name: String) -> String {
        let messages = [
            "뭐해? ㅎㅎ",
            "심심해~",
            "오늘 뭐했어?",
            "밥 먹었어?",
            "보고싶다 ㅠㅠ",
            "자기야~",
            "ㅋㅋㅋ 뭐해",
            "나 지금 엄청 심심해",
            "언제 볼 수 있어?",
            "오늘 날씨 좋다!",
            "뭐 먹을까 고민중...",
            "헤헤 생각나서 연락해봤어",
            "지금 뭐하는 중이야?",
            "나랑 놀아줘~"
        ]
        return messages.randomElement() ?? "뭐해?"
    }
}

// iOS 26 미만용 폴백
class AIMessageGeneratorFallback {
    static let shared = AIMessageGeneratorFallback()

    private init() {}

    func generateMessage(name: String) -> String {
        let messages = [
            "뭐해? ㅎㅎ",
            "심심해~",
            "오늘 뭐했어?",
            "밥 먹었어?",
            "보고싶다 ㅠㅠ",
            "자기야~",
            "ㅋㅋㅋ 뭐해",
            "나 지금 엄청 심심해",
            "언제 볼 수 있어?",
            "오늘 날씨 좋다!",
            "뭐 먹을까 고민중...",
            "헤헤 생각나서 연락해봤어",
            "지금 뭐하는 중이야?",
            "나랑 놀아줘~",
            "오늘 진짜 피곤해 ㅠ",
            "뭐 재밌는 거 없나~",
            "나 오늘 맛있는 거 먹었어!",
            "ㅎㅎ 갑자기 네 생각났어",
            "자고 있었어?",
            "나 지금 카페야~"
        ]
        return messages.randomElement() ?? "뭐해?"
    }
}
