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
        // 다양한 주제 랜덤 선택
        let topics = [
            "Share what you're doing right now",
            "Talk about food you ate or want to eat",
            "Mention something random about your day",
            "Ask a casual question about their day",
            "Share a random thought",
            "Talk about being tired or bored",
            "Mention the weather or plans"
        ]
        let randomTopic = topics.randomElement() ?? "Share a random thought"

        var prompt = """
        You are '\(name)', a cute Korean friend texting. Write ONE short message in Korean.

        Style rules:
        - Use casual speech (반말)
        - Be slightly cute (애교) but natural
        - Mix these expressions naturally: "ㅋㅋ", "ㅎㅎ", "~" at end of sentences
        - Examples: "오늘 뭐했어~ ㅎㅎ", "나 지금 집이야 ㅋㅋ", "배고프다~"
        - NO emojis
        - Sound natural, like a real text message
        - Don't always ask "뭐해" - be varied

        Topic for this message: \(randomTopic)

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
            prompt += "\nContinue the conversation naturally."
        }

        prompt += "\n\(name)'s message:"

        return prompt
    }

    private func getRandomFallbackMessage(name: String) -> String {
        let messages = [
            // 일상 공유
            "아 오늘 진짜 피곤해~ ㅋㅋ",
            "방금 밥 먹었는데 벌써 배고프다 ㅎㅎ",
            "나 오늘 커피 3잔째야~",
            "아까 버스에서 잠들뻔했어 ㅋㅋㅋ",
            "오늘 날씨 진짜 좋다~",
            "나 지금 유튜브 보는중 ㅎㅎ",
            "아 뭐볼지 모르겠어~",
            "방금 라면 끓여먹었어 ㅋㅋ 맛있다",
            "오늘 운동 갔다왔어~ 힘들었어 ㅎㅎ",
            "아 내일 뭐하지~",
            // 질문
            "요즘 뭐하고 지내~ ㅎㅎ",
            "점심 뭐 먹었어?",
            "주말에 뭐해~ 나랑 놀아줘 ㅋㅋ",
            "요즘 재밌는거 있어? 추천해줘~",
            "너 그거 봤어? 요즘 유행하는거 ㅋㅋ",
            // 잡담
            "아 진짜 심심하다~ ㅎㅎ",
            "갑자기 치킨 먹고싶어 ㅋㅋ",
            "ㅎㅎ 갑자기 생각나서 연락했어~",
            "심심해서 연락함 ㅋㅋ",
            "나 지금 집이야~ 너 뭐해?",
            "아 졸려~ ㅎㅎ",
            "오늘 하루 진짜 길었어 ㅋㅋ",
            "배달 시켜먹을까 고민중~ 뭐가 좋을까",
            "나 지금 카페야 ㅎㅎ",
            "아 맛있는거 먹고싶다~",
            "오늘 뭐했어? 나는 그냥 집에 있었어 ㅋㅋ"
        ]
        return messages.randomElement() ?? "ㅎㅎ 심심해~"
    }
}

// iOS 26 미만용 폴백
class AIMessageGeneratorFallback {
    static let shared = AIMessageGeneratorFallback()

    private init() {}

    func generateMessage(name: String) -> String {
        let messages = [
            // 일상 공유
            "아 오늘 진짜 피곤해~ ㅋㅋ",
            "방금 밥 먹었는데 벌써 배고프다 ㅎㅎ",
            "나 오늘 커피 3잔째야~",
            "아까 버스에서 잠들뻔했어 ㅋㅋㅋ",
            "오늘 날씨 진짜 좋다~",
            "나 지금 유튜브 보는중 ㅎㅎ",
            "아 뭐볼지 모르겠어~",
            "방금 라면 끓여먹었어 ㅋㅋ 맛있다",
            "오늘 운동 갔다왔어~ 힘들었어 ㅎㅎ",
            "아 내일 뭐하지~",
            // 질문
            "요즘 뭐하고 지내~ ㅎㅎ",
            "점심 뭐 먹었어?",
            "주말에 뭐해~ 나랑 놀아줘 ㅋㅋ",
            "요즘 재밌는거 있어? 추천해줘~",
            "너 그거 봤어? 요즘 유행하는거 ㅋㅋ",
            // 잡담
            "아 진짜 심심하다~ ㅎㅎ",
            "갑자기 치킨 먹고싶어 ㅋㅋ",
            "ㅎㅎ 갑자기 생각나서 연락했어~",
            "심심해서 연락함 ㅋㅋ",
            "나 지금 집이야~ 너 뭐해?",
            "아 졸려~ ㅎㅎ",
            "오늘 하루 진짜 길었어 ㅋㅋ",
            "배달 시켜먹을까 고민중~ 뭐가 좋을까",
            "나 지금 카페야 ㅎㅎ",
            "아 맛있는거 먹고싶다~",
            "오늘 뭐했어? 나는 그냥 집에 있었어 ㅋㅋ"
        ]
        return messages.randomElement() ?? "ㅎㅎ 심심해~"
    }
}
