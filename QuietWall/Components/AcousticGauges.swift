//
//  AcousticGauges.swift
//  QuietWall
//
//  The signature visualizations, all drawn with Shapes/Paths + GeometryReader
//  (no Canvas): a ring index gauge with a target tick, the layer-by-layer
//  attenuating sound wave (cross-section), and the vertical "sandwich" section.
//  iOS 14 safe; looping animations are torn down in onDisappear.
//

import SwiftUI

// MARK: - Ring index gauge (Rw / IIC vs target)

struct IndexGauge: View {
    var value: Double
    var maxScale: Double = 75
    var target: Double
    var label: String          // "Rw" or "IIC"
    var secondary: String      // e.g. "STC 49"
    var tint: Color
    var size: CGFloat = 168
    var lineWidth: CGFloat = 16

    private var frac: CGFloat { CGFloat(min(max(value / maxScale, 0), 1)) }
    private var targetFrac: CGFloat { CGFloat(min(max(target / maxScale, 0), 1)) }
    private var radius: CGFloat { (size - lineWidth) / 2 }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.surfaceAlt, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: frac)
                .stroke(LinearGradient(colors: [tint.opacity(0.7), tint],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.55), radius: 10)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: frac)

            // target tick
            Capsule()
                .fill(Theme.textPrimary)
                .frame(width: 3, height: lineWidth + 8)
                .offset(y: -radius)
                .rotationEffect(.degrees(Double(targetFrac) * 360))

            VStack(spacing: 1) {
                Text("\(Int(value))")
                    .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.textPrimary)
                Text(label).font(Theme.caption(13)).foregroundColor(tint)
                Text(secondary).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
                Text("Target \(Int(target))").font(Theme.caption(10)).foregroundColor(Theme.textDisabled)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Attenuating wave shape

struct AttenuatingWave: Shape {
    /// Amplitude fraction (0...1) at each layer boundary (count = layers + 1).
    var amps: [CGFloat]
    var phase: CGFloat
    var maxAmplitude: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midY = rect.midY
        guard amps.count >= 2 else {
            p.move(to: CGPoint(x: 0, y: midY)); p.addLine(to: CGPoint(x: rect.width, y: midY)); return p
        }
        let n = amps.count - 1
        let segW = rect.width / CGFloat(n)
        let step: CGFloat = 2
        var x: CGFloat = 0
        p.move(to: CGPoint(x: 0, y: midY))
        while x <= rect.width {
            let t = segW > 0 ? x / segW : 0
            let i = min(n - 1, max(0, Int(t)))
            let localT = t - CGFloat(i)
            let amp = (amps[i] + (amps[i + 1] - amps[i]) * localT) * maxAmplitude
            let y = midY + sin(x / 15 + phase) * amp
            p.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        return p
    }
}

// MARK: - Wave cross-section (the marquee visualization)

struct WaveCrossSectionView: View {
    let layers: [Layer]
    let result: AcousticResult
    var height: CGFloat = 150

    @State private var phase: CGFloat = 0
    @State private var isVisible = true

    private var amps: [CGFloat] {
        guard result.rw > 0, !result.attenuationProfile.isEmpty else { return [1, 0.1] }
        var a: [CGFloat] = [1.0]
        for step in result.attenuationProfile {
            a.append(CGFloat(max(0.04, step.remainingDB / result.rw)))
        }
        return a
    }

    private func bandWidth(_ layer: Layer, total: CGFloat, sumT: CGFloat) -> CGFloat {
        let t = max(layer.thicknessMM, 6)   // floor so thin layers stay visible
        return total * (t / sumT)
    }

