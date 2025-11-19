import Foundation

typealias Vector = [Float]

class Trajectory {
    var obs: Vector
    var action: Int
    var logProb: Float   // log π_old(a|s)
    var value: Float
    var reward: Float
    var done: Bool

    var advantage: Float = 0
    var ret: Float = 0

    init(obs: Vector,
         action: Int,
         logProb: Float,
         value: Float,
         reward: Float,
         done: Bool)
    {
        self.obs = obs
        self.action = action
        self.logProb = logProb
        self.value = value
        self.reward = reward
        self.done = done
    }
}

class PPOAgent {
    // Core model and optimizer
    var model: MLP
    var optimizer: Adam
    
    // PPO hyperparameters
    let gamma: Float
    let gae_lambda: Float
    let clip_coef: Float
    let value_coef: Float
    let entropy_coef: Float
    let train_epochs: Int
    let max_grad_norm: Float
    let action_dim: Int
    // Hidden state for inference/rollouts (match LSTM hidden state shape)
    var hidden: (h: [Double], c: [Double])?
    var opponent_has_output: Int
    var env: env
    var opponent_has_output_count: Int
    var turn: Int
    var agent_id: Bool = true
    var agent_has_output: Int
    let max_opponent_can_output: Int = 55
    init(
        action_dim: Int,
        hidden_size: Int = 64,
        gamma: Float = 0.99,
        gae_lambda: Float = 0.95,
        clip_coef: Float = 0.2,
        value_coef: Float = 0.5,
        entropy_coef: Float = 0.01,
        lr: Double = 3e-4,
        train_epochs: Int = 4,
        max_grad_norm: Float = 0.5,
        agent_id: Bool = true,
        turn: Int,
        env: env
    ){
        self.opponent_has_output = 0
        self.turn = 1
        self.gamma = gamma
        self.gae_lambda = gae_lambda
        self.clip_coef = clip_coef
        self.value_coef = value_coef
        self.entropy_coef = entropy_coef
        self.train_epochs = train_epochs
        self.max_grad_norm = max_grad_norm
        self.opponent_has_output_count = 0
        self.agent_has_output = 0
        // 推論時用的 hidden state（收軌跡用）
        self.hidden = nil
        self.env = env
        self.action_dim = action_dim
        self.agent_id = agent_id
        
        // Obtain a sample observation to determine input size without using self
        let (agent_obs1, _, now_turn, _, _) = env.reset(agent_id: agent_id)
        // Observation length = base obs (agent_obs1) + 3 derived scalars appended in convert_agent_obs_to_obs
        let obs_dim = agent_obs1.count + 4
        
        // Initialize remaining state as desired
        self.turn = now_turn
        self.opponent_has_output = 0
        self.opponent_has_output_count = 0
        self.agent_has_output = 0
        self.hidden = nil
        
        // Now it's safe to initialize properties that may use self later
        self.model = MLP(inputSize: obs_dim, hiddenSize: hidden_size, hiddenLayers: 5, outputDim: action_dim)
        self.optimizer = Adam(params: self.model.parameters(), lr: lr)
    }
    

