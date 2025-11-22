//
//  ContentView.swift
//  ai-traing
//
//  Created by user20 on 2025/11/19.
//

import SwiftUI
import SwiftData
import Charts
import Combine
import AVFoundation



struct SettingsView: View {
    @Binding var isPlayerFirst: Bool
    @Environment(\.dismiss) var dismiss
    
    @AppStorage("isSoundEnabled") private var isSoundEnabled = true
    
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
                    Toggle("Enable Sound Effects", isOn: $isSoundEnabled)
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
    @State private var lastReward: String = "0.0"
    @State private var rewardHistory: [RewardPoint] = []
    
    @State private var isAlwaysTraining: Bool = false
    @State private var currentAgent: PPOAgent?
    
    struct RewardPoint: Identifiable {
        let id = UUID()
        let episode: Int
        let reward: Float
    }
    
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
                        if isAlwaysTraining {
                            ProgressView() {
                                Text("Training in Progress (Infinite)")
                            }
                            Text("Episodes Completed: \(Int(rewardHistory.last?.episode ?? 0))")
                                .font(.headline)
                        } else {
                            ProgressView(value: progress, total: Double(episodeCount)) {
                                Text("Training Progress")
                            } currentValueLabel: {
                                Text("\(Int(progress)) / \(episodeCount) Episodes")
                            }
                            .progressViewStyle(.linear)
                        }
//                        .padding()
                        
                        if !rewardHistory.isEmpty {
                            Chart(rewardHistory) { point in
                                LineMark(
                                    x: .value("Episode", point.episode),
                                    y: .value("Reward", point.reward)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                                
                                AreaMark(
                                    x: .value("Episode", point.episode),
                                    y: .value("Reward", point.reward)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                            .frame(height: 200)
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        
                        Text(logMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("Last Reward: \(lastReward)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        Button {
                            logMessage = "Stopping after current episode..."
                            currentAgent?.stop()
                        } label: {
                            Text("Stop Training")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 20) {
                        Text("Self-Play Training")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Toggle("Always Train", isOn: $isAlwaysTraining)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        if !isAlwaysTraining {
                            Stepper("Episodes: \(episodeCount)", value: $episodeCount, in: 10...10000, step: 10)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        Button {
                            startTraining()
                        } label: {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                Text(isAlwaysTraining ? "Start Infinite Training" : "Start Training")
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
        rewardHistory.removeAll()
        logMessage = "Initializing Environment..."
        
        // Capture configuration on MainActor to avoid async access warnings in detached task
        let configHiddenSize = hidden_size
        let configHiddenLayers = hidden_layers
        let configGaeLambda = gae_lambda
        let configValueCoef = value_coef
        let configEntropyCoef = entropy_coef
        let configLearningRate = learning_rate
        let configTrainEpochs = train_epochs
        let configIsAlwaysTraining = isAlwaysTraining
        let configEpisodeCount = episodeCount
        
        Task.detached(priority: .userInitiated) {
            // Initialize Environment and Agent
            // Note: AIEnv might be inferred as MainActor if it imports UI frameworks. 
            // If so, we might need to adjust AIEnv or create it on MainActor.
            // For now, we create it here. If it warns, we might need to refactor AIEnv.
            let env = AIEnv()
            let agent = PPOAgent(
                action_dim: 11,
                hidden_size: configHiddenSize,
                hidden_layers: configHiddenLayers,
                gamma: 0.95,
                gae_lambda: Float(configGaeLambda),
                clip_coef: 0.2,
                value_coef: Float(configValueCoef),
                entropy_coef: Float(configEntropyCoef),
                lr: configLearningRate,
                train_epochs: configTrainEpochs,
                max_grad_norm: 0.5,
                agent_id: true, // Train as Agent 1
                turn: 0,
                env: env
            )
            
            await MainActor.run {
                self.currentAgent = agent
                logMessage = "Training Started..."
            }
            
            let episodesToRun = configIsAlwaysTraining ? -1 : configEpisodeCount
            
            await agent.run(num_episodes: episodesToRun) { completed, reward in
                Task { @MainActor in
                    if !configIsAlwaysTraining {
                        self.progress = Double(completed)
                    } else {
                        // For infinite training, just show count
                        self.progress = Double(completed % 100) // Loop progress bar or just show count
                    }
                    
                    self.lastReward = String(format: "%.2f", reward)
                    self.rewardHistory.append(RewardPoint(episode: completed, reward: reward))
                    
                    // Keep chart clean
                    if self.rewardHistory.count > 100 {
                        self.rewardHistory.removeFirst()
                    }
                    
                    if completed % 10 == 0 {
                        self.logMessage = "Completed \(completed) episodes..."
                    }
                }
            }
            
            await MainActor.run {
                self.isTraining = false
                self.currentAgent = nil
                self.logMessage = "Training Complete!"
                if !configIsAlwaysTraining {
                    self.dismiss()
                }
            }
        }
    }
}

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // Header Image
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                        .padding()
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                        )
                        .padding(.bottom, 10)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        RuleRow(icon: "suit.club.fill", title: "卡牌配置", description: "雙方各自擁有 1 到 10 點的卡牌，共 10 張。")
                        RuleRow(icon: "flag.2.crossed.fill", title: "三回合對決", description: "遊戲共進行三個回合，採三戰兩勝制。")
                        RuleRow(icon: "arrow.triangle.2.circlepath", title: "輪流出牌", description: "雙方輪流出牌累積戰力，直到一方選擇 Pass。")
                        RuleRow(icon: "hand.raised.fill", title: "Pass 機制", description: "一旦選擇 Pass，該回合你將不能再出牌。當雙方都選擇 Pass 時，該回合結束並結算分數。")
                        RuleRow(icon: "trophy.fill", title: "獲勝條件", description: "每回合點數總和高者勝。贏得更多回合者獲得最終勝利。")
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("遊戲說明")
            .toolbar {
                Button("了解") {
                    dismiss()
                }
            }
        }
    }
}

struct RuleRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct HackerTerminalView: View {
    @State private var logs: [String] = []
    // Use a timer to generate logs
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black
            
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 2) {
                    Spacer()
                    ForEach(logs, id: \.self) { log in
                        Text(log)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .lineLimit(1)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottomLeading)
                .padding(10)
            }
        }
        .frame(width: 300, height: 300)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.green.opacity(0.6), lineWidth: 2)
        )
        .shadow(color: .green.opacity(0.3), radius: 20)
        .onReceive(timer) { _ in
            logs.append(generateRandomLog())
            if logs.count > 25 {
                logs.removeFirst()
            }
        }
    }
    
    func generateRandomLog() -> String {
        let commands: [String] = [
            "INITIALIZING_NEURAL_NET...",
            "BYPASSING_FIREWALL...",
            "ACCESS_GRANTED",
            "DOWNLOADING_PACKETS...",
            "DECRYPTING_DATA_STREAM...",
            "OPTIMIZING_WEIGHTS...",
            "PPO_AGENT_ACTIVE",
            "SEARCHING_FOR_VULNERABILITIES...",
            "ROOT_ACCESS: ENABLED",
            "SYSTEM_OVERRIDE: TRUE"
        ]
        
        if Bool.random() {
            return commands.randomElement()!
        } else {
            // Generate random hex/binary
            let chars = "01"
            let len = Int.random(in: 20...40)
            let randomStr = String((0..<len).map { _ in chars.randomElement()! })
            return "0x\(String(Int.random(in: 1000...9999), radix: 16).uppercased()) :: \(randomStr)"
        }
    }
}

