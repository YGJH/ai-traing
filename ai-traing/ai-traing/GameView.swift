//
//  GameView.swift
//  ai-traing
//
//  Created by user20 on 2025/11/20.
//

import SwiftUI

struct Card: View {
    @Binding var isVisible: Bool
    let xOffset: CGFloat
    let yOffset: CGFloat
    let number: Int
    let rotate: Double

    init(isUsed: Binding<Bool>, xOffset: CGFloat, yOffset: CGFloat, number: Int, rotate: Double = 0.1) {
        self._isVisible = isUsed
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.number = number
        self.rotate = rotate
    }

    var body: some View {
        Group {
            if isVisible {
                ZStack {
                    // Card Base
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 4)
                    
                    // Border
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    
                    // Center Number
                    Text("\(number)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Corner Numbers
                    VStack {
                        HStack {
                            Text("\(number)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(number)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(180))
                        }
                    }
                    .padding(6)
                }
                .frame(width: 90, height: 140)
                .rotationEffect(.degrees(rotate))
                .offset(x: xOffset, y: yOffset)
                .transition(.scale.combined(with: .opacity))
            } else {
                // Placeholder for used card
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(.white.opacity(0.15))
                    .frame(width: 90, height: 140)
                    .rotationEffect(.degrees(rotate))
                    .offset(x: xOffset, y: yOffset)
            }
        }
    }
}

struct GameView: View {
    let onBack: () -> Void
    let isPlayerFirst: Bool
    
    init(onBack: @escaping () -> Void, isPlayerFirst: Bool = true) {
        self.onBack = onBack
        self.isPlayerFirst = isPlayerFirst
    }
    
    // 卡片數量
    private let cardCount: Int = 10

    // 每張牌各自的 x/y 偏移（中心為基準）
    private let rotateTion: [Double] = [-20, -10, 0 , 10 , 20, -20, -10, 0 , 10 , 20]

    private let xOffsets: [CGFloat] = [-160, -80, 0 , 80 , 160, -160, -80, 0 , 80 , 160, ]
//    private let yOffsets: [CGFloat] = [-120, -90, -60, -30, 0, 30, 60, 90, 120, 150]
    private let yOffsets: [CGFloat] = [200, 185, 180, 185, 200, 320, 305, 300, 305, 320]
    private let cardSize = CGSize(width: 100, height: 200)

    // 供每張卡片綁定使用狀態（示意用途）
    @State private var cardUsed: [Bool] = Array(repeating: false, count: 10)
    @StateObject var gameEnv = AIEnv()
    
    @State var agent: PPOAgent?
    @State var turn = 0
    @State var already_pass = false;
    
    var agent_id: Bool { isPlayerFirst }
    
    @State var  agent_thinking = false;
    // Alert state
    @State private var showAlert = false
    @State private var alertTitle: String = "Not allowed"
    @State private var alertMessage: String = "You cannot output card in this turn."
    
    // Lock UI during AI turn
    @State private var isProcessingTurn = false
    
    // Game Status Display
    @State private var playerLastMove: String = "-"
    @State private var aiLastMove: String = "-"
    @State private var aiCardNumber: Int? = nil
    
    // Training State
    @State private var isTraining = false
    
    // Game Over Alert
    @State private var showGameOverAlert = false
    @State private var gameOverMessage = ""
    
    func handleGameEnd() {
        print("🏁 Game Finished. Starting Training...")
        isTraining = true
        
        Task {
            // Allow UI to update to show "Training..."
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            if let agent = agent {
                // Run training on background thread to prevent UI freeze
                await withCheckedContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        agent.train()
                        continuation.resume()
                    }
                }
            }
            
