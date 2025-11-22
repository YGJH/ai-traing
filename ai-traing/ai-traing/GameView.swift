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

struct GameOverView: View {
    let winner: String
    let playerWins: Int
    let aiWins: Int
    let playerScore: Int
    let aiScore: Int
    let playerRemaining: Int
    let aiRemaining: Int
    let onPlayAgain: () -> Void
    let onBack: () -> Void
    
    var isPlayerWin: Bool { winner.contains("You") }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 25) {
                // Title
                Text(winner.uppercased())
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isPlayerWin ? [.yellow, .orange] : [.red, .purple],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: isPlayerWin ? .orange.opacity(0.5) : .red.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // Score Board
                VStack(spacing: 15) {
                    Text("Match Result")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 40) {
                        VStack {
                            Text("\(playerWins)")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.cyan)
                            Text("You")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("-")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        
                        VStack {
                            Text("\(aiWins)")
                                .font(.system(size: 50, weight: .bold))
                                .foregroundColor(.pink)
                            Text("AI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // Details
                    HStack(spacing: 30) {
                        VStack(spacing: 5) {
                            Text("Last Round")
                                .font(.caption)
                                .foregroundColor(.gray)
                            VStack(spacing: 2) {
                                Text("You: \(playerScore)")
                                    .foregroundColor(.cyan)
                                Text("AI: \(aiScore)")
                                    .foregroundColor(.pink)
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 40)
                        
                        VStack(spacing: 5) {
                            Text("Remaining")
                                .font(.caption)
                                .foregroundColor(.gray)
                            VStack(spacing: 2) {
                                Text("You: \(playerRemaining)")
                                    .foregroundColor(.cyan)
                                Text("AI: \(aiRemaining)")
                                    .foregroundColor(.pink)
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                    }
                }
                .padding(25)
                .background(Color(UIColor.systemGray6).opacity(0.1))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                // Buttons
                HStack(spacing: 20) {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("Menu")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(minWidth: 120)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(15)
                    }
                    
                    Button(action: onPlayAgain) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Play Again")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(minWidth: 120)
                        .background(
                            LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(15)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
            .padding(.horizontal, 20)
        }
    }
}

struct RoundOverView: View {
    let roundNumber: Int
    let playerScore: Int
    let aiScore: Int
    let onNextRound: () -> Void
    
    var isPlayerWin: Bool { playerScore > aiScore }
    var isDraw: Bool { playerScore == aiScore }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            
            VStack(spacing: 25) {
                Text(isDraw ? "DRAW" : (isPlayerWin ? "YOU WIN" : "AI WINS"))
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isDraw ? [.gray, .white] : (isPlayerWin ? [.yellow, .orange] : [.red, .purple]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: isPlayerWin ? .orange.opacity(0.5) : .red.opacity(0.5), radius: 10, x: 0, y: 5)
                
                Text("Round \(roundNumber)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                
                HStack(spacing: 40) {
                    VStack {
                        Text("\(playerScore)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.cyan)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("-")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    
                    VStack {
                        Text("\(aiScore)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.pink)
                        Text("AI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: onNextRound) {
                    HStack {
                        Text("Next Round")
                        Image(systemName: "arrow.right")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(minWidth: 160)
                    .background(Color.blue)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(30)
            .shadow(radius: 20)
        }
    }
}

struct GameView: View {
    let onBack: () -> Void
    let isPlayerFirst: Bool
    
    init(onBack: @escaping () -> Void, isPlayerFirst: Bool) {
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
    @Environment(AIEnv.self) var gameEnv
    
    @State var agent: PPOAgent?
    @State var turn = 0
    @State var already_pass = false;
    
    var agent_id: Bool { isPlayerFirst }
    
    @State var  agent_thinking = false;
    
    // PPO Settings
    @AppStorage("gae_lambda") private var gae_lambda: Double = 0.95
    @AppStorage("value_coef") private var value_coef: Double = 0.5
    @AppStorage("entropy_coef") private var entropy_coef: Double = 0.01
    @AppStorage("learning_rate") private var learning_rate: Double = 0.0003
    @AppStorage("train_epochs") private var train_epochs: Int = 4
    @AppStorage("hidden_size") private var hidden_size: Int = 64
    @AppStorage("hidden_layers") private var hidden_layers: Int = 3
    
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
    @State private var showAIPassMessage: Bool = false
    
    // Training State
    @State private var isTraining = false
    
    // Game Over Alert
    @State private var showGameOverAlert = false
    @State private var gameOverMessage = ""
    @State private var winnerName = ""
    @State private var finalScorePlayer = 0
    @State private var finalScoreAI = 0
    @State private var lastRoundScorePlayer = 0
    @State private var lastRoundScoreAI = 0
    @State private var remainingCardsPlayer = 0
    @State private var remainingCardsAI = 0
    
    // Timer State
    @State private var timeRemaining = 10
    @State private var timer: Timer?
    
    func startTimer() {
        stopTimer()
        guard !already_pass else { return }
        
        timeRemaining = 10
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    stopTimer()
                    print("⏳ Time's up! Auto-passing.")
                    already_pass = true
                    handlePlayerMove(action: 10)
                }
            }
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func handleGameEnd() {
        stopTimer()
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
                
                // Determine winner based on agent_id (Player's identity)
                // If agent_id is true, Player is Agent 1.
                // If agent_id is false, Player is Agent 2.
                
                let playerWins = agent_id ? (gameEnv.agent1_wins > gameEnv.agent2_wins) : (gameEnv.agent2_wins > gameEnv.agent1_wins)
                let aiWins = agent_id ? (gameEnv.agent2_wins > gameEnv.agent1_wins) : (gameEnv.agent1_wins > gameEnv.agent2_wins)
                
                if playerWins {
                    winnerName = "You Win!"
                    SoundManager.shared.playSound(named: "victory")
                } else if aiWins {
                    winnerName = "AI Wins!"
                    SoundManager.shared.playSound(named: "loss")
                } else {
                    winnerName = "Draw!"
                    SoundManager.shared.playSound(named: "loss") // Or maybe a draw sound if available, defaulting to loss or victory or nothing
                }
                
                finalScorePlayer = agent_id ? gameEnv.agent1_wins : gameEnv.agent2_wins
                finalScoreAI = agent_id ? gameEnv.agent2_wins : gameEnv.agent1_wins
                
                lastRoundScorePlayer = agent_id ? gameEnv.lastRoundScores.0 : gameEnv.lastRoundScores.1
                lastRoundScoreAI = agent_id ? gameEnv.lastRoundScores.1 : gameEnv.lastRoundScores.0
                
                // Calculate remaining cards sum
                let playerObs = agent_id ? gameEnv.obs_agent1 : gameEnv.obs_agent2
                let aiObs = agent_id ? gameEnv.obs_agent2 : gameEnv.obs_agent1
                
                func sumRemaining(_ obs: [Float]) -> Int {
                    var sum = 0
                    for i in 0..<obs.count {
                        if obs[i] == 1.0 { sum += (i + 1) }
                    }
                    return sum
                }
                
                remainingCardsPlayer = sumRemaining(playerObs)
                remainingCardsAI = sumRemaining(aiObs)
                
                showGameOverAlert = true
            }
        }
    }
    
    func resetGame() {
        print("🔄 Resetting Game...")
        stopTimer()
        let _ = gameEnv.reset(agent_id: agent_id)
        already_pass = false
        playerLastMove = "-"
        aiLastMove = "-"
        aiCardNumber = nil
        agent?.hidden = nil
        
        if !agent_id {
             runAITurn()
        } else {
             startTimer()
        }
    }

    func handlePlayerMove(action: Int) {
        guard !isProcessingTurn else { return }
        stopTimer()
        
        // Play sound for card placement (if not passing)
        if action < 10 {
            SoundManager.shared.playSound(named: "putcard")
        }
        
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
            startTimer()
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
                let (aiAction, finished, _) = agent.step_one(deterministic: true)
                
                // Play sound for AI card placement
                if aiAction < 10 {
                    SoundManager.shared.playSound(named: "putcard")
                }
                
                // Update UI
                aiLastMove = (aiAction == 10) ? "Pass" : "\(aiAction + 1)"
                
                if aiAction < 10 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        aiCardNumber = aiAction + 1
                    }
                } else {
                    // AI passed - show Pass message
                    withAnimation {
                        aiCardNumber = nil
                        showAIPassMessage = true
                    }
                    
                    // Hide Pass message after 2 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        withAnimation {
                            showAIPassMessage = false
                        }
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
                        startTimer()
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
            if let _ = aiCardNumber {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    // Mystery Card (Back of card)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.2, green: 0.2, blue: 0.5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        // Pattern or Border
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        
                        Text("?")
                            .font(.system(size: 60, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .frame(width: 90, height: 140)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                .zIndex(60)
            }
            
            // AI Pass Message Display
            if showAIPassMessage {
                ZStack {
                    // Background blur
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .frame(width: 250, height: 150)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    
                    VStack(spacing: 10) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("PASS")
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("AI Passed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale.combined(with: .opacity))
                .zIndex(65)
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
                            stopTimer()
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
                        
                        // Timer Display
                        if !isProcessingTurn && !already_pass {
                            Text("\(timeRemaining)s")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(timeRemaining <= 3 ? .red : .white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .transition(.scale)
                        }
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
                                Text("(\(agent_id ? gameEnv.agent2_wins : gameEnv.agent1_wins) Wins)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text("Sum: ???")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach((agent_id ? gameEnv.agent2_round_cards : gameEnv.agent1_round_cards), id: \.self) { _ in
                                        Text("?")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .frame(width: 20, height: 28)
                                            .background(Color.white.opacity(0.3))
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
                                Text("(\(agent_id ? gameEnv.agent1_wins : gameEnv.agent2_wins) Wins)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                Text("You 👤")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Text("Sum: \((agent_id ? gameEnv.agent1_round_cards : gameEnv.agent2_round_cards).reduce(0, +))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.cyan)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    ForEach((agent_id ? gameEnv.agent1_round_cards : gameEnv.agent2_round_cards), id: \.self) { card in
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
            
            if showGameOverAlert {
                GameOverView(
                    winner: winnerName,
                    playerWins: finalScorePlayer,
                    aiWins: finalScoreAI,
                    playerScore: lastRoundScorePlayer,
                    aiScore: lastRoundScoreAI,
                    playerRemaining: remainingCardsPlayer,
                    aiRemaining: remainingCardsAI,
                    onPlayAgain: {
                        showGameOverAlert = false
                        resetGame()
                    },
                    onBack: onBack
                )
                .zIndex(400)
            }
            
            if gameEnv.showRoundResult {
                RoundOverView(
                    roundNumber: gameEnv.lastRoundNumber,
                    playerScore: agent_id ? gameEnv.lastRoundScores.0 : gameEnv.lastRoundScores.1,
                    aiScore: agent_id ? gameEnv.lastRoundScores.1 : gameEnv.lastRoundScores.0,
                    onNextRound: {
                        gameEnv.showRoundResult = false
                        if gameEnv.round == 3 {
                            gameEnv.resolveShowdown()
                            handleGameEnd()
                        }
                    }
                )
                .zIndex(350)
            }
        }
        .onAppear {
                print("🎮 GameView appeared. isPlayerFirst: \(isPlayerFirst), agent_id: \(agent_id)")
                // Reset environment for new game session since it's injected from environment
                let _ = gameEnv.reset(agent_id: agent_id)
                
                if agent == nil {
                    print("aaa")
                    agent = PPOAgent(
                        action_dim: 11,
                        hidden_size: hidden_size,
                        hidden_layers: hidden_layers,
                        gamma: 0.95,
                        gae_lambda: Float(gae_lambda),
                        clip_coef: 0.2,
                        value_coef: Float(value_coef),
                        entropy_coef: Float(entropy_coef),
                        lr: learning_rate,
                        train_epochs: train_epochs,
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
                        startTimer()
                    }
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            // Removed standard alert for Round Result in favor of custom view
            // .alert("Round Result", isPresented: $gameEnv.showRoundResult) { ... }
            // Removed standard alert for Game Over in favor of custom view
            // .alert("Game Over", isPresented: $showGameOverAlert) { ... }
    }
}

#Preview {
    GameView(onBack: {
        print("Back tapped in Preview")
    }, isPlayerFirst: true)
}
