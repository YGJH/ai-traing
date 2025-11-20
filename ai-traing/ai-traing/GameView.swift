//
//  GameView.swift
//  ai-traing
//
//  Created by user20 on 2025/11/20.
//

import SwiftUI

struct Card: View {
    @Binding var isUsed: Bool
    let xOffset: CGFloat
    let yOffset: CGFloat
    let number: Int
    
    let width: CGFloat = 80
    let height: CGFloat = 130
    let thick: CGFloat = 4
    let rotate: Double

    init(isUsed: Binding<Bool>, xOffset: CGFloat, yOffset: CGFloat, number: Int, rotate: Double = 0.1) {
        self._isUsed = isUsed
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.number = number
        self.rotate = rotate
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(isUsed ? Color.blue.opacity(1) : Color.white.opacity(0))
                .frame(width: width, height: height)
                .overlay(
                    Text(isUsed ? "" : "Used")
                        .font(.caption)
                        .foregroundStyle(.white)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .rotationEffect(.degrees(rotate))
                .offset(x: xOffset, y: yOffset)
                .overlay {
                    Text("\(number)")
                        .font(Font.largeTitle.bold())
                        .foregroundStyle(Color.white)
                        .offset(x: xOffset, y: yOffset)
                }
                .zIndex(1)
            
            
            RoundedRectangle(cornerRadius: 20)
                .fill(isUsed ? Color.yellow.opacity(0.6) : Color.white.opacity(0))
                .frame(width: width+thick , height: height + thick)
                .overlay(
                    Text(isUsed ? "USED" : "")
                        .font(.caption)
                        .foregroundStyle(.white)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .rotationEffect(.degrees(rotate))
                .offset(x: xOffset, y: yOffset)

        }
    }
}

struct GameView: View {
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
    let agent_id = false;
    @State var  agent_thinking = false;
    // Alert state
    @State private var showAlert = false
    @State private var alertTitle: String = "Not allowed"
    @State private var alertMessage: String = "You cannot output card in this turn."
    
    // Lock UI during AI turn
    @State private var isProcessingTurn = false
    
    func handlePlayerMove(action: Int) {
        guard !isProcessingTurn else { return }
        
        print("👤 Player move: \(action)")
        // 1. Player executes step
        let (_, _, _, _, _, _, finished) = gameEnv.step(agent_id: agent_id, action: action)
        
        if finished {
            print("🏁 Game Over after Player move")
            return
        }
        
        // 2. Trigger AI Turn
        runAITurn()
    }
    
    func runAITurn() {
        isProcessingTurn = true
        agent_thinking = true
        
        Task {
            // Delay for UX
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            if let agent = agent {
                // AI executes step internally
                let (aiAction, finished) = agent.step_one()
                print("🤖 AI executed action: \(aiAction)")
                
                await MainActor.run {
                    agent_thinking = false
                    isProcessingTurn = false
                    if finished {
                        print("🏁 Game Over after AI move")
                    }
                }
            } else {
                await MainActor.run {
                    isProcessingTurn = false
                    agent_thinking = false
                }
            }
        }
    }
    
    var body: some View {
            ZStack(alignment: .topTrailing) {
                Color.white.ignoresSafeArea()

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
                                guard i < gameEnv.obs_agent2.count else { return false }
                                return gameEnv.obs_agent2[i] == 1  // 1 = unused (show blue), 0 = used (transparent)
                            },
                            set: { newValue in
                                guard i < gameEnv.obs_agent2.count else { return }
                                gameEnv.obs_agent2[i] = newValue ? 1 : 0
                            }
                        )
                        
                        ZStack {
                            Card(isUsed: isUsedBinding, xOffset: x, yOffset: y, number: i + 1, rotate: r)
                            
                            // Invisible overlay for tap detection
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .frame(width: 100, height: 150)
                                .offset(x: x, y: y)
                                .onTapGesture {
                                    if isProcessingTurn { return }
                                    
                                    print("🔥 Card \(i+1) tapped! Current value: \(gameEnv.obs_agent2[i])")
                                    
                                    if gameEnv.obs_agent2[i] == 0 {
                                        print("❌ Card \(i+1) already used")
                                    }
                                    else if self.already_pass {
                                        alertTitle = "Not allowed"
                                        alertMessage = "You cannot output card in this turn."
                                        showAlert = true
                                    }
                                    else if gameEnv.obs_agent2[i] == 1 {
                                        withAnimation(.easeInOut) {
                                            handlePlayerMove(action: i)
                                        }
                                    }
                                }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Button {
                    if isProcessingTurn { return }
                    print("🔘 Pass button tapped")
                    already_pass = true
                    handlePlayerMove(action: 10) // 10 is Pass
                } label: {
                    Text("Pass")
                }
                .buttonStyle(.borderedProminent)
                .padding(30)
                .zIndex(100)
                .disabled(isProcessingTurn) // Disable button when AI is thinking
                
                if agent_thinking {
                    ProgressView("AI Thinking...")
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(10)
                        .zIndex(200)
                }
            }
            .onAppear {
                if agent == nil {
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
    }
}

#Preview {
    GameView()
}
