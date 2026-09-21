import Foundation

@main
struct Checks {
    static func main() throws {
        let req = GenerationRequest(prompt: "Eine blaue Tasse 🦊", aspect: .square, quality: .standard, transparent: true, steps: 40, seed: 42, references: [])
        let t2i = Workflow.make(req, uploaded: [])
        func input(_ graph: [String: Any], _ node: String) -> [String: Any] { (graph[node] as! [String: Any])["inputs"] as! [String: Any] }
        precondition(input(t2i,"1")["unet_name"] as? String == "qwen_image_2.1_bf16.safetensors")
        precondition((input(t2i,"6")["latent_image"] as! [Any])[0] as? String == "5")
        precondition(input(t2i,"6")["seed"] as? Int == 42)
        precondition(req.effectivePrompt.contains(req.prompt) && req.effectivePrompt.contains("alpha channel"))
        let edit = Workflow.make(req, uploaded: (1...10).map { "image\($0).png" })
        let encoder = input(edit,"4")
        for index in 1...10 { precondition(encoder["images.image_\(index)"] != nil) }
        precondition(encoder["vae"] != nil)
        let latent = input(edit,"6")["latent_image"] as! [Any]
        precondition(latent[0] as? String == "4" && latent[1] as? Int == 2)
        for aspect in Aspect.allCases {
            for quality in Quality.allCases {
                let (w,h) = aspect.size(quality: quality)
                precondition(w % 32 == 0 && h % 32 == 0 && w >= 384 && h >= 384)
            }
        }
        let c = Creation(id: UUID(), date: Date(), prompt: req.prompt, fileName: "one.png", seed: 42, aspect: .portrait, quality: .detail, transparent: true, steps: 40, referenceCount: 2)
        let d = try JSONDecoder().decode(Creation.self, from: JSONEncoder().encode(c))
        precondition(d.id == c.id && d.prompt == c.prompt && d.referenceCount == 2)
        _ = try JSONSerialization.data(withJSONObject: edit)
        let compact = Workflow.make(req, uploaded: [], precision: .compact)
        precondition(input(compact,"1")["unet_name"] as? String == "qwen_image_2.1_int8_convrot.safetensors")
        precondition(input(compact,"2")["clip_name"] as? String == "qwen3vl_8b_int8_convrot.safetensors")
        precondition(Quality.draft.title == "Draft")
        let oldDraft = try JSONDecoder().decode(Quality.self, from: Data("\"Entwurf\"".utf8))
        precondition(oldDraft == .draft)
        let packet = Data([0,0,0,1,0,0,0,1,255,216,255])
        precondition(PreviewFrame.imageData(from: packet) == Data([255,216,255]))
        precondition(PreviewFrame.imageData(from: Data(packet.prefix(8))) == nil)
        precondition(PreviewFrame.imageData(from: Data([0,0,0,4,0,0,0,1,1])) == nil)
        print("PASS: generation contract, 10-reference edit graph, reference sizing, transparency, model grid, seed, JSON persistence")
    }
}
