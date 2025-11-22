//
//  env.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

import Foundation
import Combine
import Observation

@Observable
class AIEnv {
    var obs_agent1: [Float]
    var obs_agent2: [Float]
    var fin: Bool
    var round: Int = 1
    var agent1_wins: Int = 0
    var agent2_wins: Int = 0

    // Internal state flags — do not use @State in ObservableObject
    private var agent1_has_passed: Bool = false
    private var agent2_has_passed: Bool = false
    private var agent1_has_output: Int = 0
    private var agent2_has_output: Int = 0
    
    // Track scores from previous rounds to calculate current round score
    var agent1_score_history: Int = 0
    var agent2_score_history: Int = 0
    
    var lastRoundScores: (Int, Int) = (0, 0)
    var lastRoundNumber: Int = 0
    var showRoundResult: Bool = false
    
    // Track cards played in the current round
    var agent1_round_cards: [Int] = []
    var agent2_round_cards: [Int] = []
    var last_reward: (Float, Float) = (0.0, 0.0)
    
    init() {
        self.obs_agent1 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        self.obs_agent2 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        self.fin = false
        self.round = 1
    }
    
    func reset(agent_id: Bool) -> ([Float], [Float], Bool , Bool, Int, (Float, Float), Bool) {
        obs_agent1 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        obs_agent2 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        fin = false
        round = 1
        agent1_wins = 0
        agent2_wins = 0
        agent1_has_passed = false
        agent2_has_passed = false
        agent1_has_output = 0
        agent2_has_output = 0
        agent1_score_history = 0
        agent2_score_history = 0
        agent1_round_cards = []
        agent2_round_cards = []
        return (obs_agent1, obs_agent2, agent1_has_passed, agent2_has_passed, round, (0.0, 0.0), fin)
    }

    func calculate_total_score(obs: [Float]) -> Int {
        var score = 0
        for i in 0..<obs.count {
            if obs[i] == 0.0 {
                score += (i + 1)
            }
        }
        return score
    }

    func get_round_scores() -> (Int, Int) {
        let s1 = calculate_total_score(obs: obs_agent1) - agent1_score_history
        let s2 = calculate_total_score(obs: obs_agent2) - agent2_score_history
        return (s1, s2)
    }

    func get_obs() -> ([Float], [Float],Bool, Bool, Int, (Float, Float), Bool) {
        return (obs_agent1, obs_agent2, agent1_has_passed , agent2_has_passed, round, (0.0, 0.0), fin)
    }
    
    func step(agent_id: Bool, action: Int) -> ([Float], [Float],Bool, Bool, Int, (Float, Float), Bool) {
        var reward: (Float, Float) = (0.0, 0.0)
        
        // Apply action
        if agent_id { // Agent 1
            if action < 10 {
                obs_agent1[action] = 0.0
                agent1_round_cards.append(action + 1)
                reward.0 += 0.2 // Reward for playing a card
            } else {
                agent1_has_passed = true
                reward.0 -= 1.0 // Stronger penalty for passing
            }
        } else { // Agent 2
            if action < 10 {
                obs_agent2[action] = 0.0
                agent2_round_cards.append(action + 1)
                reward.1 += 0.2 // Reward for playing a card
            } else {
                agent2_has_passed = true
                reward.1 -= 1.0 // Stronger penalty for passing
            }
        }
        
        // Check for Round End
        if agent1_has_passed && agent2_has_passed {
            let score1_total = calculate_total_score(obs: obs_agent1)
            let score2_total = calculate_total_score(obs: obs_agent2)
            
            let round_score1 = score1_total - agent1_score_history
            let round_score2 = score2_total - agent2_score_history
            
            lastRoundScores = (round_score1, round_score2)
            lastRoundNumber = round
            
            print("End of Round \(round). Scores: Agent1=\(round_score1), Agent2=\(round_score2)")
            
            let score_diff = Float(round_score1 - round_score2)
            let scaled_diff = score_diff / 55.0
            
            if round_score1 > round_score2 {
                agent1_wins += 1
                reward.0 += (1.0 + scaled_diff)
                reward.1 += (-1.0 - scaled_diff)
            } else if round_score2 > round_score1 {
                agent2_wins += 1
                reward.0 += (-1.0 + scaled_diff)
                reward.1 += (1.0 - scaled_diff)
            } else {
                // Draw
            }
            
            // Update history
            agent1_score_history = score1_total
            agent2_score_history = score2_total
            
            // Check Game Over
            if round == 3 {
                fin = true
                // Bonus reward for winning game
                if agent1_wins > agent2_wins {
                    reward.0 += 5.0
                    reward.1 -= 5.0
                } else if agent2_wins > agent1_wins {
                    reward.0 -= 5.0
                    reward.1 += 5.0
                }
            } else {
                showRoundResult = true
                // Prepare for next round
                round += 1
                agent1_has_passed = false
                agent2_has_passed = false
                agent1_round_cards = []
                agent2_round_cards = []
                // Note: We do NOT reset obs_agent (cards remain played)
            }
        }
        
        self.last_reward = reward
        return (obs_agent1, obs_agent2, agent1_has_passed, agent2_has_passed, round, reward, fin)
    }

    func resolveShowdown() {
        // In Showdown, we consider all remaining cards as played for scoring purposes,
        // but we do NOT zero them out in 'obs' so they can be counted as "Remaining" in the UI.
        
        // Total possible score (sum of 1..10) is 55.
        let score1_total = 55
        let score2_total = 55
        
        let round_score1 = score1_total - agent1_score_history
        let round_score2 = score2_total - agent2_score_history
        
        lastRoundScores = (round_score1, round_score2)
        lastRoundNumber = 3
        
        print("Showdown Round 3. Scores: Agent1=\(round_score1), Agent2=\(round_score2)")
        
        if round_score1 > round_score2 {
            agent1_wins += 1
        } else if round_score2 > round_score1 {
            agent2_wins += 1
        }
        
        // Bonus reward for winning game
        var bonus: (Float, Float) = (0.0, 0.0)
        if agent1_wins > agent2_wins {
            bonus.0 += 5.0
            bonus.1 -= 5.0
        } else if agent2_wins > agent1_wins {
            bonus.0 -= 5.0
            bonus.1 += 5.0
        }
        self.last_reward = bonus
        
        fin = true
    }
}