struct MatrixRainView: View {
    let matrixChars = Array("0101010101XYZA@#&!<>?:").map { String($0) }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let fontSize: CGFloat = 14
                let columnCount = Int(size.width / fontSize)
                
                for col in 0..<columnCount {
                    // Deterministic random based on column
                    let r = Double(col * 12345 + 6789)
                    let speed = 100.0 + (r.truncatingRemainder(dividingBy: 200.0)) // Speed 100-300
                    let offset = r.truncatingRemainder(dividingBy: 1000.0)
                    
                    // Position
                    let totalHeight = size.height + 300
                    let y = (time * speed + offset).truncatingRemainder(dividingBy: totalHeight) - 150
                    let x = CGFloat(col) * fontSize + fontSize / 2
                    
                    // Stream length
                    let streamLen = 10 + Int(r.truncatingRemainder(dividingBy: 15))
                    
                    for i in 0..<streamLen {
                        let charY = y - CGFloat(i) * fontSize
                        
                        if charY > -fontSize && charY < size.height {
                            // Character selection
                            // Change character periodically
                            let charIndex = Int(time * 2 + Double(i) + Double(col)) % matrixChars.count
                            let char = matrixChars[charIndex]
                            
                            // Color
                            let opacity = max(0, 1.0 - Double(i) / Double(streamLen))
                            let color: Color
                            if i == 0 {
                                color = .white.opacity(opacity)
                            } else {
                                color = .green.opacity(opacity)
                            }
                            
                            context.draw(
                                Text(char)
                                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                    .foregroundColor(color),
                                at: CGPoint(x: x, y: charY)
                            )
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct ContentView: View {

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isPlayerFirst") private var isPlayerFirst = true
    @State private var showSettings = false
    @State private var showTraining = false
    @State private var showHowToPlay = false
    
    let startWords = [
        "這是一個跟你的agent訓練的遊戲",
        "你跟他玩得越久, 他就會訓練的越好"
    ]
    @State private var word = ""
    @State private var currentWordIndex: Int = 0
    @State private var showGame: Bool = false
    @State private var gameEnv = AIEnv()
    
    var body: some View {
        ZStack {
            // Global Background - Dark Theme
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.2), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            MatrixRainView()
                .opacity(0.3)
            
            if !hasCompletedOnboarding {
                onboardingView
            } else {
                mainMenuView
            }
        }
        .environment(gameEnv)
        .animation(.spring, value: hasCompletedOnboarding)
        .simultaneousGesture(
            TapGesture().onEnded {
                SoundManager.shared.playSound()
            }
        )
        .sheet(isPresented: $showSettings) {
            SettingsView(isPlayerFirst: $isPlayerFirst)
        }
        .sheet(isPresented: $showTraining) {
            TrainingView()
        }
        .sheet(isPresented: $showHowToPlay) {
            HowToPlayView()
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
                            HackerTerminalView()
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
                        
                        MenuButton(title: "How to Play", icon: "book.fill", color: .green) {
                            showHowToPlay = true
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

class SoundManager {
    static let shared = SoundManager()
    var player: AVAudioPlayer?

    func playSound(named soundName: String = "soundGlass") {
        let isSoundEnabled = UserDefaults.standard.object(forKey: "isSoundEnabled") as? Bool ?? true
        guard isSoundEnabled else { return }
        
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else {
            print("Sound file \(soundName) not found")
            return
        }
        do {
            // Allow background audio to mix if needed, or just play
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}

#Preview {
    ContentView()
}
