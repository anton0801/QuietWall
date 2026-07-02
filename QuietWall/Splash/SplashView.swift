//
//  SplashView.swift
//  QuietWall
//
//  Thematic launch animation: a sound wave travels through a stack of wall
//  layers and visibly attenuates. Three+ simultaneously animated layers:
//  (1) background gradient/glow shift, (2) the wall section draws in while the
//  wave pulses through it (looping), (3) the logo + title spring entrance, with
//  a designed scale-up/fade exit. A single coordinator timer drives the staged
//  sequence; every looping animation is torn down in onDisappear. iOS 14 safe.
//

import SwiftUI
import Combine
import Network

struct SplashView: View {
    
    @StateObject private var mix = Mix()

    // Loop teardown
    @State private var isVisible = true

    // Staged reveals
    @State private var showGlow = false
    @State private var bandGrow: CGFloat = 0
    @State private var showLogo = false
    @State private var networkMonitor = NWPathMonitor()
    @State private var exiting = false

    // Looping layers
    @State private var wavePhase: CGFloat = 0
    @State private var glowShift = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var logoPulse = false

    // Single coordinator timer
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    private let bandColors: [Color] = [
        Theme.accent, Theme.info, Theme.success, Theme.highlight, Theme.wave, Theme.accent
    ]
    private let amps: [CGFloat] = [1.0, 0.82, 0.58, 0.36, 0.18, 0.08, 0.03]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    // ---- Layer 1: gradient + drifting glow ----
                    Color.black.ignoresSafeArea()
                    
                    Image(geometry.size.width > geometry.size.height ? "quit_wall_guardsl" : "quit_wall_guards")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                        .opacity(0.45)
                        .blur(radius: 4.5)

                    Circle()
                        .fill(Theme.violetGlow)
                        .frame(width: 360, height: 360)
                        .blur(radius: 100)
                        .offset(x: glowShift ? 110 : -110, y: glowShift ? -180 : -120)
                        .opacity(showGlow ? 1 : 0)

                    Circle()
                        .fill(Theme.waveGlow)
                        .frame(width: 280, height: 280)
                        .blur(radius: 90)
                        .offset(x: glowShift ? -120 : 120, y: glowShift ? 220 : 160)
                        .opacity(showGlow ? 1 : 0)
                    
                    NavigationLink(
                        destination: ChamberView().navigationBarHidden(true),
                        isActive: $mix.navigateToWeb
                    ) { EmptyView() }

                    // ---- Layer 2: wall section + travelling wave ----
                    VStack(spacing: 14) {
                        ZStack {
                            // wall bands grow in
                            HStack(spacing: 3) {
                                ForEach(0..<bandColors.count, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(bandColors[i].opacity(0.28))
                                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(bandColors[i].opacity(0.5), lineWidth: 1))
                                        .frame(width: 26, height: 120 * bandGrow)
                                }
                            }

                            // attenuating wave (looping)
                            AttenuatingWave(amps: amps, phase: wavePhase, maxAmplitude: 40)
                                .stroke(Theme.waveGradient, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                                .frame(width: CGFloat(bandColors.count) * 29, height: 120)
                                .shadow(color: Theme.waveGlow, radius: 8)
                                .opacity(bandGrow)
                            
                        }
                        .scaleEffect(exiting ? 1.7 : 1)
                        .opacity(exiting ? 0 : 1)
                    }
                    
                    NavigationLink(
                        destination: RootView().navigationBarBackButtonHidden(true),
                        isActive: $mix.navigateToMain
                    ) { EmptyView() }

                    // ---- Layer 3: logo + title ----
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 3)
                                .frame(width: 96, height: 96)
                                .shadow(color: Theme.violetGlow, radius: logoPulse ? 18 : 8)
                            Circle()
                                .fill(.white.opacity(0.12))
                                .frame(width: 88, height: 88)
                            Image(systemName: "hammer")
                                .font(.system(size: 38))
                                .foregroundColor(.white)
                        }
                        .scaleEffect(showLogo ? (exiting ? 1.6 : (logoPulse ? 1.03 : 1.0)) : 0.4)
                        .opacity(showLogo ? (exiting ? 0 : 1) : 0)

                        VStack(spacing: 6) {
                            Text("QUIET WALL")
                                .font(.system(size: 30, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .tracking(3)
                        }
                        .opacity(showLogo ? (exiting ? 0 : 1) : 0)
                        .offset(y: showLogo ? 0 : 20)
                    }
                    .offset(y: 150)
                }
                .onAppear { start() }
                .fullScreenCover(isPresented: $mix.showOfflineView) {
                    OfflineRoost()
                }
                .onDisappear { teardown() }
                .fullScreenCover(isPresented: $mix.showPermissionPrompt) {
                    ConsentWall(mix: mix)
                }
            }
            .ignoresSafeArea()
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Animation control

    private func start() {
        NotificationCenter.default.publisher(for: .padsIn)
            .compactMap { $0.userInfo?["conversionData"] as? [String: Any] }
            .sink { data in
                mix.ingestPads(data)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .tapsIn)
            .compactMap { $0.userInfo?["deeplinksData"] as? [String: Any] }
            .sink { data in
                mix.ingestTaps(data)
            }
            .store(in: &cancellables)
        wireNetworkMonitoring()
        isVisible = true
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowShift = true }
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) { wavePhase = .pi * 2 }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { logoPulse = true }
        
        mix.ignite()
        
        elapsed = 0
        let t = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsed += 0.05
            tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isVisible else { return }
        if elapsed >= 0.1 && !showGlow {
            withAnimation(.easeOut(duration: 0.6)) { showGlow = true }
        }
        if elapsed >= 0.5 && bandGrow == 0 {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { bandGrow = 1 }
        }
        if elapsed >= 1.3 && !showLogo {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { showLogo = true }
        }
    }

    private func teardown() {
        isVisible = false
        timer?.invalidate(); timer = nil
        // reset loop state so no animation leaks into the main app
        glowShift = false
        wavePhase = 0
        logoPulse = false
        showGlow = false
        bandGrow = 0
        showLogo = false
    }
    
    private func wireNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { path in
            Task { @MainActor in
                mix.networkConnectivityChanged(path.status == .satisfied)
            }
        }
        networkMonitor.start(queue: .global(qos: .background))
    }
    
}
