import SwiftUI

@main
struct SpeedReaderApp: App {
    @StateObject private var bridge = ReaderBridge()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ReaderWebView(bridge: bridge)
                .ignoresSafeArea()            // the page handles safe areas itself
                .background(Color(uiColor: .systemBackground))
                .onOpenURL { url in bridge.open(url) }   // books shared from Files, Books, Mail…
                .onChange(of: scenePhase) { phase in
                    if phase == .active { bridge.syncFolder(manual: false) }
                }
        }
    }
}
