//
//  CustomTabBar.swift
//  QuietWall
//
//  Custom themed tab bar (not the system TabView chrome). Five tabs; the Build
//  tab shows a red badge equal to the active build's acoustic-bridge count.
//  iOS 14 safe.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case build, estimate, compare, docs, more
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .build: return "Build"
        case .estimate: return "Estimate"
        case .compare: return "Compare"
        case .docs: return "Docs"
        case .more: return "More"
        }
    }
    var icon: String {
        switch self {
        case .build: return "square.stack.3d.up.fill"
        case .estimate: return "waveform"
        case .compare: return "rectangle.split.3x1.fill"
        case .docs: return "doc.text.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

struct CustomTabBar: View {
    @Binding var selection: AppTab
    var badge: Int = 0   // bridge count, shown on the Build tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selection = tab }
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Image(systemName: tab.icon)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(selection == tab ? Theme.accent : Theme.textSecondary)
                                .scaleEffect(selection == tab ? 1.14 : 1.0)
                                .shadow(color: selection == tab ? Theme.violetGlow : .clear, radius: 8)
                            if tab == .build && badge > 0 {
                                Text("\(badge)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(Theme.danger))
                                    .offset(x: 12, y: -10)
                            }
                        }
                        Text(tab.title)
                            .font(.system(size: 10, weight: selection == tab ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == tab ? Theme.accent : Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .padding(.horizontal, 6)
        .background(
            BlurView(style: .systemChromeMaterialDark)
                .overlay(Theme.bgSoft.opacity(0.7))
                .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
                .edgesIgnoringSafeArea(.bottom)
        )
    }
}
