//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

struct TriageIconButton: View {
    let title: String
    let symbol: String
    var shortcut: String? = nil
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .frame(width: 32, height: 32)
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                .background(DesignTokens.ColorToken.textPrimary.opacity(hovered ? 0.09 : 0.035), in: RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .opacity(isEnabled ? 1 : 0.65)
        .onHover { hovered = $0 }
        .accessibilityLabel(title)
        .help(shortcut.map { "\(title)  (\($0))" } ?? title)
    }
}

struct TriageDecisionButton: View {
    let title: String
    let symbol: String
    let key: String
    var consequential = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovered = false

    private var tint: Color {
        consequential ? DesignTokens.ColorToken.consequence : DesignTokens.ColorToken.textPrimary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 13))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                Spacer(minLength: 0)
                Text(key)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 20, height: 20)
                    .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 4))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(tint.opacity(hovered ? 0.11 : 0.045), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(tint.opacity(consequential ? 0.22 : 0.12)))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovered = $0 }
        .accessibilityLabel(consequential ? "Stage for trash" : title)
        .help(consequential ? "Stage for trash — review before deleting  (←)" : "\(title)  (\(key == "␣" ? "Space" : key))")
    }
}
