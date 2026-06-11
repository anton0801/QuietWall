//
//  AcousticBackground.swift
//  QuietWall
//
//  The reusable acoustic backdrop: deep indigo gradient + faint wall-slice
//  cross-section marks + a soft sound wave + a violet glow. Drawn entirely with
//  Shapes/Paths (no assets, no Canvas). iOS 14 safe.
//

import SwiftUI

// MARK: - Sine sound wave shape

/// A horizontal sine wave whose amplitude can taper across its width (used to
/// show sound energy decaying through the assembly).
struct SoundWave: Shape {
    var amplitude: CGFloat = 16
    var wavelength: CGFloat = 90
    var phase: CGFloat = 0
    /// 1 = constant amplitude, <1 taper toward the trailing edge.
    var trailingScale: CGFloat = 1

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        let step: CGFloat = 2
        var x: CGFloat = 0
        p.move(to: CGPoint(x: 0, y: midY))
        while x <= rect.width {
            let progress = rect.width == 0 ? 0 : x / rect.width
            let localAmp = amplitude * (1 - (1 - trailingScale) * progress)
            let y = midY + sin((x / wavelength) * 2 * .pi + phase) * localAmp
            p.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        return p
    }
}

// MARK: - Wall-slice cross-section marks

/// Faint stacked horizontal bands suggesting a wall assembly seen in section.
struct WallSliceMarks: Shape {
    var bands: Int = 7
    var spacing: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var y: CGFloat = spacing
        var i = 0
        while y <= rect.height && i < bands {
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
            i += 1
        }
        // a couple of vertical fastener ticks
        let xs: [CGFloat] = [rect.width * 0.22, rect.width * 0.55, rect.width * 0.82]
        for x in xs {
            p.move(to: CGPoint(x: x, y: spacing))
            p.addLine(to: CGPoint(x: x, y: min(rect.height, spacing * CGFloat(bands + 1))))
        }
        return p
    }
}

// MARK: - Backdrop view

struct AcousticBackground: View {
    var showWave: Bool = true
    @State private var phase: CGFloat = 0
    @State private var isVisible = true

    var body: some View {
        ZStack {
            Theme.background

            // soft violet glow, top-trailing
            Circle()
                .fill(Theme.violetGlow)
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 120, y: -260)

            // wall-slice section marks, lower portion
            WallSliceMarks(bands: 7, spacing: 24)
                .stroke(Theme.accent.opacity(0.06),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round))
                .frame(height: 200)
                .frame(maxHeight: .infinity, alignment: .bottom)

            if showWave {
                SoundWave(amplitude: 10, wavelength: 120, phase: phase, trailingScale: 0.25)
                    .stroke(Theme.wave.opacity(0.10),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .frame(height: 60)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 90)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            isVisible = true
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
        .onDisappear {
            isVisible = false
            phase = 0
        }
    }
}

/// Convenience modifier so any screen can sit on the acoustic backdrop.
extension View {
    func acousticScreen(showWave: Bool = true) -> some View {
        ZStack {
            AcousticBackground(showWave: showWave)
            self
        }
    }
}
