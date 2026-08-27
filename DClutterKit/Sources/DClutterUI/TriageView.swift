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
    @State private var showHelp = false
    /// Live swipe position, -1..1, so the card tracks the fingers.
    @State private var swipeProgress: CGFloat = 0
    @State private var swipeMonitor = SwipeMonitorController()
    @State private var draftName = ""
    @FocusState private var renameFieldFocused: Bool
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
            controlBar(viewModel: viewModel)
            Spacer()
            if let current = viewModel.current {
                CardView(candidate: current, context: context, previewFocused: Binding(
                    get: { viewModel.previewFocused },
                    set: { viewModel.previewFocused = $0 }
                ), lastDecision: lastDecision,
                   onOpen: { viewModel.openCurrentInDefaultApp() },
                   swipeOffset: swipeProgress)
            } else {
                Text("All done.")
                    .foregroundStyle(DesignTokens.ColorToken.textSecondary)
            }
            Spacer()
            if viewModel.isRenaming {
                renameField(viewModel: viewModel)
            } else {
                statusBar(viewModel: viewModel)
            }
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
        .onAppear {
            isFocused = true
            swipeMonitor.onProgress = { amount in swipeProgress = amount }
            swipeMonitor.onCommit = { direction in
                // The departing card keeps the offset it was rendered with
                // (see CardView.swipeOffset), so it carries on out from
                // where the fingers left it. Resetting here only affects
                // the incoming card, which starts at rest.
                lastDecision = direction
                swipeProgress = 0
                withAnimation(.easeOut(duration: 0.19)) {
                    switch direction {
                    case .keep: viewModel.keep()
                    case .stage: viewModel.stage()
                    case .skip: viewModel.skip()
                    }
                }
            }
            swipeMonitor.onSnapBack = {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    swipeProgress = 0
                }
            }
            swipeMonitor.start()
        }
        .onDisappear { swipeMonitor.stop() }
        .onChange(of: viewModel.previewFocused) { _, focused in
            // While the preview has focus the gesture is the preview's.
            swipeMonitor.isEnabled = !focused && !viewModel.isRenaming
        }
        .onChange(of: viewModel.isRenaming) { _, renaming in
            // A swipe landing mid-rename would decide the very file being
            // renamed, out from under the text field.
            swipeMonitor.isEnabled = !renaming && !viewModel.previewFocused
            if !renaming { isFocused = true }
        }
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
            if letter == "z" { undo(viewModel); return .handled }
            return .ignored
        }
        // ⇧⌘Z is the macOS redo convention (⌘Y is the Windows one).
        if press.modifiers.subtracting(.capsLock) == [.command, .shift] {
            if letter == "z" { redo(viewModel); return .handled }
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
        case .downArrow:
            guard let current = viewModel.current else { return .handled }
            draftName = current.url.lastPathComponent
            viewModel.renameError = nil
            viewModel.isRenaming = true
            renameFieldFocused = true
            return .handled
        case .escape: viewModel.previewFocused = false; return .handled
        case .space: decide(.skip, using: viewModel); return .handled
        default: break
        }
        if press.key.character == "?" { showHelp.toggle(); return .handled }
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
            // Logo slot — replace the placeholder with the real mark.
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 15))
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                .help("DClutter")

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
                undo(viewModel)
            }
            .disabled(!viewModel.canUndo)
            controlButton("Redo", systemImage: "arrow.uturn.forward", shortcut: "⇧⌘Z") {
                redo(viewModel)
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

            controlButton("Help", systemImage: "questionmark.circle", shortcut: "?") {
                showHelp.toggle()
            }
            .popover(isPresented: $showHelp, arrowEdge: .bottom) { helpCard }
        }
    }

    /// Progress is measured in files, never bytes (§0). `trashedCount` is
    /// shown separately because staging already advances the decided count,
    /// so a commit would otherwise move no number on screen at all.
    private func statusBar(viewModel: SessionViewModel) -> some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Text("\(viewModel.remainingCount) left")
            Text("·")
            Text("\(viewModel.sortedSinceLastCommit) sorted")
            Spacer()
            Text("double-click the card to open it")
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(DesignTokens.ColorToken.textTertiary)
    }

    /// §2 principle 2 warns that a text field mid-session kills the loop,
    /// so this is deliberately cheap to leave: Return commits, Esc cancels,
    /// and it replaces the status bar rather than displacing the card.
    @ViewBuilder
    private func renameField(viewModel: SessionViewModel) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.unit) {
            HStack(spacing: DesignTokens.Spacing.small) {
                Text("RENAME")
                    .font(.system(size: 11, design: .monospaced))
                    .kerning(0.5)
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                TextField("", text: $draftName)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .focused($renameFieldFocused)
                    .onSubmit { viewModel.renameCurrent(to: draftName) }
                Text("↩ rename · esc cancel")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            }
            if let error = viewModel.renameError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.ColorToken.consequence)
            }
        }
        .onExitCommand {
            viewModel.isRenaming = false
            viewModel.renameError = nil
            isFocused = true
        }
    }

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text("Controls").font(.system(size: 13, weight: .semibold))
            Grid(alignment: .leading, horizontalSpacing: DesignTokens.Spacing.large, verticalSpacing: 6) {
                ForEach(Self.helpRows, id: \.0) { key, action in
                    GridRow {
                        Text(key)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DesignTokens.ColorToken.textTertiary)
                        Text(action).font(.system(size: 12))
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.large)
        .frame(width: 300)
    }

    private static let helpRows: [(String, String)] = [
        ("→  or  K", "Keep, next card"),
        ("←  or  X", "Stage for trash, next card"),
        ("Space", "Skip — comes back at the end"),
        ("↑", "Focus the preview"),
        ("↓", "Rename this file"),
        ("Esc", "Back to triage"),
        ("⌘Z", "Undo"),
        ("⇧⌘Z", "Redo"),
        ("⌘⏎", "Review and trash staged files"),
        ("Double-click", "Open the file"),
    ]

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

    /// Undo and redo cross-fade rather than sliding: the card is not
    /// leaving in a direction, it is being replaced, and a directional
    /// slide would imply a decision that isn't being made.
    private func undo(_ viewModel: SessionViewModel) {
        lastDecision = nil
        withAnimation(.easeInOut(duration: 0.19)) { viewModel.undo() }
    }

    private func redo(_ viewModel: SessionViewModel) {
        lastDecision = nil
        withAnimation(.easeInOut(duration: 0.19)) { viewModel.redo() }
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
