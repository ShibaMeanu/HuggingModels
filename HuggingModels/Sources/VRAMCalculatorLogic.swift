import Foundation

// Defines supported quantization levels and their memory footprints.
enum Quantization: String, CaseIterable, Identifiable {
    case fp16 = "FP16 / BF16 (16-bit)"
    case int8 = "INT8 / FP8 (8-bit)"
    case int4 = "INT4 / GGUF / AWQ (4-bit)"
    
    var id: String { self.rawValue }
    
    // Returns bytes used per individual model parameter.
    var bytesPerParam: Double {
        switch self {
        case .fp16: return 2.0
        case .int8: return 1.0
        case .int4: return 0.5
        }
    }
}

// Holds the breakdown of calculated VRAM requirements.
struct VRAMResult {
    let modelVRAM: Double // VRAM for model weights in GB
    let kvCacheVRAM: Double // VRAM for context/cache in GB
    let totalVRAM: Double // Total estimated VRAM (including overhead) in GB
    let effectiveBytesPerParam: Double // Actual bytes/param after quantization
}

// Logic engine for calculating LLM VRAM requirements.
class VRAMCalculator {
    /// Estimates VRAM based on model architecture, context settings, and quantization.
    static func calculate(
        parametersBillions: Double,
        config: HFConfig,
        contextLength: Int,
        batchSize: Int,
        quantization: Quantization,
        selectedGGUFVariant: GGUFVariant? = nil
    ) -> VRAMResult? {
        
        // 1. Calculate Model Weights VRAM
        let totalParameters = parametersBillions * 1_000_000_000
        var modelVRAMGB: Double
        var effectiveBytesPerParam = quantization.bytesPerParam
        
        if let gguf = selectedGGUFVariant {
            // Priority 1: Use specific GGUF file size if available.
            modelVRAMGB = Double(gguf.size) / 1_073_741_824.0
            effectiveBytesPerParam = Double(gguf.size) / totalParameters
        } else if let totalWeightSize = config.modelMetadata?.safetensors?.total, quantization == (config.detectedQuantization ?? .fp16) {
            // Priority 2: Use actual Safetensors total size if reported by API and matches selected quantization.
            modelVRAMGB = Double(totalWeightSize) / 1_073_741_824.0
            effectiveBytesPerParam = Double(totalWeightSize) / totalParameters
        } else {
            // Priority 3: Fallback to mathematical estimation.
            let modelVRAMBytes = totalParameters * quantization.bytesPerParam
            modelVRAMGB = modelVRAMBytes / 1_073_741_824.0
        }
        
        // 2. Calculate KV Cache VRAM
        // Requires hidden layers, attention heads, and hidden size from model config.
        guard let hiddenLayers = config.numHiddenLayers,
              let attentionHeads = config.numAttentionHeads,
              let hiddenSize = config.hiddenSize else {
            return nil
        }
        
        let keyValueHeads = config.numKeyValueHeads ?? attentionHeads
        let headDim = Double(hiddenSize) / Double(attentionHeads)
        
        // KV cache usually stays in high precision (FP16/BF16) in most inference engines.
        let kvCacheBytesPerParam = 2.0 
        
        // Formula: 2 (K&V) * layers * heads * head_dim * context * batch * precision_bytes
        let kvCacheBytes = 2.0 * Double(hiddenLayers) * Double(keyValueHeads) * headDim * Double(contextLength) * Double(batchSize) * kvCacheBytesPerParam
        
        let kvCacheVRAMGB = kvCacheBytes / 1_073_741_824.0
        
        // 3. Final Estimate with Framework Overhead
        // Adds a 10% safety buffer for CUDA context and framework-specific allocations.
        let totalVRAM = (modelVRAMGB + kvCacheVRAMGB) * 1.10
        
        return VRAMResult(
            modelVRAM: modelVRAMGB,
            kvCacheVRAM: kvCacheVRAMGB,
            totalVRAM: totalVRAM,
            effectiveBytesPerParam: effectiveBytesPerParam
        )
    }
}
