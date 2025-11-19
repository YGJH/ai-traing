import Foundation

final class MLP: Codable {
    typealias Vector = [Float]
    typealias Matrix = [[Float]]

    // One weight matrix and bias vector per shared trunk layer (hidden layers only)
    private(set) var W: [Matrix]
    private(set) var b: [Vector]

    // Two heads that take the final trunk output as input
    // action: [lastHiddenSize x outputDim]
    // valueHead: [lastHiddenSize x 1]
    private(set) var valueHead: Matrix
    private(set) var action: Matrix

    // Model metadata (useful for validation on load)
    private let inputSize: Int
    private let hiddenSize: Int
    private let hiddenLayers: Int
    private let outputDim: Int

    // File name derived from architecture to keep things simple
    private var modelFileURL: URL {
        let fileName = "mlp_\(inputSize)_\(hiddenSize)_\(hiddenLayers)_\(outputDim).json"
        return MLP.defaultModelsDirectory().appendingPathComponent(fileName)
    }

    enum CodingKeys: String, CodingKey {
        case W, b, valueHead, action, inputSize, hiddenSize, hiddenLayers, outputDim
    }

    func parameters() -> [Parameter1D] {
        var params: [Parameter1D] = []

        // === trunk: W, b ===
        for l in 0..<W.count {
            // W[l] 每一個 row 一個 Parameter1D
            for r in 0..<W[l].count {
                let layerIndex = l
                let rowIndex = r

                let p = Parameter1D(
                    getter: { [unowned self] in
                        self.W[layerIndex][rowIndex]
                    },
                    setter: { [unowned self] newRow in
                        self.W[layerIndex][rowIndex] = newRow
                    }
                )
                params.append(p)
            }

            // 對應的 bias b[l]
            let layerIndex = l
            let biasParam = Parameter1D(
                getter: { [unowned self] in
                    self.b[layerIndex]
                },
                setter: { [unowned self] newBias in
                    self.b[layerIndex] = newBias
                }
            )
            params.append(biasParam)
        }

        // === action head ===
        for r in 0..<action.count {
            let rowIndex = r
            let p = Parameter1D(
                getter: { [unowned self] in
                    self.action[rowIndex]
                },
                setter: { [unowned self] newRow in
                    self.action[rowIndex] = newRow
                }
            )
            params.append(p)
        }

        // === value head ===
        for r in 0..<valueHead.count {
            let rowIndex = r
            let p = Parameter1D(
                getter: { [unowned self] in
                    self.valueHead[rowIndex]
                },
                setter: { [unowned self] newRow in
                    self.valueHead[rowIndex] = newRow
                }
            )
            params.append(p)
        }

        return params
    }

    
    // MARK: - Init

    // If a model file matching this architecture exists, load it; otherwise initialize randomly.
    init(inputSize: Int, hiddenSize: Int, hiddenLayers: Int, outputDim: Int) {
        self.inputSize = inputSize
        self.hiddenSize = hiddenSize
        self.hiddenLayers = hiddenLayers
        self.outputDim = outputDim
        self.W = []
        self.b = []
        self.valueHead = []
        self.action = []

        if FileManager.default.fileExists(atPath: modelFileURL.path) {
            do {
                try self.load()
            } catch {
                // If loading fails, fall back to random initialization
                self.randomInitialize()
                // Best effort save so subsequent runs can load
                try? self.save()
            }
        } else {
            self.randomInitialize()
            // Save the newly initialized model
            try? self.save()
        }
    }

    // MARK: - Public API

    // Forward pass returning action probabilities (softmax) from the action head.
    // The value head is computed but not returned here; use forwardWithValue if you need both.
    func forward(x: Vector) -> (action: Vector, value: Float) {
        return forwardWithValue(x: x)
    }

