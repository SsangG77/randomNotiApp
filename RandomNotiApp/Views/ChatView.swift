//
//  ChatView.swift
//  RandomNotiApp
//

import SwiftUI
import Combine

struct ChatView: View {
    let itemId: UUID
    @ObservedObject private var manager = NotificationManager.shared
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool

    private var item: NotificationItem? {
        manager.items.first { $0.id == itemId }
    }

    private var messages: [Message] {
        item?.messages ?? []
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // 채팅 메시지 목록
                GeometryReader { outerGeometry in
                    let screenHeight = outerGeometry.size.height

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubble(
                                    message: message,
                                    screenHeight: screenHeight,
                                    senderName: item?.title ?? "",
                                    profileImageData: item?.profileImageData
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }

                Divider()

                // 입력 영역
                HStack(spacing: 12) {
                    TextField("메시지 입력...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .lineLimit(1...5)
                        .focused($isInputFocused)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .onChange(of: isInputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onAppear {
                manager.markAsRead(itemId: itemId)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
        .navigationTitle(item?.title ?? "채팅")
        .navigationBarTitleDisplayMode(.inline)
        .onTapGesture {
            isInputFocused = false
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty, let item = item else { return }

        manager.sendUserMessage(inputText, for: item.id)
        inputText = ""
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - 메시지 말풍선
struct MessageBubble: View {
    let message: Message
    let screenHeight: CGFloat
    let senderName: String
    let profileImageData: Data?

    @State private var bubblePosition: CGFloat = 0.5

    // 그라데이션 색상: 위 = 보라, 아래 = 파랑
    private static let topColor = Color(red: 0.6, green: 0.2, blue: 0.9)     // 보라
    private static let bottomColor = Color(red: 0.2, green: 0.4, blue: 0.95) // 파랑

    private var bubbleGradient: LinearGradient {
        let clampedPosition = max(0, min(1, bubblePosition))

        // 화면 위치에 따라 보라 ↔ 파랑 사이 색상 계산
        let color = interpolateColor(from: Self.topColor, to: Self.bottomColor, progress: clampedPosition)

        return LinearGradient(
            colors: [color, color.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func interpolateColor(from: Color, to: Color, progress: CGFloat) -> Color {
        let fromUI = UIColor(from)
        let toUI = UIColor(to)

        var fromR: CGFloat = 0, fromG: CGFloat = 0, fromB: CGFloat = 0, fromA: CGFloat = 0
        var toR: CGFloat = 0, toG: CGFloat = 0, toB: CGFloat = 0, toA: CGFloat = 0

        fromUI.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)
        toUI.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

        let r = fromR + (toR - fromR) * progress
        let g = fromG + (toG - fromG) * progress
        let b = fromB + (toB - fromB) * progress

        return Color(red: r, green: g, blue: b)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // 상대방 프로필 이미지
                if let imageData = profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(senderName.prefix(1)))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                }
            }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    GeometryReader { geometry in
                        Group {
                            if message.isFromUser {
                                bubbleGradient
                            } else {
                                Color(.systemGray5)
                            }
                        }
                        .onAppear {
                            updatePosition(geometry: geometry)
                        }
                        .onChange(of: geometry.frame(in: .global).midY) { _, _ in
                            updatePosition(geometry: geometry)
                        }
                    }
                )
                .foregroundColor(message.isFromUser ? .white : .primary)
                .cornerRadius(18)

            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func updatePosition(geometry: GeometryProxy) {
        let frame = geometry.frame(in: .global)
        bubblePosition = frame.midY / screenHeight
    }
}

#Preview {
    NavigationStack {
        ChatView(itemId: UUID())
    }
}
