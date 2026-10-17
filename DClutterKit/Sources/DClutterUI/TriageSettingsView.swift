//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI

enum SettingsSection { case general, controls }

struct TriageSettingsView<Controls: View>: View {
    @Binding var holdSpeed: Double
    @Binding var confirmAddFolder: Bool
    @Binding var section: SettingsSection
    @ViewBuilder var controls: () -> Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings").font(.headline)
            Picker("Settings section", selection: $section) {
                Text("General").tag(SettingsSection.general)
                Text("Controls & gestures").tag(SettingsSection.controls)
            }
            .pickerStyle(.segmented)

            if section == .general {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Hold speed").fontWeight(.medium)
                        Spacer()
                        let speed = InteractionSettings.boundedSpeed(holdSpeed)
                        Text("\(speed, format: .number.precision(.fractionLength(0...1))) \(speed == 1 ? "file" : "files") / second")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $holdSpeed, in: InteractionSettings.holdSpeedRange, step: 0.5) {
                        Text("Hold speed")
                    }
                    .accessibilityIdentifier("hold-speed")
                    HStack {
                        Text("Slow")
                        Spacer()
                        Text("Fast")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(holdSpeed < 1
                        ? "One file every two seconds while holding ← or →. Single presses respond immediately."
                        : "Hold ← or → to move through files at this pace. Single presses respond immediately.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Confirm “Add folder…”", isOn: $confirmAddFolder)
                        .accessibilityIdentifier("confirm-add-folder")
                    Text("After a swipe, press Return or click “Add folder…” to open the folder picker.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ScrollView { controls().frame(maxWidth: .infinity, alignment: .leading) }
                    .frame(height: 460)
            }
        }
        .padding(20)
        .frame(width: 420, alignment: .leading)
    }
}