    func argmax(_ prob: [Float]) -> Int {
        var mx: Float = -Float.greatestFiniteMagnitude
        var idx: Int = -1
        for i in (0..<prob.count) {
            if prob[i] > mx {
                mx = prob[i]
                idx = i
            }
        }
        return idx
    }
    
    
    func convert_agent_obs_to_obs(_ agent_obs1: [Float] , _ agent_obs2: [Float] ,_ now_turn: Int) -> Vector {
        var ret: Vector = []
        if(now_turn != self.turn) {
            self.opponent_has_output = 0
            self.opponent_has_output_count = 0
            for i in 0..<agent_obs2.count {
                if agent_obs2[i] == 0 {
                    self.opponent_has_output += (i + 1);
                    self.opponent_has_output_count += 1
                }
            }
            self.agent_has_output = 0
            for i in 0..<agent_obs1.count {
                if agent_obs1[i] == 0 {
                    self.agent_has_output += (i+1)
                }
            }
            self.turn = now_turn
        }
        var agent_has_output = 0
        var agent_can_output = 0
        var opponent_has_output_count = 0
        for i in 0..<agent_obs1.count {
            ret.append(Float(agent_obs1[i]))
            if agent_obs1[i] == 0 {
                agent_has_output += (i+1)
            }
            else {
                agent_can_output += (i+1)
            }
        }
        
        agent_has_output -= self.agent_has_output
        
        ret.append(Float(agent_has_output))
        
        for i in 0..<agent_obs2.count {
            if agent_obs2[i] == 0 {
                opponent_has_output_count += 1
            }
        }
        opponent_has_output_count -= self.opponent_has_output_count
        
        ret.append(Float(opponent_has_output_count))
        ret.append(Float(max_opponent_can_output - self.opponent_has_output))
        ret.append(Float(agent_can_output))
        
        // agent input dim = 13
        
        return ret
        
    }
    
    
    
    
    func run(num_episodes: Int) {
        
        var trajectories: [Trajectory] = []
        
        for _ in 0..<num_episodes{
            
            var (agent_obs1, agent_obs2, now_turn, reward, fin) = self.env.reset(agent_id: self.agent_id)
            self.turn = now_turn
            self.opponent_has_output = 0
            self.opponent_has_output_count = 0
            self.hidden = nil // 每局一開始把 LSTM hidden 清空
            self.agent_has_output = 0
            while !fin {
                let agent_obs = convert_agent_obs_to_obs(agent_obs1, agent_obs2, now_turn)
                // 準備初始 hidden state（若為 nil 則用全 0）

                // 先綁定到區域變數，再把新 hidden 寫回屬性，避免「Expected pattern」

                let (probs, value) = self.model.forward(x: agent_obs)
                let action = argmax(probs)

                (agent_obs1, agent_obs2, now_turn, reward, fin) = self.env.step(agent_id: self.agent_id, action: action)

                let traj = Trajectory(
                    obs: agent_obs,
                    action: action,
                    logProb: probs[action],
                    value: value,
                    reward: reward,
                    done: fin
                )
                trajectories.append(traj)
            }
            
            
            // train
            // 一局結束後，用 trajectories 做 TRPO 更新
            trainTRPO(trajectories: trajectories)

        }
    }
    
    
    func computeGAE(trajectories: inout [Trajectory]) {
        var nextValue: Float = 0
        var nextAdvantage: Float = 0

        // 從最後一個 timestep 往前推
        for i in stride(from: trajectories.count - 1, through: 0, by: -1) {
            let traj = trajectories[i]

            let reward = traj.reward
            let value = traj.value
            let done = traj.done

            let mask: Float = done ? 0.0 : 1.0

            // δ_t = r_t + γ V(s_{t+1}) - V(s_t)
            let delta = reward + gamma * nextValue * mask - value

            // A_t = δ_t + γλ A_{t+1}
            let advantage = delta + gamma * gae_lambda * nextAdvantage * mask

            let ret = advantage + value

            traj.advantage = advantage
            traj.ret = ret

            nextAdvantage = advantage
            nextValue = value
        }

        // 可選：把 advantage 標準化，穩定訓練
        let advs = trajectories.map { $0.advantage }
        let meanAdv = advs.reduce(0, +) / Float(advs.count)
        let varAdv = advs.reduce(0) { $0 + ($1 - meanAdv) * ($1 - meanAdv) } / Float(advs.count)
        let stdAdv = sqrt(max(varAdv, 1e-8))

        for traj in trajectories {
            traj.advantage = (traj.advantage - meanAdv) / stdAdv
        }
    }

    func getFlatParameters() -> [Float] {
        var flat: [Float] = []
        for p in optimizer.params {
            flat.append(contentsOf: p.data)
        }
        return flat
    }

    func setFlatParameters(_ flat: [Float]) {
        var offset = 0
        for p in optimizer.params {
            let n = p.data.count
            let slice = Array(flat[offset..<offset+n])
            p.data = slice
            offset += n
        }
    }

    func dot(_ a: [Float], _ b: [Float]) -> Float {
        precondition(a.count == b.count)
        var s: Float = 0
        for i in 0..<a.count {
            s += a[i] * b[i]
        }
        return s
    }

