//
//  env.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

import Foundation
import Combine
import SwiftUI
import UIKit

class AIEnv: ObservableObject {
    @Published var obs_agent1: [Float]
    @Published var obs_agent2: [Float]
    @Published var fin: Bool
    @Published var turn: Int

    // Internal state flags — do not use @State in ObservableObject
    private var agent1_has_passed: Bool = false
    private var agent2_has_passed: Bool = false
    private var agent1_has_output: Int = 0
    private var agent2_has_output: Int = 0
    
    init() {
        self.obs_agent1 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        self.obs_agent2 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        self.fin = false
        self.turn = 1
    }
    
    func reset(agent_id: Bool) -> ([Float], [Float], Bool , Bool, Int, (Float, Float), Bool) {
        obs_agent1 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        obs_agent2 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        fin = false
        turn = 1
        agent1_has_passed = false
        agent2_has_passed = false
        agent1_has_output = 0
        agent2_has_output = 0
        return (obs_agent1, obs_agent2, agent1_has_passed, agent2_has_passed, turn, (0.0, 0.0), fin)
    }

    func get_heristic_reward(agent_id: Bool) -> (Float, Float) {
        var agent1_output: Float = 0.0
        var agent2_output: Float = 0.0

        for i in 0..<10 {
            if obs_agent1[i] == 0.0 {
                agent1_output += 1
            }
            if obs_agent2[i] == 0.0 {
                agent2_output += 1
            }
        }

        agent1_output -= Float(agent1_has_output)
        agent2_output -= Float(agent2_has_output)
        
        var agent1_reward: Float = 0.0
        var agent2_reward: Float = 0.0

        let diff = agent1_output - agent2_output
        if diff > 0 {
            agent1_reward = 1.0 / diff
            agent2_reward = -agent1_reward
        } else if diff < 0 {
            agent2_reward = 1.0 / (-diff)
            agent1_reward = -agent2_reward
        } else {
            // Equal outputs; no advantage
            agent1_reward = 0.0
            agent2_reward = 0.0
        }

        agent1_has_output += Int(agent1_output)
        agent2_has_output += Int(agent2_output)

        return (agent1_reward, agent2_reward)
    }
    func get_obs() -> ([Float], [Float],Bool, Bool, Int, (Float, Float), Bool) {
        return (obs_agent1, obs_agent2, agent1_has_passed , agent2_has_passed, turn, (0.0, 0.0), fin)
    }
    func step(agent_id: Bool, action: Int) -> ([Float], [Float],Bool, Bool, Int, (Float, Float), Bool) {
        if agent_id {
            if action < 10 {
                obs_agent1[action] = 0.0
                return (obs_agent1, obs_agent2, agent1_has_passed , agent2_has_passed, turn, (0.0, 0.0), fin)
            } else { // pass
                agent1_has_passed = true
                var reward: (Float, Float) = (0.0, 0.0)
                if agent1_has_passed && agent2_has_passed {
                    reward = get_heristic_reward(agent_id: true)
                    fin = true
                }
                return (obs_agent1, obs_agent2,agent1_has_passed, agent2_has_passed, turn, reward, fin)
            }
        } else {
            if action < 10 {
                obs_agent2[action] = 0.0
                return (obs_agent1, obs_agent2, agent1_has_passed , agent2_has_passed, turn, (0.0, 0.0), fin)
            } else { // pass
                agent2_has_passed = true
                var reward: (Float, Float) = (0.0, 0.0)
                if agent1_has_passed && agent2_has_passed {
                    reward = get_heristic_reward(agent_id: false)
                    fin = true
                }
                return (obs_agent1, obs_agent2,agent1_has_passed, agent2_has_passed,turn, reward, fin)
            }
        }
    }
}
