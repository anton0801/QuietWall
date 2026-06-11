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

struct SplashView: View {
    let onFinish: () -> Void

    // Loop teardown
    @State private var isVisible = true

    // Staged reveals
    @State private var showGlow = false
    @State private var bandGrow: CGFloat = 0
    @State private var showLogo = false
    @State private var exiting = false

    // Looping layers
    @State private var wavePhase: CGFloat = 0
    @State private var glowShift = false
    @State private var logoPulse = false

    // Single coordinator timer
    @State private var timer: Timer?
    @State private var elapsed: Double = 0

    private let bandColors: [Color] = [
        Theme.accent, Theme.info, Theme.success, Theme.highlight, Theme.wave, Theme.accent
    ]
    private let amps: [CGFloat] = [1.0, 0.82, 0.58, 0.36, 0.18, 0.08, 0.03]

    var body: some View {
        ZStack {
            // ---- Layer 1: gradient + drifting glow ----
            Theme.background.ignoresSafeArea()

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

            // ---- Layer 3: logo + title ----
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Theme.accent, lineWidth: 3)
                        .frame(width: 96, height: 96)
                        .shadow(color: Theme.violetGlow, radius: logoPulse ? 18 : 8)
                    Circle()
                        .fill(Theme.accent.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "waveform")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(Theme.highlight)
                }
                .scaleEffect(showLogo ? (exiting ? 1.6 : (logoPulse ? 1.03 : 1.0)) : 0.4)
                .opacity(showLogo ? (exiting ? 0 : 1) : 0)

                VStack(spacing: 6) {
                    Text("QUIET WALL")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .tracking(3)
                    Text("Build the wall that keeps it quiet.")
                        .font(Theme.caption(13))
                        .foregroundColor(Theme.textSecondary)
                }
                .opacity(showLogo ? (exiting ? 0 : 1) : 0)
                .offset(y: showLogo ? 0 : 20)
            }
            .offset(y: 150)
        }
        .onAppear { start() }
        .onDisappear { teardown() }
    }

    // MARK: - Animation control

    private func start() {
        isVisible = true
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { glowShift = true }
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) { wavePhase = .pi * 2 }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { logoPulse = true }

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
        if elapsed >= 2.2 && !exiting {
            withAnimation(.easeIn(duration: 0.5)) { exiting = true }
        }
        if elapsed >= 2.75 {
            timer?.invalidate(); timer = nil
            onFinish()
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
}
