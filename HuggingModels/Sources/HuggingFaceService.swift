import Foundation

// Represents a model item in the search results.
struct HFModelSearchResponse: Decodable, Identifiable {
    let id: String
    let likes: Int?
    let downloads: Int?
    let trendingScore: Int?
    let tags: [String]?

    // Determines if the model should show the trending lightning bolt.
    var isTrending: Bool {
        guard let score = trendingScore, score >= 3 else { return false }
        // We only mark "Original" models as trending, matching HF's website logic.
        let isDerivative = tags?.contains(where: { $0.hasPrefix("base_model:") }) ?? false
        return !isDerivative
    }
}

// Detailed metadata for a specific model.
struct HFModelMetadata: Decodable {
    let safetensors: SafetensorsData?
    let tags: [String]?
    let downloads: Int?
    let likes: Int?
    let trendingScore: Int?
    
    struct SafetensorsData: Decodable {
        let total: Int64?
        let parameters: [String: Int64]?
    }
}

// Represents a specific quantization file within a GGUF repository.
struct GGUFVariant: Decodable, Identifiable, Hashable {
    var id: String { filename }
    let filename: String
    let size: Int64
}

// Architectural configuration of a model, used for VRAM calculations.
struct HFConfig: Decodable {
    let numHiddenLayers: Int?
    let numAttentionHeads: Int?
    let numKeyValueHeads: Int?
    let hiddenSize: Int?
    var vocabSize: Int?
    var modelMetadata: HFModelMetadata? = nil
    var ggufVariants: [GGUFVariant] = []
    
    var downloads: Int? = nil
    var likes: Int? = nil
    var trendingScore: Int? = nil

    // Logic to determine if a model is trending based on score and lack of base_model tag.
    var isTrending: Bool {
        guard let score = trendingScore, score >= 3 else { return false }
        let isDerivative = modelMetadata?.tags?.contains(where: { $0.hasPrefix("base_model:") }) ?? false
        return !isDerivative
    }

    // Attempts to auto-detect quantization from model tags.
    var detectedQuantization: Quantization? {
        guard let tags = modelMetadata?.tags else { return nil }

        if tags.contains("4-bit") || tags.contains("gguf") || tags.contains("awq") {
            return .int4
        }
        if tags.contains("8-bit") || tags.contains("fp8") {
            return .int8
        }
        if tags.contains("float16") || tags.contains("bfloat16") {
            return .fp16
        }

        return nil
    }

    // Helper for flexible JSON decoding of varying key names (e.g., n_layer vs num_layers).
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        func findInt(for keys: [String], in container: KeyedDecodingContainer<DynamicCodingKeys>) -> Int? {
            for key in keys {
                if let codingKey = DynamicCodingKeys(stringValue: key) {
                    if let intValue = try? container.decode(Int.self, forKey: codingKey) {
                        return intValue
                    }
                    if let stringValue = try? container.decode(String.self, forKey: codingKey),
                       let intValue = Int(stringValue) {
                        return intValue
                    }
                }
            }
            return nil
        }
        
        let layerKeys = ["num_hidden_layers", "n_layer", "num_layers", "n_layers"]
        let headKeys = ["num_attention_heads", "n_head", "num_heads", "num_query_heads"]
        let kvHeadKeys = ["num_key_value_heads", "n_kv_heads", "num_kv_heads"]
        let hiddenSizeKeys = ["hidden_size", "n_embd", "d_model"]
        
        var layers = findInt(for: layerKeys, in: container)
        var heads = findInt(for: headKeys, in: container)
        var kvHeads = findInt(for: kvHeadKeys, in: container)
        var hidden = findInt(for: hiddenSizeKeys, in: container)
        var vocab = findInt(for: ["vocab_size"], in: container)
        
        // If not found at root, look in common nested configs (like text_config).
        if layers == nil || heads == nil || hidden == nil || vocab == nil {
            let nestedKeys = ["text_config", "gemma4_text", "qwen3_5_text", "llm_config", "vision_config"]
            for nestedKey in nestedKeys {
                if let codingKey = DynamicCodingKeys(stringValue: nestedKey),
                   let nestedContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: codingKey) {
                    if layers == nil { layers = findInt(for: layerKeys, in: nestedContainer) }
                    if heads == nil { heads = findInt(for: headKeys, in: nestedContainer) }
                    if kvHeads == nil { kvHeads = findInt(for: kvHeadKeys, in: nestedContainer) }
                    if hidden == nil { hidden = findInt(for: hiddenSizeKeys, in: nestedContainer) }
                    if vocab == nil { vocab = findInt(for: ["vocab_size"], in: nestedContainer) }
                }
            }
        }
        
        self.numHiddenLayers = layers
        self.numAttentionHeads = heads
        self.numKeyValueHeads = kvHeads
        self.hiddenSize = hidden
        self.vocabSize = vocab
    }
}