    func trainTRPO(trajectories: [Trajectory],
                   maxKL: Float = 1e-2,
                   cgIters: Int = 10,
                   cgDamping: Float = 1e-3,
                   lineSearchSteps: Int = 10)
    {
        // 1. 算 advantage / returns
        var trajs = trajectories
        computeGAE(trajectories: &trajs)

        // 2. flatten trajectories for convenience
        let states  = trajs.map { $0.obs }
        let actions = trajs.map { $0.action }
        let oldLogProbs = trajs.map { $0.logProb }
        let advantages = trajs.map { $0.advantage }

        // 3. 存舊參數（用來算 KL）
        let oldParams = getFlatParameters()

        // 4. 算 policy gradient g
        let g = computePolicyGradient(states: states,
                                      actions: actions,
                                      oldLogProbs: oldLogProbs,
                                      advantages: advantages)

        // 如果 g 幾乎 0，就不用更新
        let gNorm = sqrt(dot(g, g))
        if gNorm < 1e-8 {
            return
        }

        // 5. 用 conjugate gradient 解 Hx = g，得到 search direction x
        let x = conjugateGradient(b: g,
                                  states: states,
                                  actions: actions,
                                  oldLogProbs: oldLogProbs,
                                  cgIters: cgIters,
                                  cgDamping: cgDamping)

        // 6. 算 x^T H x （用 fisherVectorProduct）
        let Hx = fisherVectorProduct(x,
                                     states: states,
                                     actions: actions,
                                     oldLogProbs: oldLogProbs,
                                     cgDamping: cgDamping)
        let xHx = dot(x, Hx)
        let stepSize = sqrt(2 * maxKL / (xHx + 1e-8))

        let fullStep = x.map { $0 * stepSize }

        // 7. line search
        lineSearch(oldParams: oldParams,
                   fullStep: fullStep,
                   states: states,
                   actions: actions,
                   oldLogProbs: oldLogProbs,
                   advantages: advantages,
                   maxKL: maxKL,
                   lineSearchSteps: lineSearchSteps)
        
        // 8. value head 用 MSE + Adam 更新（可另外寫一個 trainValue(...)）
        trainValue(trajectories: trajs)
    }
    
    func conjugateGradient(b: [Float],
                           states: [Vector],
                           actions: [Int],
                           oldLogProbs: [Float],
                           cgIters: Int,
                           cgDamping: Float) -> [Float]
    {
        var x = [Float](repeating: 0, count: b.count)
        var r = b
        var p = r
        var rdotr = dot(r, r)

        for _ in 0..<cgIters {
            let Ap = fisherVectorProduct(p,
                                         states: states,
                                         actions: actions,
                                         oldLogProbs: oldLogProbs,
                                         cgDamping: cgDamping)
            let alpha = rdotr / (dot(p, Ap) + 1e-8)
            for i in 0..<x.count {
                x[i] += alpha * p[i]
                r[i] -= alpha * Ap[i]
            }
            let newRdotr = dot(r, r)
            if newRdotr < 1e-10 {
                break
            }
            let beta = newRdotr / (rdotr + 1e-8)
            for i in 0..<p.count {
                p[i] = r[i] + beta * p[i]
            }
            rdotr = newRdotr
        }
        return x
    }

    
    func trainValue(trajectories: [Trajectory],
                    valueEpochs: Int = 2)
    {
        // 用 Adam 做 regression: minimize (V(s) - R)^2
        for _ in 0..<valueEpochs {
            optimizer.zeroGrad()

            var totalLoss: Float = 0
            for traj in trajectories {
                let s = traj.obs
                let target = traj.ret

                let (_, v) = model.forward(x: s)

                let diff = v - target
                let loss = 0.5 * diff * diff
                totalLoss += loss

                // TODO: 手刻 value head 的反向傳播，把 ∂loss/∂params
                // 寫進 Parameter1D.grad
            }

            // 用 Adam.step() 更新（這裡同時也會動到 policy 的參數，因為你 shared trunk；
            // 如果要完全分開 policy / value 的參數，可以改架構）
            optimizer.step()
        }
    }
    func policyLoss(states: [Vector],
                    actions: [Int],
                    oldLogProbs: [Float],
                    advantages: [Float]) -> Float
    {
        var loss: Float = 0
        let n = states.count

        for i in 0..<n {
            let s = states[i]
            let a = actions[i]
            let oldLogP = oldLogProbs[i]
            let adv = advantages[i]

            let (logProbs, _) = model.forward(x: s)
            let logP = logProbs[a]
            let ratio = expf(logP - oldLogP)

            loss += -ratio * adv
        }
        return loss / Float(n)
    }
    
    
    func lineSearch(oldParams: [Float],
                    fullStep: [Float],
                    states: [Vector],
                    actions: [Int],
                    oldLogProbs: [Float],
                    advantages: [Float],
                    maxKL: Float,
                    lineSearchSteps: Int)
    {
        let oldLoss = policyLoss(states: states,
                                 actions: actions,
                                 oldLogProbs: oldLogProbs,
                                 advantages: advantages)

        var stepFrac: Float = 1.0

        for _ in 0..<lineSearchSteps {
            let newParams = zip(oldParams, fullStep).map { $0 + stepFrac * $1 }
            setFlatParameters(newParams)

            let newLoss = policyLoss(states: states,
                                     actions: actions,
                                     oldLogProbs: oldLogProbs,
                                     advantages: advantages)
            let kl = meanKL(states: states, oldLogProbs: oldLogProbs)

            if newLoss < oldLoss && kl <= maxKL {
                // 接受這個 step
                print("Line search accept, stepFrac =", stepFrac)
                return
            }

            stepFrac *= 0.5
        }

        // 如果全部都 fail，就退回舊參數
        setFlatParameters(oldParams)
        print("Line search failed, revert parameters")
    }
    
