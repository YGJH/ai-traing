import Foundation
import JavaScriptCore

protocol RewardStrategy {
    /// Calculate immediate reward for an action
    /// - Parameters:
    ///   - agentId: True for Agent 1, False for Agent 2
    ///   - action: The action taken (0-9 for cards, 10 for pass)
    ///   - isPass: Whether the action was a pass
    /// - Returns: The immediate reward for the agent who acted
    func getStepReward(agentId: Bool, action: Int, isPass: Bool) -> Float
    
    /// Calculate reward at the end of a round
    /// - Parameters:
    ///   - roundScore1: Score of Agent 1 in this round
    ///   - roundScore2: Score of Agent 2 in this round
    /// - Returns: Tuple of (Agent 1 Reward, Agent 2 Reward)
    func getRoundEndReward(roundScore1: Int, roundScore2: Int) -> (Float, Float)
    
    /// Calculate reward at the end of the game
    /// - Parameters:
    ///   - agent1Wins: Total rounds won by Agent 1
    ///   - agent2Wins: Total rounds won by Agent 2
    /// - Returns: Tuple of (Agent 1 Reward, Agent 2 Reward)
    func getGameEndReward(agent1Wins: Int, agent2Wins: Int) -> (Float, Float)
}

class DefaultRewardStrategy: RewardStrategy {
    func getStepReward(agentId: Bool, action: Int, isPass: Bool) -> Float {
        if !isPass {
            return 0.2 // Reward for playing a card
        } else {
            return -1.0 // Penalty for passing
        }
    }
    
    func getRoundEndReward(roundScore1: Int, roundScore2: Int) -> (Float, Float) {
        let score_diff = Float(roundScore1 - roundScore2)
        let scaled_diff = score_diff / 55.0
        
        var r1: Float = 0.0
        var r2: Float = 0.0
        
        if roundScore1 > roundScore2 {
            r1 = 1.0 + scaled_diff
            r2 = -1.0 - scaled_diff
        } else if roundScore2 > roundScore1 {
            r1 = -1.0 + scaled_diff
            r2 = 1.0 - scaled_diff
        } else {
            // Draw
            r1 = 0.0
            r2 = 0.0
        }
        return (r1, r2)
    }
    
    func getGameEndReward(agent1Wins: Int, agent2Wins: Int) -> (Float, Float) {
        if agent1Wins > agent2Wins {
            return (5.0, -5.0)
        } else if agent2Wins > agent1Wins {
            return (-5.0, 5.0)
        }
        return (0.0, 0.0)
    }
}

class JSRewardStrategy: RewardStrategy {
    private let context: JSContext
    private let stepRewardFunc: JSValue
    private let roundEndRewardFunc: JSValue
    private let gameEndRewardFunc: JSValue
    
    init(jsCode: String) throws {
        guard let context = JSContext() else {
            throw NSError(domain: "JSRewardStrategy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSContext"])
        }
        self.context = context
        
        // Evaluate the user code
        context.evaluateScript(jsCode)
        
        // Check for required functions
        guard let stepFunc = context.objectForKeyedSubscript("getStepReward"), !stepFunc.isUndefined else {
            throw NSError(domain: "JSRewardStrategy", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing function: getStepReward"])
        }
        guard let roundFunc = context.objectForKeyedSubscript("getRoundEndReward"), !roundFunc.isUndefined else {
            throw NSError(domain: "JSRewardStrategy", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing function: getRoundEndReward"])
        }
        guard let gameFunc = context.objectForKeyedSubscript("getGameEndReward"), !gameFunc.isUndefined else {
            throw NSError(domain: "JSRewardStrategy", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing function: getGameEndReward"])
        }
        
        self.stepRewardFunc = stepFunc
        self.roundEndRewardFunc = roundFunc
        self.gameEndRewardFunc = gameFunc
        
        // Test run to ensure no runtime errors immediately
        if stepFunc.call(withArguments: [true, 0, false])?.isUndefined == true {
            throw NSError(domain: "JSRewardStrategy", code: 5, userInfo: [NSLocalizedDescriptionKey: "getStepReward returned undefined during test"])
        }
    }
    
    func getStepReward(agentId: Bool, action: Int, isPass: Bool) -> Float {
        let result = stepRewardFunc.call(withArguments: [agentId, action, isPass])
        // Convert JSValue to a numeric Swift type safely
        return Float(result?.toDouble() ?? 0.0)
    }
    
    func getRoundEndReward(roundScore1: Int, roundScore2: Int) -> (Float, Float) {
        let result = roundEndRewardFunc.call(withArguments: [roundScore1, roundScore2])
        if let arr = result?.toArray(), arr.count >= 2 {
            let r1 = (arr[0] as? NSNumber)?.floatValue ?? 0.0
            let r2 = (arr[1] as? NSNumber)?.floatValue ?? 0.0
            return (r1, r2)
        }
        return (0.0, 0.0)
    }
    
    func getGameEndReward(agent1Wins: Int, agent2Wins: Int) -> (Float, Float) {
        let result = gameEndRewardFunc.call(withArguments: [agent1Wins, agent2Wins])
        if let arr = result?.toArray(), arr.count >= 2 {
            let r1 = (arr[0] as? NSNumber)?.floatValue ?? 0.0
            let r2 = (arr[1] as? NSNumber)?.floatValue ?? 0.0
            return (r1, r2)
        }
        return (0.0, 0.0)
    }
}
