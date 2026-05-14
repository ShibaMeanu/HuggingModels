import SwiftUI

@main
struct HuggingModelsApp: App {
    // Initializing the ViewModel as a single source of truth for the application.
    @StateObject private var viewModel = ViewModel()

    var body: some Scene {
        // Defines the app as a macOS Menu Bar item.
        MenuBarExtra {
            ContentView()
                .environmentObject(viewModel)
        } label: {
            // Using the Hugging Face emoji as the menu bar icon.
            Text("🤗")
        }
        .menuBarExtraStyle(.window) // Opens as a floating window when clicked.
    }
}
