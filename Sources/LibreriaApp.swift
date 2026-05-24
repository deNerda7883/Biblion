import SwiftUI

@main
struct LibreriaApp: App {
    @StateObject private var store = LibroStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            ImpostazioniView()
        }
    }
}
