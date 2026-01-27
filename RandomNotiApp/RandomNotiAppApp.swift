//
//  RandomNotiAppApp.swift
//  RandomNotiApp
//
//  Created by 김무경 on 1/27/26.
//

import SwiftUI

@main
struct RandomNotiAppApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // 앱이 활성화될 때 알림 다시 스케줄링
                NotificationManager.shared.rescheduleAllNotifications()
            }
        }
    }
}
