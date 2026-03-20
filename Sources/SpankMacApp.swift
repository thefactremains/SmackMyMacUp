import SwiftUI

@main
struct WhacMyMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only — no window scene needed.
        Settings { EmptyView() }
    }
}