// Service for interacting with the Hugging Face REST API.
class HuggingFaceService {
    static let shared = HuggingFaceService()
    
    /// Searches for models and returns a list sorted by popularity/momentum.
    func searchModels(query: String) async throws -> [HFModelSearchResponse] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://huggingface.co/api/models?search=\(encodedQuery)&limit=50") else {
            return []
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let results = try JSONDecoder().decode([HFModelSearchResponse].self, from: data)
        
        // Primary sort: Downloads -> Trending -> Likes.
        return results.sorted { a, b in
            let aDownloads = a.downloads ?? 0
            let bDownloads = b.downloads ?? 0
            if aDownloads != bDownloads { return aDownloads > bDownloads }
            
            let aTrending = a.trendingScore ?? 0
            let bTrending = b.trendingScore ?? 0
            if aTrending != bTrending { return aTrending > bTrending }
            
            return (a.likes ?? 0) > (b.likes ?? 0)
        }
    }
    
    /// Fetches architectural configuration and metadata for a specific model.
    func fetchConfig(for modelId: String) async throws -> HFConfig {
        guard let metadataUrl = URL(string: "https://huggingface.co/api/models/\(modelId)") else {
            throw URLError(.badURL)
        }
        
        let (metadataData, _) = try await URLSession.shared.data(from: metadataUrl)
        
        // Internal struct to help resolve base_model references.
        struct HFMetadataResponse: Decodable {
            let tags: [String]?
            let cardData: CardData?
            struct CardData: Decodable {
                let base_model: BaseModelValue?
            }
            enum BaseModelValue: Decodable {
                case string(String), array([String])
                init(from decoder: Decoder) throws {
                    let container = try decoder.singleValueContainer()
                    if let s = try? container.decode(String.self) { self = .string(s) }
                    else if let a = try? container.decode([String].self) { self = .array(a) }
                    else { throw DecodingError.typeMismatch(BaseModelValue.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected string or array")) }
                }
                var first: String? {
                    switch self {
                    case .string(let s): return s
                    case .array(let a): return a.first
                    }
                }
            }
        }
        
        let metadata = try JSONDecoder().decode(HFMetadataResponse.self, from: metadataData)
        let actualMetadata = try JSONDecoder().decode(HFModelMetadata.self, from: metadataData)
        
        // Try fetching config.json from the primary repo, or fallback to the base model.
        var configData: Data? = nil
        let primaryConfigUrl = "https://huggingface.co/\(modelId)/raw/main/config.json"
        
        if let (data, response) = try? await URLSession.shared.data(from: URL(string: primaryConfigUrl)!),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            configData = data
        } else if let baseModelId = metadata.cardData?.base_model?.first {
            let fallbackUrl = "https://huggingface.co/\(baseModelId)/raw/main/config.json"
            if let (data, response) = try? await URLSession.shared.data(from: URL(string: fallbackUrl)!),
               (response as? HTTPURLResponse)?.statusCode == 200 {
                configData = data
            }
        }
        
        guard let data = configData else { throw URLError(.fileDoesNotExist) }
        
        var config = try JSONDecoder().decode(HFConfig.self, from: data)
        config.modelMetadata = actualMetadata
        config.downloads = actualMetadata.downloads
        config.likes = actualMetadata.likes
        config.trendingScore = actualMetadata.trendingScore
        
        // If it's a GGUF repository, fetch the file tree to find specific variants.
        if actualMetadata.tags?.contains("gguf") == true {
            if let treeUrl = URL(string: "https://huggingface.co/api/models/\(modelId)/tree/main") {
                if let (treeData, _) = try? await URLSession.shared.data(from: treeUrl) {
                    struct TreeItem: Decodable {
                        let path: String, type: String, size: Int64
                    }
                    if let items = try? JSONDecoder().decode([TreeItem].self, from: treeData) {
                        config.ggufVariants = items
                            .filter { $0.type == "file" && $0.path.lowercased().hasSuffix(".gguf") }
                            .map { GGUFVariant(filename: $0.path, size: $0.size) }
                            .sorted(by: { $0.size > $1.size })
                    }
                }
            }
        }
        
        return config
    }
}
