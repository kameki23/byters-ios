import SwiftUI

@main
struct BytersApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(appState)
        }
    }
}
