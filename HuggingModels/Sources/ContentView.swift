import SwiftUI

// Main view for the menu bar application.
struct ContentView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    searchSection
                    
                    if let config = viewModel.config {
                        modelInfoSection(config)
                        configurationSection
                        resultsSection
                    } else if let error = viewModel.errorMessage {
                        // Display search or network errors.
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        // Empty state instructions.
                        Text("Search and select a Hugging Face model to begin.")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            
            Divider()
            
            footerView
        }
        .frame(width: 350, height: 500) // Fixed size for the menu bar window.
    }
    
    // Displays the app title and a reset button.
    private var headerView: some View {
        HStack {
            Text("Hugging Models")
                .font(.headline)
            Spacer()
            if viewModel.selectedModelId != nil {
                Button("Reset") {
                    viewModel.config = nil
                    viewModel.selectedModelId = nil
                    viewModel.searchQuery = ""
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
    }

    // Displays version info and a quit button.
    private var footerView: some View {
        HStack {
            Text("v1.0")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .padding(.top, 8)
    }

    // Displays high-level model info like likes, downloads, and a link to the Hub.
    private func modelInfoSection(_ config: HFConfig) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Model Card")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if config.isTrending {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                        Text("Trending")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                }
            }

            HStack(spacing: 16) {
                if let downloads = config.downloads {
                    Label(formatNumber(downloads), systemImage: "icloud.and.arrow.down")
                }
                if let likes = config.likes {
                    Label(formatNumber(likes), systemImage: "heart.fill")
                }
                
                Spacer()
                
                // Link to open the model's Hugging Face page in the browser.
                if let modelId = viewModel.selectedModelId {
                    Button(action: {
                        if let url = URL(string: "https://huggingface.co/\(modelId)") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text("View on Hugging Face")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // Search input and live results dropdown.
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search Hugging Face...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                if viewModel.isSearching {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            
            // Live search results list.
            if !viewModel.searchResults.isEmpty && viewModel.selectedModelId != viewModel.searchQuery {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults) { result in
                        Button(action: {
                            viewModel.selectModel(result.id)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.id)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 8) {
                                        if let downloads = result.downloads {
                                            Label(formatNumber(downloads), systemImage: "icloud.and.arrow.down")
                                        }
                                        if let likes = result.likes {
                                            Label(formatNumber(likes), systemImage: "heart.fill")
                                        }
                                        if result.isTrending {
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(.orange)
                                        }
                                    }
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if result.id != viewModel.searchResults.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }

    // Helper to format numbers with K/M suffixes.
    private func formatNumber(_ n: Int) -> String {
        let num = Double(n)
        if num >= 1_000_000 {
            return String(format: "%.1fM", num / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", num / 1_000)
        } else {
            return "\(n)"
        }
    }
    
    // Sliders and pickers for adjusting the model configuration.
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configuration")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack {
                Text("Parameters (Billions):")
                Spacer()
                TextField("8.0", text: $viewModel.parametersBillionsString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Context Length:")
                    Spacer()
                    Text("\(Int(viewModel.contextLength)) tokens")
                        .monospacedDigit()
                }
                Slider(value: $viewModel.contextLength, in: 512...256000, step: 512)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Batch Size:")
                    Spacer()
                    Text("\(Int(viewModel.batchSize))")
                        .monospacedDigit()
                }
                Slider(value: $viewModel.batchSize, in: 1...32, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Quantization:")
                    if viewModel.config?.detectedQuantization != nil {
                        Text("(Detected)")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                }
                
                // If the model is GGUF, show the specific file picker.
                if let variants = viewModel.config?.ggufVariants, !variants.isEmpty {
                    Picker("GGUF File", selection: $viewModel.selectedGGUFVariant) {
                        ForEach(variants) { variant in
                            Text("\(variant.filename) (\(String(format: "%.1f", Double(variant.size) / 1_073_741_824.0)) GB)")
                                .tag(variant as GGUFVariant?)
                        }
                    }
                    .labelsHidden()
                } else {
                    // Standard quantization picker.
                    Picker("", selection: $viewModel.quantization) {
                        ForEach(Quantization.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    .labelsHidden()
                }
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
    
    // Displays the final VRAM estimation results.
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Requirements (Estimated)")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if let result = viewModel.currentResult {
                HStack {
                    Text("Model Weights:")
                    Spacer()
                    Text(String(format: "%.2f GB", result.modelVRAM))
                        .monospacedDigit()
                }
                HStack {
                    Text("Effective Precision:")
                    Spacer()
                    Text(String(format: "%.2f bits/param", result.effectiveBytesPerParam * 8.0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text("KV Cache:")
                    Spacer()
                    Text(String(format: "%.2f GB", result.kvCacheVRAM))
                        .monospacedDigit()
                }
                Divider()
                HStack {
                    Text("Total VRAM:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(String(format: "%.2f GB", result.totalVRAM))
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(.blue)
                }
                Text("Includes ~10% buffer for framework overhead.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            } else {
                // Validation feedback if critical data is missing.
                Text(viewModel.configValidationMessage ?? "Invalid configuration or missing model data.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .cornerRadius(8)
    }
}
