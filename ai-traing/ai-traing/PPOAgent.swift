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
    let hidden_size: Int
    let hidden_layers: Int
    // Hidden state for inference/rollouts (match LSTM hidden state shape)
    var hidden: (h: [Double], c: [Double])?
    var opponent_has_output: Int
    var env: AIEnv
    var opponent_has_output_count: Int
    var turn: Int
    var agent_id: Bool = true
    var agent_has_output: Int
    let max_opponent_can_output: Int = 55
    
    // Control flag for infinite training
    var shouldStop: Bool = false
    
    func stop() {
        shouldStop = true
    }
    
    init(
        action_dim: Int = 11,
        hidden_size: Int = 32,
        hidden_layers: Int = 3,
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
        self.hidden_size = hidden_size
        self.hidden_layers = hidden_layers
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
        self.model = MLP(inputSize: obs_dim, hiddenSize: hidden_size, hiddenLayers: hidden_layers, outputDim: action_dim)
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
    
    func sample(_ probs: [Float]) -> Int {
        let r = Float.random(in: 0..<1)
        var cum: Float = 0
        for (i, p) in probs.enumerated() {
            cum += p
            if r < cum {
                return i
            }
        }
        return probs.count - 1
    }

    func step_one(deterministic: Bool = false) -> (Int, Bool, Bool) {
        var finished = false
        var roundEnded = false
        var action = 0
        
        // Get observation from environment
        var (agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed , now_turn, (agent1_reward, agent2_reward), fin) = env.get_obs()
        
        // Determine "My" observation and "Opponent" observation based on agent_id
        let my_obs: [Float]
        let opp_obs: [Float]
        let my_passed: Bool
        let opp_passed: Bool
        
        if self.agent_id { // AI is Agent 1
            my_obs = agent_obs1
            opp_obs = agent_obs2
            my_passed = agent1_has_passed
            opp_passed = agent2_has_passed
        } else { // AI is Agent 2
            my_obs = agent_obs2
            opp_obs = agent_obs1
            my_passed = agent2_has_passed
            opp_passed = agent1_has_passed
        }
        
        // Convert to agent's observation format
        let ret = self.convert_agent_obs_to_obs(my_obs, opp_obs, my_passed, opp_passed , now_turn);
        
        // --- Model Logic ---
        let (probs, value) = model.forward(x: ret)
        
        // Masking
        let masked_probs = probs.enumerated().map { (i, p) in
            // Check if action i is valid
            if i < 10 {
                // Card play action
                return my_obs[i] == 1 ? p : 0.0 // Zero probability for invalid moves
            } else {
                // Pass action is always valid
                // But we should discourage passing if we have cards to play
                var hasCards = false
                for k in 0..<10 { if my_obs[k] == 1 { hasCards = true; break } }
                
                if hasCards {
                    return p * 0.05 // Heavily discourage passing if cards are available
                }
                return p
            }
        }
        
        // Normalize
        var sumP: Float = 0
        for p in masked_probs { sumP += p }
        
        // If sumP is 0 (shouldn't happen if pass is valid), fallback to uniform over valid actions
        let normalized_probs: [Float]
        if sumP > 1e-10 {
            normalized_probs = masked_probs.map { $0 / sumP }
        } else {
            // Fallback: uniform probability over valid actions
            var validCount = 0
            for i in 0..<10 { if my_obs[i] == 1 { validCount += 1 } }
            validCount += 1 // +1 for Pass
            
            normalized_probs = masked_probs.enumerated().map { (i, _) in
                if i < 10 { return my_obs[i] == 1 ? 1.0 / Float(validCount) : 0.0 }
                else { return 1.0 / Float(validCount) }
            }
        }
        
        if deterministic {
            action = argmax(normalized_probs)
        } else {
            action = sample(normalized_probs)
        }
        
        let prob = normalized_probs[action]

        // Execute action in environment
        let old_turn = now_turn
        (agent_obs1, agent_obs2, agent1_has_passed, agent2_has_passed , now_turn, (agent1_reward, agent2_reward), fin) = env.step(agent_id: agent_id , action: action)
        
        roundEnded = (now_turn != old_turn) || fin

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
        
        return (action, finished, roundEnded)
    }
    
    func train() {
        if !trajectories.isEmpty {
            print("🧠 Starting PPO Training with \(trajectories.count) steps...")
            trainPPOClip(trajectories: trajectories)
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
    
    
    func reset_internal_state(turn: Int) {
        self.turn = turn
        self.opponent_has_output = 0
        self.opponent_has_output_count = 0
        self.hidden = nil
        self.agent_has_output = 0
    }
    
    func heuristic_action(agent_id: Bool) -> Int {
        let (s1, s2) = env.get_round_scores()
        var my_score = agent_id ? s1 : s2
        let opp_score = agent_id ? s2 : s1
        
        // If we are winning, pass to save cards/maintain lead
        if my_score > opp_score && agent_id == false{
            return 10 // Pass
        } else if my_score > opp_score {
            my_score = max(my_score - 10, 0)
        }
        
        // If losing or tied, try to win by 1 point (or catch up)
        let diff = opp_score - my_score
        let target = diff + 1
        
        let my_obs = agent_id ? env.obs_agent1 : env.obs_agent2
        
        // Find smallest card >= target
        var best_action = -1
        
        // 1. Try to find a card that flips the lead
        for i in 0..<10 {
            if my_obs[i] == 1.0 { // Available
                let cardVal = i + 1
                if cardVal >= target {
                    best_action = i
                    break // Found smallest sufficient card
                }
            }
        }
        
        // 2. If no card can flip lead, play smallest available card to catch up (reduce loss margin)
        if best_action == -1 {
            for i in 0..<10 {
                if my_obs[i] == 1.0 {
                    best_action = i
                    break
                }
            }
        }
        
        // 3. If no cards available, must pass
        if best_action == -1 {
            return 10
        }
        
        return best_action
    }
    
    func run(num_episodes: Int, onProgress: ((Int, Float) -> Void)? = nil) async {
        
        // Create opponent for self-play (Agent 2 if self is Agent 1, and vice versa)
        let opponent = PPOAgent(
            action_dim: self.action_dim,
            hidden_size: self.hidden_size,
            hidden_layers: self.hidden_layers,
            gamma: self.gamma,
            gae_lambda: self.gae_lambda,
            clip_coef: self.clip_coef,
            value_coef: self.value_coef,
            entropy_coef: self.entropy_coef,
            lr: 0.0, // Opponent doesn't train directly
            train_epochs: 0,
            max_grad_norm: self.max_grad_norm,
            agent_id: !self.agent_id,
            turn: 0,
            env: self.env
        )
        
        var episode = 0
        self.shouldStop = false
        
        while true {
            // Check termination conditions
            if num_episodes > 0 && episode >= num_episodes { break }
            if shouldStop { 
                print("🛑 Training stopped by user request.")
                break 
            }
            
            // Sync opponent model with self model
            opponent.model = self.model 

            var (_, _, _, _, now_turn, _, fin)  = self.env.reset(agent_id: self.agent_id)
            
            self.reset_internal_state(turn: now_turn)
            opponent.reset_internal_state(turn: now_turn)
            
            // Turn management: true = Agent 1, false = Agent 2
            // Assuming Agent 1 always starts the game/round for simplicity, or alternate based on episode?
            // Let's stick to Agent 1 starts for now.
            var current_turn_agent_id = true 
            
            // 50% chance to play against Heuristic (Deterministic), 50% against Self (Stochastic)
            let useHeuristic = Bool.random()
            
            while !fin {
                // Get current pass states
                let (_, _, ag1Passed, ag2Passed, _, _, f) = self.env.get_obs()
                fin = f
                if fin { break }
                
                // Determine who acts
                var acting_agent_id = current_turn_agent_id
                
                if ag1Passed && !ag2Passed {
                    acting_agent_id = false // Agent 2 must act
                } else if !ag1Passed && ag2Passed {
                    acting_agent_id = true // Agent 1 must act
                }
                
                // Execute action
                if acting_agent_id == self.agent_id {
                    // Self acts (Training: use sampling)
                    let (_, finished, roundEnded) = self.step_one(deterministic: false)
                    fin = finished
                    
                    if roundEnded {
                        // Self caused round end. Opponent (who passed) needs reward update.
                        let oppReward = self.agent_id ? self.env.last_reward.1 : self.env.last_reward.0
                        // Heuristic opponent doesn't track trajectories, so no update needed for it
                    }
                } else {
                    // Opponent acts
                    if useHeuristic {
                        // Heuristic Strategy (Deterministic)
                        let action = self.heuristic_action(agent_id: acting_agent_id)
                        
                        // Execute directly in env
                        let old_turn = now_turn
                        let (_, _, _, _, new_turn, _, finished) = self.env.step(agent_id: acting_agent_id, action: action)
                        fin = finished
                        let roundEnded = (new_turn != old_turn) || fin
                        
                        if roundEnded {
                            // Opponent caused round end. Self (who passed) needs reward update.
                            let myReward = self.agent_id ? self.env.last_reward.0 : self.env.last_reward.1
                            if let lastTraj = self.trajectories.last {
                                lastTraj.reward += myReward
                                lastTraj.done = fin
                            }
                        }
                    } else {
                        // Self-Play (Stochastic)
                        let (_, finished, roundEnded) = opponent.step_one(deterministic: false)
                        fin = finished
                        
                        if roundEnded {
                            // Opponent caused round end. Self (who passed) needs reward update.
                            let myReward = self.agent_id ? self.env.last_reward.0 : self.env.last_reward.1
                            if let lastTraj = self.trajectories.last {
                                lastTraj.reward += myReward
                                lastTraj.done = fin
                            }
                        }
                    }
                }
                
                // Toggle turn if both were active (standard alternation)
                if !ag1Passed && !ag2Passed {
                    current_turn_agent_id = !current_turn_agent_id
                }
            }
            
            // Calculate total reward for this episode
            let episodeReward = self.trajectories.reduce(0) { $0 + $1.reward }

            // Train on trajectories from self perspective only
            trainPPOClip(trajectories: self.trajectories)
            self.trajectories.removeAll()
            
            // Clear opponent trajectories (used in self-play mode)
            opponent.trajectories.removeAll()
            
            // Update progress
            onProgress?(episode + 1, episodeReward)
            
            // Periodic Save (every 50 episodes)
            if (episode + 1) % 50 == 0 {
                do {
                    try model.save()
                    print("💾 Auto-saving model at episode \(episode + 1)...")
                } catch {
                    print("❌ Failed to auto-save model: \(error)")
                }
            }
            
            episode += 1
            
            // Yield to allow UI updates
            await Task.yield()
        }
        
        // Save model after run
        do {
            try model.save()
            print("💾 Model saved successfully after run.")
        } catch {
            print("❌ Failed to save model: \(error)")
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

    func trainPPOClip(trajectories: [Trajectory]) {
        var trajs = trajectories
        computeGAE(trajectories: &trajs)
        
        let states = trajs.map { $0.obs }
        let actions = trajs.map { $0.action }
        let oldLogProbs = trajs.map { $0.logProb }
        let returns = trajs.map { $0.ret }
        let advantages = trajs.map { $0.advantage }
        
        let n = states.count
        
        for _ in 0..<train_epochs {
            model.zeroGrads()
            
            for i in 0..<n {
                let s = states[i]
                let a = actions[i]
                let oldLogP = oldLogProbs[i]
                let adv = advantages[i]
                let ret = returns[i]
                
                let (probs, v) = model.forward(x: s)
                
                // --- Value Head Gradients ---
                // Loss = 0.5 * value_coef * (v - ret)^2
                // dLoss/dv = value_coef * (v - ret)
                let dValue = value_coef * (v - ret) / Float(n)
                
                // --- Policy Head Gradients ---
                let prob = probs[a]
                let logP = log(prob + 1e-10)
                let ratio = exp(logP - oldLogP)
                
                var dLoss_dProb_a: Float = 0
                let unclipped = ratio * adv
                let clipped = min(max(ratio, 1.0 - clip_coef), 1.0 + clip_coef) * adv
                
                // We want to maximize Objective, so minimize Loss = -Objective
                // If unclipped < clipped (meaning unclipped is the active constraint in min), gradient flows
                // Note: This logic depends on sign of adv.
                // Standard PPO: L = min(r*A, clip(r)*A).
                // If r*A < clip(r)*A, then L = r*A. dL/dr = A.
                // If r*A > clip(r)*A, then L = clip(r)*A. dL/dr = 0.
                
                if unclipped < clipped {
                    // d(-L)/dProb = - (d(r*A)/dProb) = - A * (1/oldProb)
                    // ratio = prob / exp(oldLogP)
                    dLoss_dProb_a = -adv / exp(oldLogP)
                } else {
                    dLoss_dProb_a = 0
                }
                
                // Entropy: H = - sum p log p
                // Objective += entropy_coef * H
                // Loss -= entropy_coef * H = entropy_coef * sum p log p
                // dLoss/dp = entropy_coef * (1 + log p)
                
                var dLoss_dProbs = [Float](repeating: 0, count: probs.count)
                for k in 0..<probs.count {
                    dLoss_dProbs[k] += entropy_coef * (1.0 + log(probs[k] + 1e-10))
                    if k == a {
                        dLoss_dProbs[k] += dLoss_dProb_a
                    }
                }
                
                // Backprop through Softmax
                // dL/dz_j = p_j * (dL/dp_j - sum(dL/dp_k * p_k))
                var sum_dLdp_p: Float = 0
                for k in 0..<probs.count {
                    sum_dLdp_p += dLoss_dProbs[k] * probs[k]
                }
                
                var dLogits = [Float](repeating: 0, count: probs.count)
                for j in 0..<probs.count {
                    dLogits[j] = probs[j] * (dLoss_dProbs[j] - sum_dLdp_p)
                    dLogits[j] /= Float(n) // Average over batch
                }
                
                model.backward(x: s, dLogits: dLogits, dValue: dValue)
            }
            
            model.copyGradientsTo(params: optimizer.params)
            optimizer.step()
        }
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
