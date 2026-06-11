//
//  Components.swift
//  QuietWall
//
//  Reusable UI kit: action buttons, cards, chips, stat tiles, segmented control,
//  styled inputs, steppers and the screen scaffold. iOS 14 safe (value-form
//  overlay/background, custom ButtonStyles instead of .bordered).
//

import SwiftUI

// MARK: - Button styles

struct ActionButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary
    var fullWidth: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.heading(15))
            .foregroundColor(foreground)
            .padding(.vertical, 13)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background(for: configuration))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(kind == .secondary ? Theme.stroke : Color.clear, lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
            .shadow(color: kind == .primary ? Theme.violetGlow : Color.clear, radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.textOnAccent
        case .secondary: return Color.dynamic(light: 0x6D28D9, dark: 0xE9E3FF)
        case .danger: return .white
        }
    }

    @ViewBuilder
    private func background(for configuration: Configuration) -> some View {
        switch kind {
        case .primary: Theme.actionGradient
        case .secondary: Theme.surface
        case .danger: LinearGradient(colors: [Theme.danger, Theme.danger.opacity(0.82)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Convenience button with optional SF Symbol.
struct ActionButton: View {
    let title: String
    var systemImage: String? = nil
    var kind: ActionButtonStyle.Kind = .primary
    var fullWidth: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let img = systemImage { Image(systemName: img) }
                Text(title)
            }
        }
        .buttonStyle(ActionButtonStyle(kind: kind, fullWidth: fullWidth))
    }
}

/// A label that looks like an ActionButton, for use inside NavigationLink.
struct ActionLabel: View {
    let title: String
    var systemImage: String? = nil
    var kind: ActionButtonStyle.Kind = .primary
    var fullWidth: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            if let img = systemImage { Image(systemName: img) }
            Text(title)
        }
        .font(Theme.heading(15))
        .foregroundColor(kind == .secondary ? Color.dynamic(light: 0x6D28D9, dark: 0xE9E3FF) : Theme.textOnAccent)
        .padding(.vertical, 13).padding(.horizontal, 18)
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(kind == .secondary ? AnyView(Theme.surface) : AnyView(Theme.actionGradient))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m)
            .stroke(kind == .secondary ? Theme.stroke : Color.clear, lineWidth: 1.2))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.m))
    }
}

// MARK: - Card container

struct CardView<Content: View>: View {
    var padding: CGFloat = Theme.Space.m
    var tint: Color? = nil
    let content: () -> Content
    init(padding: CGFloat = Theme.Space.m, tint: Color? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.padding = padding; self.tint = tint; self.content = content
    }
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.m)
                    .stroke(tint ?? Theme.stroke, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let img = systemImage {
                Image(systemName: img).foregroundColor(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(Theme.heading(17)).foregroundColor(Theme.textPrimary)
                if let s = subtitle {
                    Text(s).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
        }
    }
}

// MARK: - Status chip

struct TagChip: View {
    let text: String
    var color: Color = Theme.accent
    var filled: Bool = false
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon { Image(systemName: icon).font(.system(size: 9, weight: .bold)) }
            Text(text)
        }
        .font(Theme.caption(11))
        .foregroundColor(filled ? .white : color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(filled ? color : color.opacity(0.18)))
    }
}

// MARK: - Stat tile

struct StatTile: View {
    let value: String
    let label: String
    var systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tint)
                Spacer()
            }
            Text(value).font(Theme.title(22)).foregroundColor(Theme.textPrimary)
            Text(label).font(Theme.caption()).foregroundColor(Theme.textSecondary)
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.m).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.m).stroke(tint.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Progress bar

struct ProgressBar: View {
    var progress: Double           // 0...1
    var tint: Color = Theme.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surfaceAlt)
                Capsule().fill(tint)
                    .frame(width: geo.size.width * CGFloat(min(max(progress, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Segmented control (custom, themed — avoids UISegmented styling fights)

struct SegmentBar<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let label: (T) -> String
    var icon: ((T) -> String)? = nil

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { opt in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selection = opt }
                }) {
                    HStack(spacing: 5) {
                        if let icon = icon { Image(systemName: icon(opt)).font(.system(size: 12, weight: .semibold)) }
                        Text(label(opt)).font(Theme.caption(13))
                    }
                    .foregroundColor(selection == opt ? Theme.textOnAccent : Theme.textSecondary)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        Group {
                            if selection == opt {
                                RoundedRectangle(cornerRadius: Theme.Radius.s - 2).fill(Theme.accentGradient)
                            } else {
                                RoundedRectangle(cornerRadius: Theme.Radius.s - 2).fill(Color.clear)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
    }
}

// MARK: - Stepper row

struct StepperRow: View {
    let label: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...20
    var tint: Color = Theme.accent

    var body: some View {
        HStack {
            Text(label).font(Theme.body()).foregroundColor(Theme.textPrimary)
            Spacer()
            Button(action: { if value > range.lowerBound { value -= 1 } }) {
                Image(systemName: "minus").frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.surfaceAlt)).foregroundColor(tint)
            }.buttonStyle(PlainButtonStyle())
            Text("\(value)").font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
                .frame(minWidth: 28)
            Button(action: { if value < range.upperBound { value += 1 } }) {
                Image(systemName: "plus").frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.surfaceAlt)).foregroundColor(tint)
            }.buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Styled inputs

struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            TextField(placeholder, text: $text)
                .font(Theme.body())
                .foregroundColor(Theme.textPrimary)
                .keyboardType(keyboard)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

struct LabeledNumberField: View {
    let label: String
    @Binding var value: Double
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label.uppercased()).font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            HStack {
                TextField("0", text: Binding(
                    get: { value == 0 ? "" : Formatters.decimal(value, digits: 2) },
                    set: { value = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0 }
                ))
                .keyboardType(.decimalPad)
                .font(Theme.body())
                .foregroundColor(Theme.textPrimary)
                if !suffix.isEmpty {
                    Text(suffix).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.surfaceAlt))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.stroke, lineWidth: 1))
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    var systemImage: String = "tray"
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.accent.opacity(0.75))
            Text(title).font(Theme.heading(16)).foregroundColor(Theme.textPrimary)
            Text(message).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

// MARK: - Disclaimer banner (estimative tool)

struct DisclaimerBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundColor(Theme.wave)
            Text("Estimative guidance only — not a laboratory measurement.")
                .font(Theme.caption(11)).foregroundColor(Theme.textSecondary)
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.s).fill(Theme.wave.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.s).stroke(Theme.wave.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Screen scaffold (title bar + scroll content on acoustic backdrop)

struct ScreenScaffold<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var showWave: Bool = true
    let content: () -> Content

    init(_ title: String, subtitle: String? = nil, showWave: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.subtitle = subtitle; self.showWave = showWave; self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Theme.title(27)).foregroundColor(Theme.textPrimary)
                    if let s = subtitle {
                        Text(s).font(Theme.caption()).foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(.top, 4)
                content()
            }
            .padding(Theme.Space.m)
            .padding(.bottom, 110)   // clear the custom tab bar
        }
        .acousticScreen(showWave: showWave)
    }
}
