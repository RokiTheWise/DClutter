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
    @State private var loadError: String?
    // This is a keyboard-first app: .onKeyPress only fires on a focused
    // view, and nothing else in the window claims focus, so the triage
    // surface must explicitly take it — both at launch and again whenever
    // the commit sheet dismisses (a sheet steals focus while presented).
    @FocusState private var isFocused: Bool
    // §7: which key decided the card currently animating out, so CardView
    // can translate the exit in that direction.
    @State private var lastDecision: DecisionDirection?
    @State private var showResetConfirm = false
    let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    public var body: some View {
        Group {
            if let viewModel, let context {
                content(viewModel: viewModel, context: context)
            } else if let loadError {
                VStack(spacing: DesignTokens.Spacing.large) {
                    Text("Couldn't read your Downloads folder.")
                        .foregroundStyle(DesignTokens.ColorToken.textPrimary)
                    Text(loadError)
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                    Button("Try Again") {
                        // Clearing loadError re-renders into the ProgressView
                        // branch, whose own .task fires loadSession() — do
                        // not also kick one off here, or two concurrent
                        // scans race to write the same persistence file.
                        self.loadError = nil
                    }
                }
                .padding(DesignTokens.Spacing.cardMargin)
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
                ), lastDecision: lastDecision, onOpen: { viewModel.openCurrentInDefaultApp() })
            } else {
                Text("All done.")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            Spacer()
            controlBar(viewModel: viewModel)
        }
        .padding(DesignTokens.Spacing.cardMargin)
        .background(DesignTokens.ColorToken.surface)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress { press in handle(press, viewModel: viewModel) }
        // Escape hatch. Once the live QLPreviewView takes first responder,
        // .onKeyPress above stops firing entirely — including for Esc — so
        // focusing the preview would trap the user with no way back to
        // triage. A .keyboardShortcut is registered at the window level and
        // fires regardless of which subview holds focus.
        .background(
            Button("") {
                viewModel.previewFocused = false
                isFocused = true
            }
            .keyboardShortcut(.cancelAction)
            .opacity(0)
            .accessibilityHidden(true)
        )
        .onAppear { isFocused = true }
        .confirmationDialog(
            "Start over?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Start Over", role: .destructive) { viewModel.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every keep, trash and skip decision is discarded and the queue restarts. Files already moved to the Trash stay there.")
        }
        .sheet(isPresented: Bindable(viewModel).showCommitSheet) {
            CommitSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.showCommitSheet) { _, isPresented in
            if !isPresented { isFocused = true }
        }
    }

    private func handle(_ press: KeyPress, viewModel: SessionViewModel) -> KeyPress.Result {
        // Lowercased so Caps Lock doesn't break the letter bindings below.
        let letter = press.key.character.lowercased()
        // Exact modifier set, not `.contains(.command)` — otherwise e.g.
        // ⌥⌘Z would also count as undo. Caps Lock is subtracted because it
        // rides along in the modifier set whenever it happens to be on,
        // which would otherwise silently kill ⌘Z and ⌘⏎.
        if press.modifiers.subtracting(.capsLock) == .command {
            switch press.key {
            case .return: viewModel.showCommitSheet = true; return .handled
            default: break
            }
            if letter == "z" { viewModel.undo(); return .handled }
            return .ignored
        }
        // ⇧⌘Z is the macOS redo convention (⌘Y is the Windows one).
        if press.modifiers.subtracting(.capsLock) == [.command, .shift] {
            if letter == "z" { viewModel.redo(); return .handled }
            return .ignored
        }
        // §6: Esc "returns control to triage", so while the preview is
        // focused the triage keys must not fire — only Esc is live.
        if viewModel.previewFocused {
            if press.key == .escape {
                viewModel.previewFocused = false
                return .handled
            }
            return .ignored
        }
        switch press.key {
        case .rightArrow: decide(.keep, using: viewModel); return .handled
        case .leftArrow: decide(.stage, using: viewModel); return .handled
        case .upArrow: viewModel.previewFocused = true; return .handled
        case .escape: viewModel.previewFocused = false; return .handled
        case .space: decide(.skip, using: viewModel); return .handled
        default: break
        }
        switch letter {
        case "k": decide(.keep, using: viewModel); return .handled
        case "x": decide(.stage, using: viewModel); return .handled
        default: return .ignored
        }
    }

    /// Every decision is reachable by pointer as well as by key. §2
    /// principle 5 says keyboard wins where the two conflict — it does not
    /// say pointer users get nothing, and a first-time user has no way to
    /// discover the bindings otherwise. Keys stay primary; these mirror them.
    @ViewBuilder
    private func controlBar(viewModel: SessionViewModel) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            Text("\(viewModel.totalCount - viewModel.remainingCount) of \(viewModel.totalCount)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(DesignTokens.ColorToken.textTertiary)

            Spacer()

            if viewModel.current != nil {
                controlButton("Trash", systemImage: "trash", shortcut: "←") {
                    decide(.stage, using: viewModel)
                }
                .foregroundStyle(DesignTokens.ColorToken.consequence)
                controlButton("Skip", systemImage: "arrow.uturn.right", shortcut: "Space") {
                    decide(.skip, using: viewModel)
                }
                controlButton("Keep", systemImage: "checkmark", shortcut: "→") {
                    decide(.keep, using: viewModel)
                }
                Divider().frame(height: 16)
            }

            controlButton("Undo", systemImage: "arrow.uturn.backward", shortcut: "⌘Z") {
                viewModel.undo()
            }
            .disabled(!viewModel.canUndo)
            controlButton("Redo", systemImage: "arrow.uturn.forward", shortcut: "⇧⌘Z") {
                viewModel.redo()
            }
            .disabled(!viewModel.canRedo)
            controlButton("Start Over", systemImage: "arrow.counterclockwise", shortcut: nil) {
                showResetConfirm = true
            }

            Divider().frame(height: 16)

            controlButton("Commit", systemImage: "tray.and.arrow.down", shortcut: "⌘⏎") {
                viewModel.showCommitSheet = true
            }
            .disabled(viewModel.stagedForCommit.isEmpty)
        }
    }

    private func controlButton(
        _ label: String,
        systemImage: String,
        shortcut: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.system(size: 11))
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.accessoryBar)
        .help(shortcut.map { "\(label)  (\($0))" } ?? label)
    }

    private func decide(_ direction: DecisionDirection, using viewModel: SessionViewModel) {
        // A removal transition is resolved from the departing view's LAST
        // COMMITTED render, so setting `lastDecision` in the same pass as
        // the mutation is too late — the outgoing card would animate in the
        // *previous* decision's direction (press right then left, and the
        // left exit still slides right). Commit the direction first, then
        // mutate on the next pass so the departing card already carries the
        // correct transition.
        guard lastDecision != direction else {
            performDecision(direction, using: viewModel)
            return
        }
        lastDecision = direction
        Task { @MainActor in
            performDecision(direction, using: viewModel)
        }
    }

    private func performDecision(_ direction: DecisionDirection, using viewModel: SessionViewModel) {
        withAnimation(.easeInOut(duration: 0.19)) {
            switch direction {
            case .keep: viewModel.keep()
            case .stage: viewModel.stage()
            case .skip: viewModel.skip()
            }
        }
    }

    private func loadSession() async {
        let provider = DirectoryMetadataProvider()
        let candidates: [FileCandidate]
        do {
            candidates = try await provider.candidates(in: folder)
        } catch {
            loadError = error.localizedDescription
            return
        }
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