    func meanKL(states: [Vector],
                oldLogProbs: [Float]) -> Float
    {
        // TODO: 真 TRPO 要 π_old 全分布；這裡簡化成 approximate KL，
        // 你可以再改成完整版本
        
        return 0.0
    }

    
    
    func fisherVectorProduct(_ v: [Float],
                             states: [Vector],
                             actions: [Int],
                             oldLogProbs: [Float],
                             cgDamping: Float) -> [Float]
    {
        // 1. 把 grad 歸 0
        optimizer.zeroGrad()

        // 2. 算平均 KL(π_old || π_new)
        let n = states.count
        var totalKL: Float = 0

        for i in 0..<n {
            let s = states[i]
            let (logProbsNew, _) = model.forward(x: s)
            // π_old 是 fixed，所以你要把當初的 prob 儲存起來（或 logProbsOld）
            // 這裡簡化成用 oldLogProbs[i] 代表 log π_old(a_i | s_i)，
            // 真正 KL 其實要 sum over all actions，這裡就先留 TODO

            // TODO: 真正應該是：
            //   KL(π_old || π_new) = sum_a π_old(a) * (log π_old(a) - log π_new(a))
            // 你 rollout 時可以順便存整個 π_old(a) vector，而不是只有 logπ_old(a_t)
        }

        let meanKL = totalKL / Float(n)

        // 3. 對 meanKL 做一次 backprop，取得 ∇_θ KL
        // TODO: 手刻 KL 的梯度，寫到 Parameter1D.grad

        // 4. 把 grad flatten 成一條 g_kl
        var gKL: [Float] = []
        for p in optimizer.params {
            gKL.append(contentsOf: p.grad)
        }

        // 5. H v ≈ (∇KL ⋅ v) + damping * v
        // 真正的 Hv 算法應該用 "Jacobian-vector product" 的 trick，
        // 這裡我們簡化，只給出骨架，你實作時可以照 TRPO 論文 / PyTorch 實作改。

        var result = [Float](repeating: 0, count: v.count)
        for i in 0..<v.count {
            result[i] = gKL[i] + cgDamping * v[i]
        }
        return result
    }

    
    func computePolicyGradient(states: [Vector],
                               actions: [Int],
                               oldLogProbs: [Float],
                               advantages: [Float]) -> [Float]
    {
        // 1. 把所有 grad 歸 0
        optimizer.zeroGrad()

        // 2. 對每個 sample 算 policy loss，並把 grad 寫入 Parameter1D.grad
        let n = states.count
        var totalLoss: Float = 0

        for i in 0..<n {
            let s = states[i]
            let a = actions[i]
            let oldLogP = oldLogProbs[i]
            let adv = advantages[i]

            let (logProbs, _) = model.forward(x: s)
            let logP = logProbs[a]
            let ratio = expf(logP - oldLogP)

            let loss_i = -ratio * adv  // 要 maximize，所以加負號
            totalLoss += loss_i

            // TODO: 這裡你要：
            //   1. 算出 ∂loss_i/∂logits, ∂loss_i/∂value 等
            //   2. 手刻 MLP 的 backprop，把梯度一路傳到 W, b, heads
            //   3. 把結果寫進對應的 Parameter1D.grad
        }

        // 3. grad 現在都在各個 Parameter1D.grad 裡，把它們 flatten 成 g
        var g: [Float] = []
        for p in optimizer.params {
            g.append(contentsOf: p.grad)
        }

        return g
    }


    
    
    
}
