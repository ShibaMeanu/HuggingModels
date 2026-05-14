import Foundation
import Combine

// Coordinates between the UI (ContentView) and the Data/Logic layers.
@MainActor
class ViewModel: ObservableObject {
    // Search state
    @Published var searchQuery = ""
    @Published var searchResults: [HFModelSearchResponse] = []
    @Published var isSearching = false
    
    // Model state
    @Published var selectedModelId: String? = nil
    @Published var config: HFConfig? = nil
    @Published var parametersBillionsString = "8.0" // User-editable parameter count
    
    // User configuration for calculation
    @Published var contextLength: Double = 8192
    @Published var batchSize: Double = 1
    @Published var quantization: Quantization = .fp16
    @Published var selectedGGUFVariant: GGUFVariant? = nil
    
    @Published var errorMessage: String? = nil
    
    private var searchCancellable: AnyCancellable?
    
    init() {
        setupSearchDebounce()
    }
    
    /// Sets up a 500ms debounce on search input to avoid hitting the API too frequently.
    private func setupSearchDebounce() {
        searchCancellable = $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                guard let self = self else { return }
                if query.isEmpty {
                    self.searchResults = []
                } else {
                    self.performSearch(query: query)
                }
            }
    }
    
    /// Executes the model search via HuggingFaceService.
    func performSearch(query: String) {
        print("DEBUG: Performing search for: \(query)")
        isSearching = true
        errorMessage = nil
        Task {
            do {
                let results = try await HuggingFaceService.shared.searchModels(query: query)
                guard self.searchQuery == query else { return }
                self.searchResults = results
            } catch {
                guard self.searchQuery == query else { return }
                self.errorMessage = "Failed to search models: \(error.localizedDescription)"
            }
            if self.searchQuery == query {
                self.isSearching = false
            }
        }
    }
    
    /// Selects a model and fetches its architectural configuration.
    func selectModel(_ modelId: String) {
        print("DEBUG: Selecting model: \(modelId)")
        self.selectedModelId = modelId
        self.searchQuery = modelId
        self.searchResults = []
        self.errorMessage = nil
        self.selectedGGUFVariant = nil
        
        // Auto-fill parameter count if it can be guessed from the name.
        if let params = guessParameters(from: modelId) {
            self.parametersBillionsString = String(format: "%.1f", params)
        }
        
        Task {
            do {
                let fetchedConfig = try await HuggingFaceService.shared.fetchConfig(for: modelId)
                
                guard self.selectedModelId == modelId else { return }
                
                self.config = fetchedConfig
                
                // Auto-detect quantization if tags are available.
                if let detected = fetchedConfig.detectedQuantization {
                    self.quantization = detected
                }

                // Default to the first GGUF variant if available.
                if !fetchedConfig.ggufVariants.isEmpty {
                    self.selectedGGUFVariant = fetchedConfig.ggufVariants.first
                }
            } catch {
                guard self.selectedModelId == modelId else { return }
                self.errorMessage = "Failed to fetch config for \(modelId). Ensure it's a valid text model."
                self.config = nil
            }
        }
    }
    
    /// Uses regex to extract parameter counts (e.g., "7B", "8x7b") from the model ID.
    private func guessParameters(from modelId: String) -> Double? {
        let pattern = "([0-9]+[xX])?([0-9]+)[bB]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        
        let nsString = modelId as NSString
        let results = regex.matches(in: modelId, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first {
            var multiplier = 1.0
            if match.range(at: 1).location != NSNotFound {
                let multString = nsString.substring(with: match.range(at: 1)).lowercased().replacingOccurrences(of: "x", with: "")
                if let m = Double(multString) { multiplier = m }
            }
            
            if match.range(at: 2).location != NSNotFound {
                let paramString = nsString.substring(with: match.range(at: 2))
                if let p = Double(paramString) {
                    return p * multiplier
                }
            }
        }
        return nil
    }
    
    /// Returns the live VRAM calculation based on current settings.
    var currentResult: VRAMResult? {
        guard let config = config,
              let params = Double(parametersBillionsString) else {
            return nil
        }
        
        return VRAMCalculator.calculate(
            parametersBillions: params,
            config: config,
            contextLength: Int(contextLength),
            batchSize: Int(batchSize),
            quantization: quantization,
            selectedGGUFVariant: selectedGGUFVariant
        )
    }

    /// Provides user feedback if the model config is missing critical data.
    var configValidationMessage: String? {
        if config == nil { return nil }
        
        if Double(parametersBillionsString) == nil {
            return "Invalid parameter count format."
        }
        
        guard let config = config else { return nil }
        
        var missingFields: [String] = []
        if config.numHiddenLayers == nil { missingFields.append("layers") }
        if config.numAttentionHeads == nil { missingFields.append("attention heads") }
        if config.hiddenSize == nil { missingFields.append("hidden size") }
        
        if !missingFields.isEmpty {
            return "Missing model data: \(missingFields.joined(separator: ", ")). Try entering parameters manually if known."
        }
        
        return nil
    }
}
