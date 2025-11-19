//
//  ContentView.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

import SwiftUI
import SwiftData


struct ContentView: View {
    
    
    
    var body: some View {
        let history: [GameStep] = [
            GameStep(
                opponentCardCount: 8,
                myCardsAlive:       [1,1,1,1,1,1,1,1,1,1],
                lostPointsSum:      0,
                opponentCardsRevealed: [0,0,0,0,0,0,0,0,0,0]
            ),
            GameStep(
                opponentCardCount: 7,
                myCardsAlive:       [1,1,0,1,1,1,1,1,1,1],
                lostPointsSum:      5,
                opponentCardsRevealed: [0,1,0,0,0,0,0,0,0,0]
            ),
            // ... 一路到現在
        ]

        let lstm = LSTM(hiddenSize: 64, numPlayableCards: 10)
        let (actionIndex, probs) = lstm.predict(history: history)

        if actionIndex == 10 {
            print("AI 決定 pass，分佈：\(probs)")
        } else {
            print("AI 決定出第 \(actionIndex) 張牌，分佈：\(probs)")
        }
    }
    
}

#Preview {
    ContentView()
}
