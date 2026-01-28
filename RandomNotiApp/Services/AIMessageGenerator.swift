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
        // 다양한 주제 랜덤 선택 (질문 최소화, 일상 공유 위주)
        let topics = [
            "Share what you're doing right now (watching YouTube, lying in bed, at cafe, etc)",
            "Talk about food you ate - describe how it was",
            "Share something funny that happened",
            "React to something (헐, 대박, 아 진짜 등)",
            "Share your current mood or feeling",
            "Talk about a drama/show you're watching",
            "Mention you're tired or sleepy",
            "Share random thought without asking anything",
            "Talk about wanting to eat something specific",
            "Share what you did today (met friend, went shopping, etc)"
        ]
        let randomTopic = topics.randomElement() ?? "Share a random thought"

        var prompt = """
        You are '\(name)', a Korean friend texting casually. Write ONE short message in Korean.

        IMPORTANT:
        - Do NOT ask questions like "뭐해?" or "뭐하고있어?"
        - Instead, SHARE something about yourself
        - React, tell stories, share feelings

        Style:
        - Use 반말 (casual speech)
        - Add "ㅋㅋ", "ㅎㅎ", "~" naturally
        - Be slightly cute but natural
        - NO emojis
        - Keep it short (1-2 sentences)

        Examples of good messages:
        - "아ㅋㅋㅋ 방금 진짜 웃긴거 봤어"
        - "나 오늘 친구 만났어~ 재밌었어 ㅎㅎ"
        - "헐 대박 ㅋㅋ"
        - "배고프다~ 치킨 먹고싶어"
        - "나 지금 침대에 누워있어 ㅋㅋ"

        Topic: \(randomTopic)

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
            prompt += "\nRespond naturally to the conversation."
        }

        prompt += "\n\(name)'s message (no questions):"

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
            "방금 라면 끓여먹었어 ㅋㅋ 맛있다",
            "오늘 운동 갔다왔어~ 힘들었어 ㅎㅎ",
            "나 지금 카페야 ㅎㅎ",
            // 감정/반응
            "아ㅋㅋㅋㅋ 방금 진짜 웃긴거 봤어",
            "헐 대박 ㅋㅋㅋ",
            "아 너무 웃겨 ㅋㅋㅋㅋ",
            "오늘 기분 좋다~ ㅎㅎ",
            "아 짜증나 ㅋㅋ",
            "엥 진짜?? ㅋㅋ",
            // 이야기/근황
            "나 오늘 친구 만났어~ 재밌었어 ㅎㅎ",
            "아까 맛집 갔는데 진짜 맛있었어 ㅋㅋ",
            "나 요즘 드라마 보는중~ 재밌어",
            "오늘 쇼핑했어 ㅎㅎ 돈 많이 썼다",
            "나 요즘 노래 이거 듣는중~",
            "아까 산책했는데 좋더라 ㅎㅎ",
            // 음식
            "갑자기 치킨 먹고싶어 ㅋㅋ",
            "아 맛있는거 먹고싶다~",
            "배달 시켜먹을까 고민중~",
            "방금 디저트 먹었어 ㅎㅎ 맛있다",
            "커피 마시고싶다~",
            // 랜덤
            "ㅋㅋㅋ 갑자기 생각나서~",
            "아 졸려~ ㅎㅎ",
            "오늘 하루 진짜 길었어 ㅋㅋ",
            "심심하다~ ㅎㅎ",
            "나 지금 침대에 누워있어 ㅋㅋ",
            "아 귀찮아~ ㅎㅎ",
            "ㅋㅋㅋ 아무말 하고싶었어",
            "나 오늘 늦잠잤어~",
            "집가고싶다 ㅋㅋ"
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
            "방금 라면 끓여먹었어 ㅋㅋ 맛있다",
            "오늘 운동 갔다왔어~ 힘들었어 ㅎㅎ",
            "나 지금 카페야 ㅎㅎ",
            // 감정/반응
            "아ㅋㅋㅋㅋ 방금 진짜 웃긴거 봤어",
            "헐 대박 ㅋㅋㅋ",
            "아 너무 웃겨 ㅋㅋㅋㅋ",
            "오늘 기분 좋다~ ㅎㅎ",
            "아 짜증나 ㅋㅋ",
            "엥 진짜?? ㅋㅋ",
            // 이야기/근황
            "나 오늘 친구 만났어~ 재밌었어 ㅎㅎ",
            "아까 맛집 갔는데 진짜 맛있었어 ㅋㅋ",
            "나 요즘 드라마 보는중~ 재밌어",
            "오늘 쇼핑했어 ㅎㅎ 돈 많이 썼다",
            "나 요즘 노래 이거 듣는중~",
            "아까 산책했는데 좋더라 ㅎㅎ",
            // 음식
            "갑자기 치킨 먹고싶어 ㅋㅋ",
            "아 맛있는거 먹고싶다~",
            "배달 시켜먹을까 고민중~",
            "방금 디저트 먹었어 ㅎㅎ 맛있다",
            "커피 마시고싶다~",
            // 랜덤
            "ㅋㅋㅋ 갑자기 생각나서~",
            "아 졸려~ ㅎㅎ",
            "오늘 하루 진짜 길었어 ㅋㅋ",
            "심심하다~ ㅎㅎ",
            "나 지금 침대에 누워있어 ㅋㅋ",
            "아 귀찮아~ ㅎㅎ",
            "ㅋㅋㅋ 아무말 하고싶었어",
            "나 오늘 늦잠잤어~",
            "집가고싶다 ㅋㅋ"
        ]
        return messages.randomElement() ?? "ㅎㅎ 심심해~"
    }
}
