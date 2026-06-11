//
//  OnboardingView.swift
//  QuietWall
//
//  Four interactive onboarding screens, first launch only. Each has a unique
//  scene and gesture: (1) tap-to-burst surface picker, (2) horizontal drag noise
//  selector, (3) scroll-driven parallax depth slider, (4) vertical drag goal
//  dial. Choices are persisted into the AppStore. iOS 14 safe.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    let onComplete: () -> Void

    @State private var page = 0
    @State private var surface: SurfaceType = .wall
    @State private var noise: NoiseType = .airborne
    @State private var limit: Double = 120
    @State private var goal: Goal = .good

    var body: some View {
        ZStack {
            AcousticBackground(showWave: true)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { finish() }
                        .font(Theme.caption(14))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.top, Theme.Space.m)
                }

                TabView(selection: $page) {
                    SurfacePage(surface: $surface).tag(0)
                    NoisePage(noise: $noise).tag(1)
                    LimitPage(limit: $limit).tag(2)
                    GoalPage(goal: $goal, noise: noise).tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i == page ? Theme.accent : Theme.stroke)
                            .frame(width: i == page ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.vertical, 12)

                ActionButton(title: primaryTitle, systemImage: page == 3 ? "square.stack.3d.up.fill" : "arrow.right") {
                    advance()
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, Theme.Space.l)
            }
        }
        .onAppear {
            surface = store.data.defaultSurface
            noise = store.data.defaultNoiseType
            limit = store.data.defaultSpaceLimitMM
            goal = store.data.defaultGoal
        }
    }

    private var primaryTitle: String {
        switch page {
        case 0: return "Set Surface"
        case 1: return "Set Noise"
        case 2: return "Set Limit"
        default: return "Build Layers"
        }
    }

    private func advance() {
        if page < 3 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        store.applyOnboarding(surface: surface, noise: noise, limit: limit, goal: goal)
        onComplete()
    }
}

// MARK: - Page 1: Surface (tap-to-burst)

private struct SurfacePage: View {
    @Binding var surface: SurfaceType
    @State private var bursts: [Burst] = []
    @State private var pulse = false
    struct Burst: Identifiable { let id = UUID(); let angle: Double; var go = false }

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            header("Where is the noise coming through?",
                   "Pick the surface — it sets the layer rules and which index matters.")

            ZStack {
                ForEach(bursts) { b in
                    Circle().fill(Theme.highlight)
                        .frame(width: 8, height: 8)
                        .offset(x: b.go ? CGFloat(cos(b.angle)) * 95 : 0,
                                y: b.go ? CGFloat(sin(b.angle)) * 95 : 0)
                        .opacity(b.go ? 0 : 1)
                }
                Circle()
                    .fill(Theme.accentGradient)
                    .frame(width: 116, height: 116)
                    .scaleEffect(pulse ? 1.05 : 0.97)
                    .shadow(color: Theme.violetGlow, radius: 18)
                    .overlay(Image(systemName: surface.icon)
                        .font(.system(size: 46, weight: .bold)).foregroundColor(.white))
            }
            .frame(height: 130)
            .onTapGesture { burst() }

            VStack(spacing: 10) {
                ForEach(SurfaceType.allCases) { s in
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { surface = s }
                        burst()
                    }) {
                        selectRow(icon: s.icon, title: s.displayName, subtitle: s.blurb, selected: surface == s)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Theme.Space.l)
            Spacer()
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true } }
        .onDisappear { pulse = false; bursts.removeAll() }
    }

    private func burst() {
        bursts = (0..<12).map { Burst(angle: Double($0) / 12 * 2 * .pi) }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.6)) { for i in bursts.indices { bursts[i].go = true } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { bursts.removeAll() }
    }
}

// MARK: - Page 2: Noise type (horizontal drag)

private struct NoisePage: View {
    @Binding var noise: NoiseType
    private let options = NoiseType.allCases

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            header("What kind of noise bothers you?",
                   "Drag the marker. Airborne is rated by Rw, impact by Ln,w.")

