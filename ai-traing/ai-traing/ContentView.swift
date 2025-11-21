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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Game Settings")) {
                    Toggle("Player Goes First (Player is Agent 1)", isOn: $isPlayerFirst)
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

struct ContentView: View {

    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("isPlayerFirst") private var isPlayerFirst = true
    @State private var showSettings = false
    
    let startWords = [
        "這是一個跟你的agent訓練的遊戲",
        "你跟他玩得越久, 他就會訓練的越好"
    ]
    @State private var word = ""
    @State private var currentWordIndex: Int = 0
    @State private var showGame: Bool = false
    
    var body: some View {
        ZStack {
            if !hasCompletedOnboarding {
                ZStack {
                    LinearGradient(colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .ignoresSafeArea(edges: .all)
                    VStack {
                        Spacer()
                        Text(word)
                            .font(.system(size: 20))
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                        Button {
                            hasCompletedOnboarding = true
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 20))
                            Text("開始")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .task(id: hasCompletedOnboarding) {
                    guard !hasCompletedOnboarding else { return }
                    if !startWords.isEmpty {
                        for i in 0..<startWords.count {
                            currentWordIndex = i
                            word = startWords[i]
                            if i < startWords.count - 1 {
                                try? await Task.sleep(nanoseconds: 4_000_000_000)
                            }
                        }
                    }
                    word = "請按下開始"
                }
                .animation(.easeIn, value: currentWordIndex)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.blue, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    if showGame {
                        GameView(onBack: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showGame = false
                            }
                        })
                            .transition(.move(edge: .trailing))
                            .zIndex(1)
                    } else {
                        VStack(spacing: 20) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    showGame = true
                                }
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 20))
                                Text("Start a new game")
                                    .font(.system(size: 20))
                            }
                            .foregroundStyle(Color(.black.withAlphaComponent(0.8)))
                            .buttonStyle(.glass)
                            
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                Text("Settings")
                                    .font(.system(size: 20))
                            }
                            .foregroundStyle(Color(.black.withAlphaComponent(0.8)))
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
        .animation(.spring, value: hasCompletedOnboarding)
        .sheet(isPresented: $showSettings) {
            SettingsView(isPlayerFirst: $isPlayerFirst)
        }
    }
}

#Preview {
    ContentView()
}
