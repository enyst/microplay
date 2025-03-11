import SwiftUI

@main
struct MacClientApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Custom new item commands
            }
            
            CommandGroup(replacing: .help) {
                Button("OpenHands Help") {
                    NSWorkspace.shared.open(URL(string: "https://github.com/enyst/microplay")!)
                }
            }
        }
    }
}