            // animated icon for the current choice
            ZStack {
                Circle().fill(Theme.wave.opacity(0.14)).frame(width: 120, height: 120)
                Image(systemName: noise.icon)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Theme.wave)
                    .shadow(color: Theme.waveGlow, radius: 12)
            }
            .frame(height: 130)

            // drag track
            GeometryReader { geo in
                let trackW = geo.size.width - 60
                let seg = trackW / CGFloat(options.count - 1)
                let idx = options.firstIndex(of: noise) ?? 0
                let knobX = 30 + CGFloat(idx) * seg
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.surfaceAlt).frame(height: 10)
                        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                    Capsule().fill(Theme.waveGradient).frame(width: knobX, height: 10)
                    Circle().fill(Theme.wave).frame(width: 34, height: 34)
                        .overlay(Image(systemName: "hand.draw.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white))
                        .shadow(color: Theme.waveGlow, radius: 8, y: 3)
                        .position(x: knobX, y: 5)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                            let clamped = min(max(v.location.x - 30, 0), trackW)
                            let i = Int((clamped / seg).rounded())
                            let newN = options[min(max(i, 0), options.count - 1)]
                            if newN != noise { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { noise = newN } }
                        })
                }
                .frame(height: 40)
                .position(x: geo.size.width / 2, y: 30)
            }
            .frame(height: 60)
            .padding(.horizontal, Theme.Space.l)

            HStack {
                ForEach(options) { o in
                    Text(o.displayName).font(Theme.caption(12))
                        .fontWeight(noise == o ? .bold : .regular)
                        .foregroundColor(noise == o ? Theme.wave : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .onTapGesture { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { noise = o } }
                }
            }
            .padding(.horizontal, Theme.Space.l)

            CardView {
                HStack(spacing: 10) {
                    Image(systemName: noise.icon).foregroundColor(Theme.wave)
                    Text(noise.blurb).font(Theme.body()).foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Space.l)
            Spacer()
        }
    }
}

// MARK: - Page 3: Space limit (scroll-driven parallax + slider)

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct LimitPage: View {
    @Binding var limit: Double
    @State private var offset: CGFloat = 0

    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                // parallax background layers
                SoundWave(amplitude: 18, wavelength: 80, phase: 0, trailingScale: 0.2)
                    .stroke(Theme.wave.opacity(0.18), lineWidth: 2)
                    .frame(height: 60)
                    .offset(y: -offset * 0.4 + 30)
                Image(systemName: "ruler.fill")
                    .font(.system(size: 120, weight: .thin))
                    .foregroundColor(Theme.accent.opacity(0.10))
                    .offset(x: -90, y: -offset * 0.25 + 60)

                VStack(spacing: Theme.Space.l) {
                    GeometryReader { proxy in
                        Color.clear.preference(key: ScrollOffsetKey.self,
                                               value: proxy.frame(in: .named("limitScroll")).minY)
                    }.frame(height: 0)

                    header("How much depth can you give up?",
                           "Scroll to explore — then set the maximum assembly thickness.")
                        .offset(y: offset * 0.12)

                    // live thickness preview
                    CardView {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            HStack {
                                Text("\(Int(limit)) mm").font(Theme.title(34)).foregroundColor(Theme.textPrimary)
                                Spacer()
                                TagChip(text: limitLabel, color: limitColor, filled: true)
                            }
                            // proportional bar
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Theme.surfaceAlt).frame(height: 16)
                                    Capsule().fill(Theme.accentGradient)
                                        .frame(width: g.size.width * CGFloat((limit - 30) / 270), height: 16)
                                }
                            }.frame(height: 16)
                            Slider(value: $limit, in: 30...300, step: 5)
                                .accentColor(Theme.accent)
                            Text("Thin builds favour mass + damping; deeper builds allow a decoupled cavity.")
                                .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)

                    CardView {
                        HStack(spacing: 10) {
                            Image(systemName: "lightbulb.fill").foregroundColor(Theme.warning)
                            Text("A cavity needs ~50mm+ to fit an absorber. Below that, lean on dense boards and damping.")
                                .font(Theme.caption(12)).foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, Theme.Space.l)

                    Spacer(minLength: 50)
                }
                .padding(.top, Theme.Space.l)
            }
        }
        .coordinateSpace(name: "limitScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset = $0 }
    }

    private var limitLabel: String {
        if limit < 60 { return "Tight" } else if limit < 140 { return "Standard" } else { return "Generous" }
    }
    private var limitColor: Color {
        if limit < 60 { return Theme.warning } else if limit < 140 { return Theme.accent } else { return Theme.success }
    }
}

