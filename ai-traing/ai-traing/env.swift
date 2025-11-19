//
//  env.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

class env {
    
    var obs_agent1: Array<Float>
    var obs_agent2: Array<Float>
    var fin: Bool
    var turn: Int

    init() {
        self.obs_agent1 =  [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        self.obs_agent2 =  [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        self.fin = false
        self.turn = 1
    }
    
    func reset(agent_id: Bool) -> ([Float], [Float], Int, Float, Bool){
        obs_agent1 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        obs_agent2 = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
        fin = false
        turn = 1
        return (obs_agent1 , obs_agent2, turn, 0.0, fin)
    }
    func step(agent_id: Bool, action: Int) -> ([Float], [Float], Int, Float, Bool){
        
        if (agent_id) {
            
            
            
            return (obs_agent1, obs_agent2, turn, 0.0, fin)
        } else {
            
            
            return (obs_agent1, obs_agent2, turn, 0.0, fin)
        }
        
        
    }
}
