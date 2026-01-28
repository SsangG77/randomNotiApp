//
//  ContentView.swift
//  RandomNotiApp
//
//  Created by 김무경 on 1/27/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var manager = NotificationManager.shared
    @State private var showingAddSheet = false
    @State private var editingItem: NotificationItem?

    var body: some View {
        NavigationView {
            Group {
                if manager.items.isEmpty {
                    emptyStateView
                } else {
                    notificationList
                }
            }
            .navigationTitle("랜덤 알림")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                NotificationEditView(mode: .add)
            }
            .sheet(item: $editingItem) { item in
                NotificationEditView(mode: .edit(item))
            }
        }
        .onAppear {
            manager.requestPermission()
            manager.rescheduleAllNotifications()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("등록된 알림이 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
            Text("+ 버튼을 눌러 새 알림을 추가하세요")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var notificationList: some View {
        List {
            ForEach(manager.items) { item in
                NavigationLink(destination: ChatView(itemId: item.id)) {
                    NotificationRowView(item: item, onEdit: {
                        editingItem = item
                    })
                }
            }
            .onDelete(perform: deleteItems)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            manager.deleteItem(manager.items[index])
        }
    }
}

// MARK: - 알림 행 뷰
struct NotificationRowView: View {
    let item: NotificationItem
    let onEdit: () -> Void
    @ObservedObject private var manager = NotificationManager.shared

    private var lastMessageText: String {
        if let lastMessage = item.messages.last {
            return lastMessage.isFromUser ? "나: \(lastMessage.content)" : lastMessage.content
        }
        return "대화를 시작해보세요"
    }

    private var statusText: String {
        if item.isWaitingForReply {
            return "답변 대기중"
        } else {
            return "\(item.minInterval)분 ~ \(item.maxInterval)분 간격"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 프로필 아이콘
            if let imageData = item.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .opacity(item.isEnabled ? 1.0 : 0.5)
            } else {
                Circle()
                    .fill(item.isEnabled ? Color.blue : Color.gray)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(item.title.prefix(1)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
            }

            // 정보
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(item.isEnabled ? .primary : .secondary)
                }

                Text(lastMessageText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(statusText)
                    .font(.caption)
                    .foregroundColor(item.isWaitingForReply ? .orange : .blue)
            }

            Spacer()

            // 설정 버튼
            Button(action: onEdit) {
                Image(systemName: "gearshape")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)

            // 토글
            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { _ in manager.toggleItem(item) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