// MARK: - Page 4: Goal (vertical drag dial)

private struct GoalPage: View {
    @Binding var goal: Goal
    let noise: NoiseType
    private let levels = Goal.allCases

    var body: some View {
        VStack(spacing: Theme.Space.l) {
            header("How quiet do you need it?",
                   "Drag the dial up for studio-grade silence. Sets your target index.")

            HStack(spacing: Theme.Space.l) {
                // vertical drag dial
                GeometryReader { geo in
                    let h = geo.size.height
                    let idx = levels.firstIndex(of: goal) ?? 1
                    // index 0 (basic) at bottom, last (studio) at top
                    let knobY = h - 24 - (CGFloat(idx) / CGFloat(levels.count - 1)) * (h - 48)
                    ZStack(alignment: .bottom) {
                        Capsule().fill(Theme.surfaceAlt).frame(width: 12)
                            .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                        Capsule().fill(Theme.accentGradient)
                            .frame(width: 12, height: (CGFloat(idx) / CGFloat(levels.count - 1)) * (h - 48) + 24)
                        Circle().fill(goal.color).frame(width: 40, height: 40)
                            .overlay(Image(systemName: goal.icon).font(.system(size: 16, weight: .bold)).foregroundColor(.white))
                            .shadow(color: goal.color.opacity(0.5), radius: 8)
                            .position(x: 6, y: knobY)
                            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                                let clamped = min(max(v.location.y, 24), h - 24)
                                let frac = 1 - (clamped - 24) / (h - 48)
                                let i = Int((frac * CGFloat(levels.count - 1)).rounded())
                                let newG = levels[min(max(i, 0), levels.count - 1)]
                                if newG != goal { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { goal = newG } }
                            })
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(width: 60, height: 240)

                VStack(spacing: 12) {
                    ForEach(levels.reversed()) { g in
                        Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { goal = g } }) {
                            HStack(spacing: 12) {
                                Image(systemName: g.icon).foregroundColor(goal == g ? .white : g.color).frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(g.displayName).font(Theme.heading(15)).foregroundColor(goal == g ? .white : Theme.textPrimary)
                                    Text("Target \(Int(g.targetIndex(for: noise))) \(noise == .impact ? "IIC" : "Rw")")
                                        .font(Theme.caption(11)).foregroundColor(goal == g ? .white.opacity(0.85) : Theme.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(goal == g ? g.color : Theme.surface))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: goal == g ? 0 : 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, Theme.Space.l)

            CardView {
                HStack(spacing: 10) {
                    Image(systemName: goal.icon).foregroundColor(goal.color)
                    Text(goal.subtitle).font(Theme.body()).foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Theme.Space.l)
            Spacer()
        }
    }
}

// MARK: - Shared header

private func header(_ title: String, _ subtitle: String) -> some View {
    VStack(spacing: 6) {
        Text(title).font(Theme.title(26)).multilineTextAlignment(.center).foregroundColor(Theme.textPrimary)
        Text(subtitle).font(Theme.caption(13)).foregroundColor(Theme.textSecondary).multilineTextAlignment(.center)
    }
    .padding(.horizontal, Theme.Space.l)
    .padding(.top, Theme.Space.m)
}

// MARK: - Shared select row

private func selectRow(icon: String, title: String, subtitle: String, selected: Bool) -> some View {
    HStack(spacing: 12) {
        Image(systemName: icon).foregroundColor(selected ? .white : Theme.accent).frame(width: 26)
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(Theme.heading(15)).foregroundColor(selected ? .white : Theme.textPrimary)
            Text(subtitle).font(Theme.caption(11)).foregroundColor(selected ? .white.opacity(0.85) : Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        if selected { Image(systemName: "checkmark.circle.fill").foregroundColor(.white) }
    }
    .padding(12)
    .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(selected ? Theme.accent : Theme.surface))
    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(Theme.stroke, lineWidth: selected ? 0 : 1))
}
