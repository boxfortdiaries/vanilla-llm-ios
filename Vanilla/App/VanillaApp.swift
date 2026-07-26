import SwiftUI

@main
struct VanillaApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .task { SampleFiles.seedIfNeeded() }
        }
    }
}
