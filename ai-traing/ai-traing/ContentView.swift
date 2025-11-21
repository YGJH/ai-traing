//
//  ContentView.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

import SwiftUI
import SwiftData



struct SettingsView: View {
    @Binding var isPlayerFirst: Bool
    @Environment(\.dismiss) var dismiss
    
    // PPO Hyperparameters
    @AppStorage("gae_lambda") private var gae_lambda: Double = 0.95
    @AppStorage("value_coef") private var value_coef: Double = 0.5
    @AppStorage("entropy_coef") private var entropy_coef: Double = 0.01
    @AppStorage("learning_rate") private var learning_rate: Double = 0.0003
    @AppStorage("train_epochs") private var train_epochs: Int = 4
    @AppStorage("hidden_size") private var hidden_size: Int = 64
    @AppStorage("hidden_layers") private var hidden_layers: Int = 3
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Game Settings")) {
                    Toggle("Player Goes First (Player is Agent 1)", isOn: $isPlayerFirst)
                }
                
                Section(header: Text("Model Architecture")) {
                    Stepper("Hidden Size: \(hidden_size)", value: $hidden_size, in: 16...256, step: 16)
                    Stepper("Hidden Layers: \(hidden_layers)", value: $hidden_layers, in: 1...10)
                }
                
                Section(header: Text("PPO Hyperparameters")) {
                    VStack(alignment: .leading) {
                        Text("GAE Lambda: \(gae_lambda, specifier: "%.2f")")
                        Slider(value: $gae_lambda, in: 0.8...1.0, step: 0.01)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Value Coef: \(value_coef, specifier: "%.2f")")
                        Slider(value: $value_coef, in: 0.1...1.0, step: 0.1)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Entropy Coef: \(entropy_coef, specifier: "%.3f")")
                        Slider(value: $entropy_coef, in: 0.0...0.1, step: 0.001)
                    }
                    
                    HStack {
                        Text("Learning Rate")
                        Spacer()
                        TextField("LR", value: $learning_rate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    
                    Stepper("Train Epochs: \(train_epochs)", value: $train_epochs, in: 1...20)
                }
                
                Section(footer: Text("If enabled, you play as Agent 1 and go first.\nIf disabled, you play as Agent 2 and AI goes first.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct TrainingView: View {
    @Environment(\.dismiss) var dismiss
    @State private var episodeCount: Int = 100
    @State private var progress: Double = 0
    @State private var isTraining: Bool = false
    @State private var logMessage: String = "Ready to train"
    
    // PPO Hyperparameters (Read-only for training context or passed down)
    @AppStorage("gae_lambda") private var gae_lambda: Double = 0.95
    @AppStorage("value_coef") private var value_coef: Double = 0.5
    @AppStorage("entropy_coef") private var entropy_coef: Double = 0.01
    @AppStorage("learning_rate") private var learning_rate: Double = 0.0003
    @AppStorage("train_epochs") private var train_epochs: Int = 4
    @AppStorage("hidden_size") private var hidden_size: Int = 64
    @AppStorage("hidden_layers") private var hidden_layers: Int = 3
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                if isTraining {
                    
                    VStack(spacing: 20) {
                        ProgressView(value: progress, total: Double(episodeCount)) {
                            Text("Training Progress")
                        } currentValueLabel: {
                            Text("\(Int(progress)) / \(episodeCount) Episodes")
                        }
                        .progressViewStyle(.linear)
                        .padding()
                        
                        Text(logMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("Self-Play Training")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Stepper("Episodes: \(episodeCount)", value: $episodeCount, in: 10...10000, step: 10)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        Button {
                            startTraining()
                        } label: {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text("Start Training")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Agent Training")
            .toolbar {
                if !isTraining {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(isTraining)
        }
    }
    
    func startTraining() {
        isTraining = true
        progress = 0
        logMessage = "Initializing Environment..."
        
        Task.detached(priority: .userInitiated) {
            // Initialize Environment and Agent
            let env = AIEnv()
            let agent = PPOAgent(
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
                agent_id: true, // Train as Agent 1
                turn: 0,
                env: env
            )
            
            await MainActor.run {
                logMessage = "Training Started..."
            }
            
            await agent.run(num_episodes: episodeCount) { completed in
                Task { @MainActor in
                    progress = Double(completed)
                    if completed % 10 == 0 {
                        logMessage = "Completed \(completed) episodes..."
                    }
                }
            }
            
            await MainActor.run {
                isTraining = false
                logMessage = "Training Complete!"
                dismiss()
            }
        }
    }
}

struct ContentView: View {

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isPlayerFirst") private var isPlayerFirst = true
    @State private var showSettings = false
    @State private var showTraining = false
    
    let startWords = [
        "這是一個跟你的agent訓練的遊戲",
        "你跟他玩得越久, 他就會訓練的越好"
    ]
    @State private var word = ""
    @State private var currentWordIndex: Int = 0
    @State private var showGame: Bool = false
    
    var body: some View {
        ZStack {
            // Global Background - Dark Theme
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if !hasCompletedOnboarding {
                onboardingView
            } else {
                mainMenuView
            }
        }
        .animation(.spring, value: hasCompletedOnboarding)
        .sheet(isPresented: $showSettings) {
            SettingsView(isPlayerFirst: $isPlayerFirst)
        }
        .sheet(isPresented: $showTraining) {
            TrainingView()
        }
    }
    
    // MARK: - Subviews
    
    var onboardingView: some View {
        VStack {
            Spacer()
            Text(word)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding()
                .shadow(color: .blue.opacity(0.5), radius: 10)
                .animation(.easeInOut, value: word)
            
            Spacer()
            
            if word == "請按下開始" {
                Button {
                    hasCompletedOnboarding = true
                } label: {
                    HStack {
                        Text("開始")
                            .font(.title3.bold())
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 15)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    )
                    .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .task(id: hasCompletedOnboarding) {
            guard !hasCompletedOnboarding else { return }
            if !startWords.isEmpty {
                for i in 0..<startWords.count {
                    currentWordIndex = i
                    withAnimation {
                        word = startWords[i]
                    }
                    if i < startWords.count {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                    }
                }
            }
            withAnimation {
                word = "請按下開始"
            }
        }
    }
    
    var mainMenuView: some View {
        ZStack {
            if showGame {
                GameView(onBack: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showGame = false
                    }
                }, isPlayerFirst: isPlayerFirst)
                .transition(.move(edge: .trailing))
                .zIndex(1)
            } else {
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Title Section
                    VStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 120, height: 120)
                                .blur(radius: 10)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 70))
                                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .cyan.opacity(0.5), radius: 10)
                        }
                        
                        Text("AI Card Trainer")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 5)
                    }
                    .padding(.bottom, 20)
                    
                    // Menu Buttons
                    VStack(spacing: 20) {
                        MenuButton(title: "Start New Game", icon: "play.fill", color: .blue) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showGame = true
                            }
                        }
                        
                        MenuButton(title: "Train Agent", icon: "brain", color: .purple) {
                            showTraining = true
                        }
                        
                        MenuButton(title: "Settings", icon: "gearshape.fill", color: .gray) {
                            showSettings = true
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    Text("Powered by PPO & Swift")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 30)
                    .foregroundStyle(color.gradient)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .opacity(0.5)
            }
            .foregroundColor(.white)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinearGradient(colors: [color.opacity(0.5), color.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    ContentView()
}
