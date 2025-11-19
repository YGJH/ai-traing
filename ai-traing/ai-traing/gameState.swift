//
//  gameState.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

struct GameStep {
    /// 對手目前手牌數（0~10）
    let opponentCardCount: Int
    
    /// 我方 10 張牌目前是否還在手上：1 = 還在, 0 = 已打出
    /// 例如 [1,1,0,1,0,1,1,1,1,0]
    let myCardsAlive: [Int]
    
    /// 已經打輸掉（失去）的點數總和
    let lostPointsSum: Int
    
    /// 對手 10 張牌中，哪些「已經知道被打出去了」：1 = 已打出, 0 = 未知/還在
    let opponentCardsRevealed: [Int]
    
    let thinking_time: Double
}
