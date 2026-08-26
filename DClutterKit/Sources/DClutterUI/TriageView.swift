//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import SwiftUI
import DClutterCore

/// §6 keyboard table (M2 subset — 1-3/move and gestures are M4):
/// →/K keep, ←/X stage, ⌘Z undo, Space skip, ⌘⏎ commit sheet,
/// ↑ focus preview, Esc unfocus.
public struct TriageView: View {
    @State private var viewModel: SessionViewModel?
    @State private var context: QueueContext?
    let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public var body: some View {
        Group {
            if let viewModel, let context {
                content(viewModel: viewModel, context: context)
            } else {
                ProgressView().task { await loadSession() }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: SessionViewModel, context: QueueContext) -> some View {
        VStack(spacing: DesignTokens.Spacing.xLarge) {
            Spacer()
            if let current = viewModel.current {
                CardView(candidate: current, context: context, previewFocused: Binding(
                    get: { viewModel.previewFocused },
                    set: { viewModel.previewFocused = $0 }
                ))
            } else {
                Text("All done.")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            Spacer()
            HStack {
                Text("\(viewModel.totalCount - viewModel.remainingCount) of \(viewModel.totalCount)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                Spacer()
                Text("⌘⏎ commit")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            }
        }
        .padding(DesignTokens.Spacing.cardMargin)
        .background(DesignTokens.ColorToken.surface)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress { press in handle(press, viewModel: viewModel) }
        .sheet(isPresented: Bindable(viewModel).showCommitSheet) {
            CommitSheet(viewModel: viewModel)
        }
    }

    private func handle(_ press: KeyPress, viewModel: SessionViewModel) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            switch press.key {
            case "z": viewModel.undo(); return .handled
            case .return: viewModel.showCommitSheet = true; return .handled
            default: return .ignored
            }
        }
        switch press.key {
        case .rightArrow, "k": viewModel.keep(); return .handled
        case .leftArrow, "x": viewModel.stage(); return .handled
        case .upArrow: viewModel.previewFocused = true; return .handled
        case .escape: viewModel.previewFocused = false; return .handled
        case .space: viewModel.skip(); return .handled
        default: return .ignored
        }
    }

    private func loadSession() async {
        let provider = DirectoryMetadataProvider()
        guard let candidates = try? await provider.candidates(in: folder) else { return }
        let ranked = QueueScorer.rank(candidates).map(\.candidate)
        let supportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("DClutter", isDirectory: true)
        if let supportDir {
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        }
        let persistenceURL = (supportDir ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("session.json")
        let session = DClutterSession(candidates: ranked, persistenceURL: persistenceURL)
        self.context = QueueContext(candidates: ranked)
        self.viewModel = SessionViewModel(session: session)
    }
}