    var body: some View {
        let sumT = max(1, layers.reduce(CGFloat(0)) { $0 + max($1.thicknessMM, 6) })
        return VStack(spacing: 8) {
            GeometryReader { geo in
                let bandsW = geo.size.width - 34   // leave room for source
                ZStack(alignment: .leading) {
                    // source icon
                    VStack(spacing: 2) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Theme.wave)
                        Text("source").font(.system(size: 8)).foregroundColor(Theme.textDisabled)
                    }
                    .frame(width: 32)

                    // layer bands
                    HStack(spacing: 1.5) {
                        ForEach(layers) { layer in
                            Rectangle()
                                .fill(layer.category.color.opacity(0.32))
                                .overlay(
                                    Rectangle().fill(layer.rigidlyFixed ? Theme.danger.opacity(0.35) : Color.clear)
                                )
                                .frame(width: bandWidth(layer, total: bandsW, sumT: sumT))
                        }
                    }
                    .frame(height: height - 28)
                    .overlay(
                        HStack(spacing: 1.5) {
                            ForEach(layers) { layer in
                                Rectangle().stroke(layer.category.color.opacity(0.5), lineWidth: 1)
                                    .frame(width: bandWidth(layer, total: bandsW, sumT: sumT))
                            }
                        }
                        .frame(height: height - 28)
                    )
                    .padding(.leading, 32)

                    // wave overlays
                    Group {
                        AttenuatingWave(amps: amps, phase: phase, maxAmplitude: (height - 28) * 0.34)
                            .stroke(Theme.wave2.opacity(0.5), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                            .frame(width: bandsW, height: height - 28)
                            .offset(x: 32)
                        AttenuatingWave(amps: amps, phase: phase + 0.6, maxAmplitude: (height - 28) * 0.40)
                            .stroke(Theme.waveGradient, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                            .frame(width: bandsW, height: height - 28)
                            .shadow(color: Theme.waveGlow, radius: 8)
                            .offset(x: 32)
                    }
                }
            }
            .frame(height: height - 28)

            HStack {
                Text("Loud side").font(Theme.caption(10)).foregroundColor(Theme.textSecondary)
                Spacer()
                Text("−\(Int(result.rw)) dB through the wall").font(Theme.caption(10)).foregroundColor(Theme.wave)
                Spacer()
                Text("Quiet side").font(Theme.caption(10)).foregroundColor(Theme.success)
            }
        }
        .frame(height: height)
        .onAppear {
            isVisible = true
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) { phase = .pi * 2 }
        }
        .onDisappear { isVisible = false; phase = 0 }
    }
}

// MARK: - Vertical layer "sandwich" section

struct LayerStackBar: View {
    let layers: [Layer]
    var highlightID: UUID? = nil
    var height: CGFloat = 260

    var body: some View {
        let sumT = max(1, layers.reduce(0.0) { $0 + max($1.thicknessMM, 8) })
        return VStack(spacing: 0) {
            if layers.isEmpty {
                EmptyStateView(systemImage: "square.stack.3d.up.slash",
                               title: "No layers yet",
                               message: "Add a layer to start building the section.")
            } else {
                ForEach(layers) { layer in
                    let frac = max(layer.thicknessMM, 8) / sumT
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(layer.category.color)
                            .frame(width: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(layer.name).font(Theme.caption(12)).foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                            Text(layer.category.displayName).font(.system(size: 9)).foregroundColor(Theme.textSecondary)
                        }
                        Spacer()
                        if layer.rigidlyFixed {
                            Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                                .font(.system(size: 11)).foregroundColor(Theme.danger)
                        }
                        Text("\(Int(layer.thicknessMM))mm").font(Theme.mono(11)).foregroundColor(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: max(28, CGFloat(frac) * height))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(layer.category.color.opacity(highlightID == layer.id ? 0.30 : 0.14))
                    .overlay(
                        Rectangle().stroke(highlightID == layer.id ? layer.category.color : Theme.stroke.opacity(0.5),
                                           lineWidth: highlightID == layer.id ? 2 : 0.5)
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: 1))
    }
}

// MARK: - Status pill (target met / building / weak / bridge)

struct StatusPill: View {
    let severity: WeakSeverity
    var text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: severity.icon).font(.system(size: 11, weight: .bold))
            Text(text).font(Theme.caption(12))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(Capsule().fill(severity.color))
        .shadow(color: severity.color.opacity(0.4), radius: 6, y: 2)
    }
}