            await MainActor.run {
                isTraining = false
                let winner = gameEnv.agent1_wins > gameEnv.agent2_wins ? "AI Wins!" : (gameEnv.agent2_wins > gameEnv.agent1_wins ? "You Win!" : "Draw!")
                
                // Include last round score in the final message
                let lastRoundInfo = "\nRound \(gameEnv.lastRoundNumber) Score: AI \(gameEnv.lastRoundScores.0) - \(gameEnv.lastRoundScores.1) You"
                
                gameOverMessage = "\(winner)\nFinal Score: AI \(gameEnv.agent1_wins) - \(gameEnv.agent2_wins) You\(lastRoundInfo)"
                showGameOverAlert = true
            }
        }
    }
    
    func resetGame() {
        print("🔄 Resetting Game...")
        let _ = gameEnv.reset(agent_id: agent_id)
        already_pass = false
        playerLastMove = "-"
        aiLastMove = "-"
        aiCardNumber = nil
        agent?.hidden = nil
        
        if !agent_id {
             runAITurn()
        }
    }

    func handlePlayerMove(action: Int) {
        guard !isProcessingTurn else { return }
        
        // Update UI
        playerLastMove = (action == 10) ? "Pass" : "\(action + 1)"
        
        print("👤 Player move: \(action)")
        // 1. Player executes step
        // Return signature: (obs1, obs2, ag1Passed, ag2Passed, turn, rewards, finished)
        let (_, _, ag1Passed, ag2Passed, _, _, finished) = gameEnv.step(agent_id: agent_id, action: action)
        
        // Update Player's pass state based on who the player is
        already_pass = agent_id ? ag1Passed : ag2Passed
        
        if finished {
            print("🏁 Game Over after Player move")
            handleGameEnd()
            return
        }
        
        // Check if AI has passed. If so, Player continues (AI cannot move).
        let aiPassed = agent_id ? ag2Passed : ag1Passed
        if aiPassed {
            print("🤖 AI has passed. Player continues.")
            return
        }
        
        // 2. Trigger AI Turn
        runAITurn()
    }
    
    func runAITurn() {
        isProcessingTurn = true
        agent_thinking = true
        
        // 使用 Task { @MainActor in ... } 確保在主執行緒執行
        Task { @MainActor in
            // Check if AI has already passed
            let (_, _, ag1Passed, ag2Passed, _, _, _) = gameEnv.get_obs()
            let aiPassed = agent_id ? ag2Passed : ag1Passed
            let playerPassed = agent_id ? ag1Passed : ag2Passed
            
            if aiPassed {
                print("🤖 AI has already passed. Skipping turn.")
                agent_thinking = false
                isProcessingTurn = false
                return
            }

            // Delay for UX
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            if let agent = agent {
                // AI executes step internally
                let (aiAction, finished) = agent.step_one()
                
                // Update UI
                aiLastMove = (aiAction == 10) ? "Pass" : "\(aiAction + 1)"
                
                if aiAction < 10 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        aiCardNumber = aiAction + 1
                    }
                } else {
                    withAnimation {
                        aiCardNumber = nil
                    }
                }
                
                print("🤖 AI executed action: \(aiAction)")
                
                // Sync state after AI move
                let (_, _, newAg1Passed, newAg2Passed, _, _, _) = gameEnv.get_obs()
                
                // Update Player's pass state (in case round reset or something changed)
                already_pass = agent_id ? newAg1Passed : newAg2Passed
                
                let currentPlayerPassed = agent_id ? newAg1Passed : newAg2Passed
                
                if finished {
                    print("🏁 Game Over after AI move")
                    agent_thinking = false
                    isProcessingTurn = false
                    handleGameEnd()
                } else {
                    // If Player has passed, AI continues playing automatically
                    if currentPlayerPassed {
                        print("🔄 Player passed, AI continues...")
                        runAITurn() // Recursive call for next AI turn
                    } else {
                        agent_thinking = false
                        isProcessingTurn = false
                    }
                }
            } else {
                isProcessingTurn = false
                agent_thinking = false
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.05, green: 0.3, blue: 0.15), Color(red: 0.0, green: 0.15, blue: 0.05)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // AI Card Display
            if let aiCard = aiCardNumber {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Card(isUsed: .constant(true), xOffset: 0, yOffset: 0, number: aiCard, rotate: 0)
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                .zIndex(60)
            }
            
            ZStack {
                ForEach(Array(0..<cardCount), id: \.self) { i in
                    // 安全防護：避免陣列越界
                    let x = i < xOffsets.count ? xOffsets[i] : 0
                    let y = i < yOffsets.count ? yOffsets[i] : 0
                    let r = i < rotateTion.count ? rotateTion[i] : 0
                    
                    // Map Float (0/1) to Bool binding:
                    // Treat 0 as "used" (true), 1 as "not used" (false)
                    let isUsedBinding = Binding<Bool>(
                        get: {
                            let obs = self.agent_id ? gameEnv.obs_agent1 : gameEnv.obs_agent2
                            guard i < obs.count else { return false }
                            return obs[i] == 1  // 1 = unused (show blue), 0 = used (transparent)
                        },
                        set: { newValue in
                            if self.agent_id {
                                guard i < gameEnv.obs_agent1.count else { return }
                                gameEnv.obs_agent1[i] = newValue ? 1 : 0
                            } else {
                                guard i < gameEnv.obs_agent2.count else { return }
                                gameEnv.obs_agent2[i] = newValue ? 1 : 0
                            }
                        }
                    )
                    
                    ZStack {
                        Card(isUsed: isUsedBinding, xOffset: x, yOffset: y, number: i + 1, rotate: r)
                        
                        // Invisible overlay for tap detection
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: 90, height: 140) // Match new card size
                            .offset(x: x, y: y)
                            .onTapGesture {
                                if isProcessingTurn { return }
                                
                                let currentVal = self.agent_id ? gameEnv.obs_agent1[i] : gameEnv.obs_agent2[i]
                                print("🔥 Card \(i+1) tapped! Current value: \(currentVal)")
                                
                                if currentVal == 0 {
                                    print("❌ Card \(i+1) already used")
                                }
                                else if self.already_pass {
                                    alertTitle = "Not allowed"
                                    alertMessage = "You cannot output card in this turn."
                                    showAlert = true
                                }
                                else if currentVal == 1 {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        handlePlayerMove(action: i)
                                    }
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Top UI Layer: Buttons & Status Board
            VStack(spacing: 0) {
                // Header Area with Gradient Background
                VStack(spacing: 12) {
                    // Row 1: Navigation & Round Info
                    HStack {
                        // Back Button
                        Button {
                            print("🔙 Back button tapped")
                            onBack()
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        
                        Spacer()
                        
                        // Round Info
                        HStack(spacing: 6) {
                            Image(systemName: "flag.checkered.2.crossed")
                                .foregroundColor(.yellow)
                                .font(.system(size: 16))
                            Text("Round \(gameEnv.round) / 3")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(20)
                        
                        Spacer()
                        
                        // Pass Button
                        Button {
                            if isProcessingTurn { return }
                            print("🔘 Pass button tapped")
                            already_pass = true
                            handlePlayerMove(action: 10) // 10 is Pass
                        } label: {
                            Text("PASS")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(1)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isProcessingTurn ? Color.gray : Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                                .shadow(radius: 2)
                        }
                        .disabled(isProcessingTurn)
                    }
                    
                    // Row 2: Stats & History
                    HStack(alignment: .top, spacing: 16) {
                        // AI Stats (Left)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("🤖 AI")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.9))
                                Text("(\(gameEnv.agent1_wins) Wins)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text("Sum: \(gameEnv.agent1_round_cards.reduce(0, +))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(gameEnv.agent1_round_cards, id: \.self) { card in
                                        Text("\(card)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.black)
                                            .frame(width: 20, height: 28)
                                            .background(Color.white.opacity(0.9))
                                            .cornerRadius(3)
                                    }
                                }
                            }
                            .frame(height: 28)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Divider
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 50)
                        
                        // Player Stats (Right)
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack {
                                Text("(\(gameEnv.agent2_wins) Wins)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("You 👤")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Text("Sum: \(gameEnv.agent2_round_cards.reduce(0, +))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach(gameEnv.agent2_round_cards, id: \.self) { card in
                                        Text("\(card)")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.black)
                                            .frame(width: 20, height: 28)
                                            .background(Color.white.opacity(0.9))
                                            .cornerRadius(3)
                                    }
                                }
                            }
                            .frame(height: 28)
                            .environment(\.layoutDirection, .rightToLeft) // Scroll from right
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .padding(.top, 60) // Add padding for status bar manually if not ignoring safe area, or use safe area inset
                .background(
                    LinearGradient(colors: [Color.black.opacity(0.8), Color.black.opacity(0.0)], startPoint: .top, endPoint: .bottom)
                        .ignoresSafeArea()
                )
                
                Spacer()
            }
            .zIndex(50)
            
            if agent_thinking {
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("AI Thinking...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)
                }
                .padding(30)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .zIndex(200)
            }
            
            if isTraining {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2.0)
                            .tint(.white)
                        Text("Training Model...")
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                        Text("Learning from this match")
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(50)
                    .background(.ultraThinMaterial)
                    .cornerRadius(25)
                    .shadow(radius: 20)
                }
                .zIndex(300)
            }
        }
        .onAppear {
                if agent == nil {
                    print("aaa")
                    agent = PPOAgent(
                        action_dim: 11,
                        hidden_size: 64,
                        gamma: 0.95,
                        gae_lambda: 0.95,
                        clip_coef: 0.2,
                        value_coef: 0.5,
                        entropy_coef: 0.01,
                        lr: 3e-4,
                        train_epochs: 4,
                        max_grad_norm: 0.5,
                        agent_id: ((agent_id) ? false : true),
                        turn: 0,
                        env: gameEnv
                    )
//
                    // Check who goes first
                    // If agent_id (Player) is true, Player goes first.
                    // If agent_id (Player) is false, AI goes first.
                    if !agent_id {
                        print("🤖 AI goes first!")
                        runAITurn()
                        
                    } else {
                        print("👤 Player goes first!")
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Round \(gameEnv.lastRoundNumber) Result", isPresented: $gameEnv.showRoundResult) {
                Button("Next Round", role: .cancel) { 
                    // If we are entering Round 3, trigger Auto Showdown
                    if gameEnv.round == 3 {
                        gameEnv.resolveShowdown()
                        handleGameEnd()
                    }
                }
            } message: {
                Text("AI: \(gameEnv.lastRoundScores.0) - You: \(gameEnv.lastRoundScores.1)")
            }
            .alert("Game Over", isPresented: $showGameOverAlert) {
                Button("Play Again", role: .cancel) {
                    resetGame()
                }
            } message: {
                Text(gameOverMessage)
            }
    }
}

#Preview {
    GameView(onBack: {
        print("Back tapped in Preview")
    })
}
