import Foundation

enum Workflow {
    static func make(_ request: GenerationRequest, uploaded: [String], precision: ModelPrecision = .full) -> [String: Any] {
        let (w,h) = request.dimensions
        var conditioning: [String: Any] = ["clip": ["2",0], "prompt": request.effectivePrompt,
                                          "negative_prompt": "", "resolution": request.quality.referenceSize]
        var graph: [String: Any] = [
            "1": ["class_type": "UNETLoader", "inputs": ["unet_name": "qwen_image_2.1_\(precision.rawValue).safetensors", "weight_dtype": "default"]],
            "2": ["class_type": "CLIPLoader", "inputs": ["clip_name": "qwen3vl_8b_\(precision.rawValue).safetensors", "type": "qwen_image", "device": "default"]],
            "3": ["class_type": "VAELoader", "inputs": ["vae_name": "qwen_image_2.1_vae_bf16.safetensors"]],
            "5": ["class_type": "EmptyLatentImage", "inputs": ["width": w, "height": h, "batch_size": 1]],
            "6": ["class_type": "KSampler", "inputs": ["model": ["1",0], "positive": ["4",0], "negative": ["4",1],
                    "latent_image": uploaded.isEmpty ? ["5",0] : ["4",2], "seed": request.seed, "steps": request.steps,
                    "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple", "denoise": 1.0]],
            "7": ["class_type": "VAEDecode", "inputs": ["samples": ["6",0], "vae": ["3",0]]],
            "8": ["class_type": "SaveImage", "inputs": ["images": ["7",0], "filename_prefix": "Lichtbild"]]
        ]
        if !uploaded.isEmpty { conditioning["vae"] = ["3",0] }
        for (index, name) in uploaded.enumerated() {
            let id = String(20 + index)
            graph[id] = ["class_type": "LoadImage", "inputs": ["image": name]]
            conditioning["images.image_\(index + 1)"] = [id,0]
        }
        graph["4"] = ["class_type": "TextEncodeQwenImage21", "inputs": conditioning]
        if request.fastMode {
            graph["30"] = ["class_type": "EasyCache", "inputs": ["model": ["1",0], "reuse_threshold": 0.2,
                            "start_percent": 0.15, "end_percent": 0.95, "verbose": false]]
            var sampler = graph["6"] as! [String: Any]
            var inputs = sampler["inputs"] as! [String: Any]
            inputs["model"] = ["30",0]
            sampler["inputs"] = inputs
            graph["6"] = sampler
        }
        return graph
    }
}
