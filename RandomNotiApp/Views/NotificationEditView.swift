//
//  NotificationEditView.swift
//  RandomNotiApp
//

import SwiftUI
import PhotosUI

enum EditMode {
    case add
    case edit(NotificationItem)
}

struct NotificationEditView: View {
    let mode: EditMode
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = NotificationManager.shared

    @State private var title: String = ""
    @State private var minInterval: Int = 5
    @State private var maxInterval: Int = 30
    @State private var isEnabled: Bool = true
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImageData: Data?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingItem: NotificationItem? {
        if case .edit(let item) = mode { return item }
        return nil
    }

    var body: some View {
        NavigationView {
            Form {
                // 상대방 정보
                Section(header: Text("상대방 정보")) {
                    // 프로필 이미지
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            if let imageData = profileImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Image(systemName: "camera.fill")
                                            .foregroundColor(.white)
                                            .font(.title2)
                                    )
                            }
                        }
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    if let uiImage = UIImage(data: data),
                                       let compressed = uiImage.jpegData(compressionQuality: 0.5) {
                                        profileImageData = compressed
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    TextField("이름 (예: 민지)", text: $title)
                }

                Section {
                    Text("AI가 대화 내용을 바탕으로 자동으로 메시지를 생성합니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 시간 간격
                Section(header: Text("메시지 간격")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("최소")
                            Spacer()
                            Picker("최소 간격", selection: $minInterval) {
                                ForEach(intervalOptions, id: \.self) { min in
                                    Text(formatInterval(min)).tag(min)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        HStack {
                            Text("최대")
                            Spacer()
                            Picker("최대 간격", selection: $maxInterval) {
                                ForEach(intervalOptions.filter { $0 >= minInterval }, id: \.self) { min in
                                    Text(formatInterval(min)).tag(min)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Text("답장 후 \(formatInterval(minInterval)) ~ \(formatInterval(maxInterval)) 사이에 새 메시지가 옵니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // 활성화
                Section {
                    Toggle("알림 활성화", isOn: $isEnabled)
                }
            }
            .navigationTitle(isEditing ? "설정 편집" : "새 상대 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveItem()
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                loadExistingItem()
            }
            .onChange(of: minInterval) { _, newValue in
                if maxInterval < newValue {
                    maxInterval = newValue
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var intervalOptions: [Int] {
        [1, 2, 3, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720, 1440]
    }

    private func formatInterval(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)분"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60)시간"
        } else {
            return "\(minutes / 60)시간 \(minutes % 60)분"
        }
    }

    private func loadExistingItem() {
        guard let item = existingItem else { return }
        title = item.title
        profileImageData = item.profileImageData
        minInterval = item.minInterval
        maxInterval = item.maxInterval
        isEnabled = item.isEnabled
    }

    private func saveItem() {
        if let existing = existingItem {
            var updated = existing
            updated.title = title
            updated.profileImageData = profileImageData
            updated.minInterval = minInterval
            updated.maxInterval = maxInterval
            updated.isEnabled = isEnabled
            manager.updateItem(updated)
        } else {
            let newItem = NotificationItem(
                title: title,
                profileImageData: profileImageData,
                minInterval: minInterval,
                maxInterval: maxInterval,
                isEnabled: isEnabled
            )
            manager.addItem(newItem)
        }
    }
}

#Preview {
    NotificationEditView(mode: .add)
}