    // Forward pass that returns both action probabilities and scalar value.
    func forwardWithValue(x: Vector) -> (action: Vector, value: Float) {
        precondition(x.count == inputSize, "Input vector size mismatch. Expected \(inputSize), got \(x.count).")
        let h = trunkForward(x: x)

        // Action head: logits = h * action; probs = softmax(logits)
        let logits = matmul(h, action)
        let probs = softmax(logits)

        // Value head: scalar = (h * valueHead)[0]
        let valueVec = matmul(h, valueHead)
        let value = valueVec.first ?? 0

        return (probs, value)
    }
    
    
    
    
    // Persist current parameters to disk
    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let data = try encoder.encode(self)
        try FileManager.default.createDirectory(at: MLP.defaultModelsDirectory(), withIntermediateDirectories: true)
        try data.write(to: modelFileURL, options: .atomic)
    }

    
    
    // MARK: - Private helpers

    private func load() throws {
        let data = try Data(contentsOf: modelFileURL)
        let decoder = JSONDecoder()
        let loaded = try decoder.decode(MLP.self, from: data)

        // Validate architecture matches
        guard loaded.inputSize == self.inputSize,
              loaded.hiddenSize == self.hiddenSize,
              loaded.hiddenLayers == self.hiddenLayers,
              loaded.outputDim == self.outputDim else {
            throw NSError(domain: "MLP", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model architecture mismatch while loading."])
        }

        self.W = loaded.W
        self.b = loaded.b
        self.valueHead = loaded.valueHead
        self.action = loaded.action
    }

    private func randomInitialize() {
        W.removeAll()
        b.removeAll()
        valueHead.removeAll()
        action.removeAll()

        // Shared trunk: input -> hidden x N (no output layer here)
        var layerSizes: [Int] = [inputSize]
        layerSizes.append(contentsOf: Array(repeating: hiddenSize, count: hiddenLayers))

        // Build trunk layers (if hiddenLayers == 0, trunk is identity)
        if hiddenLayers > 0 {
            for l in 0..<(layerSizes.count - 1) {
                let fanIn = layerSizes[l]
                let fanOut = layerSizes[l + 1]

                // He initialization for ReLU: N(0, sqrt(2/fanIn)) approximated by uniform scaled
                let std: Float = sqrt(2.0 / Float(max(1, fanIn)))

                var w: Matrix = Array(repeating: Array(repeating: 0, count: fanOut), count: fanIn)
                for i in 0..<fanIn {
                    for j in 0..<fanOut {
                        w[i][j] = Float.random(in: -1...1) * std
                    }
                }
                let bias: Vector = Array(repeating: 0, count: fanOut)

                W.append(w)
                b.append(bias)
            }
        }

        // Determine the size of the trunk output
        let lastHiddenSize: Int = (hiddenLayers > 0) ? hiddenSize : inputSize

        // Initialize action head: [lastHiddenSize x outputDim]
        do {
            let fanIn = lastHiddenSize
            let fanOut = outputDim
            let std: Float = sqrt(2.0 / Float(max(1, fanIn)))
            var w: Matrix = Array(repeating: Array(repeating: 0, count: fanOut), count: fanIn)
            for i in 0..<fanIn {
                for j in 0..<fanOut {
                    w[i][j] = Float.random(in: -1...1) * std
                }
            }
            self.action = w
        }

        // Initialize value head: [lastHiddenSize x 1]
        do {
            let fanIn = lastHiddenSize
            let fanOut = 1
            let std: Float = sqrt(2.0 / Float(max(1, fanIn)))
            var w: Matrix = Array(repeating: Array(repeating: 0, count: fanOut), count: fanIn)
            for i in 0..<fanIn {
                for j in 0..<fanOut {
                    w[i][j] = Float.random(in: -1...1) * std
                }
            }
            self.valueHead = w
        }
    }

    private func trunkForward(x: Vector) -> Vector {
        var a = x
        if W.isEmpty {
            // No hidden layers: trunk output is the input
            return a
        }
        let lastLayerIndex = W.count - 1
        for layer in 0...lastLayerIndex {
            a = add(matmul(a, W[layer]), b[layer])
            if layer != lastLayerIndex {
                a = relu(a)
            }
        }
        return a
    }

    private static func defaultModelsDirectory() -> URL {
        // Documents directory for iOS/iPadOS/macOS app sandbox
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[0].appendingPathComponent("Models", isDirectory: true)
    }

    // MARK: - Math utilities

    // y = x * W  (x: [n], W: [n x m]) -> y: [m]
    private func matmul(_ x: Vector, _ W: Matrix) -> Vector {
        precondition(W.count == x.count, "matmul dimension mismatch: x.count \(x.count) vs W.rows \(W.count)")
        let m = (W.first?.count ?? 0)
        var y = Array(repeating: Float(0), count: m)
        for i in 0..<x.count {
            let xi = x[i]
            if xi == 0 { continue }
            let row = W[i]
            for j in 0..<m {
                y[j] += xi * row[j]
            }
        }
        return y
    }

    private func add(_ x: Vector, _ b: Vector) -> Vector {
        precondition(x.count == b.count, "add dimension mismatch.")
        var y = x
        for i in 0..<x.count {
            y[i] += b[i]
        }
        return y
    }

    private func relu(_ x: Vector) -> Vector {
        var y = x
        for i in 0..<x.count {
            y[i] = max(0, x[i])
        }
        return y
    }

    private func softmax(_ x: Vector) -> Vector {
        guard let maxVal = x.max() else { return x }
        var exps = x.map { expf($0 - maxVal) }
        let sumExp = exps.reduce(0, +)
        if sumExp == 0 { return Array(repeating: 0, count: x.count) }
        for i in 0..<exps.count {
            exps[i] /= sumExp
        }
        return exps
    }
}
