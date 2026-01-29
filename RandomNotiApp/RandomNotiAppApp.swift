//
//  RandomNotiAppApp.swift
//  RandomNotiApp
//
//  Created by 김무경 on 1/27/26.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 앱 시작 시 NotificationManager 초기화 (delegate 설정)
        _ = NotificationManager.shared
        return true
    }
}

@main
struct RandomNotiAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // 앱이 활성화될 때 예약된 메시지 처리 및 알림 스케줄링
                NotificationManager.shared.rescheduleAllNotifications()
            }
        }
    }
}
