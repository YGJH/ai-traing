import Foundation
import SwiftUI


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
    var trajectories: [Trajectory]

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
    var env: AIEnv
    var opponent_has_output_count: Int
    var turn: Int
    var agent_id: Bool = true
    var agent_has_output: Int
    let max_opponent_can_output: Int = 55
    init(
        action_dim: Int = 11,
        hidden_size: Int = 32,
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
        env: AIEnv
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
        let (agent_obs1, _, _, _ , now_turn, _, _) = env.reset(agent_id: agent_id)
        // Observation length = base obs (agent_obs1) + 6 derived scalars appended in convert_agent_obs_to_obs
        let obs_dim = agent_obs1.count + 6
        self.trajectories = []
        // Initialize remaining state as desired
        self.turn = now_turn
        self.opponent_has_output = 0
        self.opponent_has_output_count = 0
        self.agent_has_output = 0
        self.hidden = nil

        // Now it's safe to initialize properties that may use self later
        self.model = MLP(inputSize: obs_dim, hiddenSize: hidden_size, hiddenLayers: 3, outputDim: action_dim)
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
    
    
    func convert_agent_obs_to_obs(_ agent_obs1: [Float] , _ agent_obs2: [Float],_ agent1_has_passed: Bool , _ agent2_has_passed: Bool , _ now_turn: Int) -> Vector {
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
        ret.append(Float(agent1_has_passed ? 1.0 : 0.0))
        ret.append(Float(agent2_has_passed ? 1.0 : 0.0))
        // agent input dim = 13
        
        return ret
        
    }
    
    func step_one() -> (Int, Bool) {
        var finished = false
        var action = 0
        
        // Get observation from environment
        var (agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed , now_turn, (agent1_reward, agent2_reward), fin) = env.get_obs()
        
        // Convert to agent's observation format
        let ret = self.convert_agent_obs_to_obs(agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed , now_turn);
        
        // --- Model Logic ---
        let (probs, value) = model.forward(x: ret)
        
        // Simple masking to prevent invalid moves (optional but recommended)
        // We can just use argmax for now as requested, but let's at least try to pick a valid one if the max is invalid?
        // For now, restoring original behavior as requested:
        let masked_probs = probs.enumerated().map { (i, p) in
            // Check if action i is valid
            if i < 10 {
                // Card play action
                return agent_obs1[i] == 1 ? p : -1000.0 // Can only play if card is not used
            } else {
                // Pass action is always valid
                return p
            }
        }
        action = argmax(masked_probs)
        let prob = masked_probs[action]

        // Execute action in environment
        (agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed , now_turn, (agent1_reward, agent2_reward), fin) = env.step(agent_id: agent_id , action: action)
        
        // Store trajectory
        let traj = Trajectory(
            obs: ret,
            action: action,
            logProb: log(prob + 1e-10), // Avoid log(0)
            value: value,
            reward: Float(self.agent_id ? agent1_reward : agent2_reward),
            done: fin
        )
        self.trajectories.append(traj)
        finished = fin
        
        // Note: Training is now triggered manually by GameView via train()
        
        return (action, finished)
    }
    
    func train() {
        if !trajectories.isEmpty {
            print("🧠 Starting PPO Training with \(trajectories.count) steps...")
            trainTRPO(trajectories: trajectories)
            trajectories.removeAll()
            
            // Save model
            do {
                try model.save()
                print("💾 Model saved successfully.")
            } catch {
                print("❌ Failed to save model: \(error)")
            }
            
            print("✅ Training Complete.")
        }
    }
    
    
    func run(num_episodes: Int) {
        
        
        for _ in 0..<num_episodes{

            var (agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed , now_turn, (agent1_reward, agent2_reward), fin)  = self.env.reset(agent_id: self.agent_id)
            self.turn = now_turn
            self.opponent_has_output = 0
            self.opponent_has_output_count = 0
            self.hidden = nil // 每局一開始把 LSTM hidden 清空
            self.agent_has_output = 0
            while !fin {
                let agent_obs = convert_agent_obs_to_obs(agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed, now_turn)
                // 準備初始 hidden state（若為 nil 則用全 0）

                // 先綁定到區域變數，再把新 hidden 寫回屬性，避免「Expected pattern」

                let (probs, value) = self.model.forward(x: agent_obs)
                let action = argmax(probs)

                (agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed, now_turn, (agent1_reward, agent2_reward), fin) = self.env.step(agent_id: self.agent_id, action: action)

                let traj = Trajectory(
                    obs: agent_obs,
                    action: action,
                    logProb: probs[action],
                    value: value,
                    reward: Float(self.agent_id ? agent1_reward : agent2_reward),
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

        // Pre-compute old probs for KL
        var oldProbs: [Vector] = []
        for s in states {
            let (p, _) = model.forward(x: s)
            oldProbs.append(p)
        }

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
                                  oldProbs: oldProbs,
                                  cgIters: cgIters,
                                  cgDamping: cgDamping)

        // 6. 算 x^T H x （用 fisherVectorProduct）
        let Hx = fisherVectorProduct(x,
                                     states: states,
                                     oldProbs: oldProbs,
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
                   oldProbs: oldProbs,
                   advantages: advantages,
                   maxKL: maxKL,
                   lineSearchSteps: lineSearchSteps)
        
        // 8. value head 用 MSE + Adam 更新（可另外寫一個 trainValue(...)）
        trainValue(trajectories: trajs)
    }
    
    func conjugateGradient(b: [Float],
                           states: [Vector],
                           oldProbs: [Vector],
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
                                         oldProbs: oldProbs,
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
        let n = Float(trajectories.count)
        // 用 Adam 做 regression: minimize (V(s) - R)^2
        for _ in 0..<valueEpochs {
            model.zeroGrads()

            var totalLoss: Float = 0
            for traj in trajectories {
                let s = traj.obs
                let target = traj.ret

                let (_, v) = model.forward(x: s)

                let diff = v - target
                let loss = 0.5 * diff * diff
                totalLoss += loss

                // dLoss/dv = (v - target)
                // Average over batch
                let dValue = (v - target) / n
                model.backward(x: s, dLogits: nil, dValue: dValue)
            }

            model.copyGradientsTo(params: optimizer.params)
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
                    oldProbs: [Vector],
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
            let kl = meanKL(states: states, oldProbs: oldProbs)

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
                oldProbs: [Vector]) -> Float
    {
        var totalKL: Float = 0
        let n = states.count
        
        for i in 0..<n {
            let s = states[i]
            let pOld = oldProbs[i]
            let (pNew, _) = model.forward(x: s)
            
            // KL = sum pOld * (log pOld - log pNew)
            var kl: Float = 0
            for j in 0..<pOld.count {
                let po = pOld[j]
                let pn = pNew[j]
                if po > 1e-8 && pn > 1e-8 {
                    kl += po * (log(po) - log(pn))
                }
            }
            totalKL += kl
        }
        
        return totalKL / Float(n)
    }

    
                                        
    func fisherVectorProduct(_ v: [Float],
                             states: [Vector],
                             oldProbs: [Vector],
                             cgDamping: Float) -> [Float]
    {
        // Finite difference: Hv approx (gradKL(theta + eps*v) - gradKL(theta)) / eps
        // Since gradKL(theta) is 0, Hv approx gradKL(theta + eps*v) / eps
        
        let eps: Float = 1e-2 / (sqrt(dot(v, v)) + 1e-8)
        let oldParams = getFlatParameters()
        
        // theta + eps * v
        let newParams = zip(oldParams, v).map { $0 + eps * $1 }
        setFlatParameters(newParams)
        
        // Compute grad KL
        model.zeroGrads()
        let n = states.count
        
        for i in 0..<n {
            let s = states[i]
            let pOld = oldProbs[i]
            let (pNew, _) = model.forward(x: s)
            
            // grad KL w.r.t logits = (pNew - pOld) / N
            var dLogits = [Float](repeating: 0, count: pNew.count)
            for j in 0..<pNew.count {
                dLogits[j] = (pNew[j] - pOld[j]) / Float(n)
            }
            
            model.backward(x: s, dLogits: dLogits, dValue: nil)
        }
        
        model.copyGradientsTo(params: optimizer.params)
        
        // Extract grad
        var gKL: [Float] = []
        for p in optimizer.params {
            gKL.append(contentsOf: p.grad)
        }
        
        // Restore params
        setFlatParameters(oldParams)

        var result = [Float](repeating: 0, count: v.count)
        for i in 0..<v.count {
            result[i] = gKL[i] / eps + cgDamping * v[i]
        }
        return result
    }

    
    func computePolicyGradient(states: [Vector],
                               actions: [Int],
                               oldLogProbs: [Float],
                               advantages: [Float]) -> [Float]
    {
        // 1. Clear internal grads
        model.zeroGrads()

        // 2. 對每個 sample 算 policy loss，並把 grad 寫入 Parameter1D.grad
        let n = states.count
        
        for i in 0..<n {
            let s = states[i]
            let a = actions[i]
            let oldLogP = oldLogProbs[i]
            let adv = advantages[i]

            let (probs, _) = model.forward(x: s)
            let logP = log(probs[a] + 1e-10)
            let ratio = expf(logP - oldLogP)

            // Loss = - ratio * adv
            // dLoss/dLogits = - adv * ratio * (delta_aj - pi_j)
            //               = adv * ratio * (pi_j - delta_aj)
            
            var dLogits = [Float](repeating: 0, count: probs.count)
            for j in 0..<probs.count {
                if j == a {
                    dLogits[j] = adv * ratio * (probs[j] - 1.0)
                } else {
                    dLogits[j] = adv * ratio * probs[j]
                }
                // Average over batch
                dLogits[j] /= Float(n)
            }
            
            model.backward(x: s, dLogits: dLogits, dValue: nil)
        }

        // 3. Copy to params
        model.copyGradientsTo(params: optimizer.params)
        
        // 4. Flatten
        var g: [Float] = []
        for p in optimizer.params {
            g.append(contentsOf: p.grad)
        }

        return g
    }


    
    
    
}
