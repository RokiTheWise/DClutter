//  DClutter — swipe-based file triage for macOS
//  Copyright 2026 Dexter Jethro Enriquez
//  Licensed under the Apache License, Version 2.0.

import AppKit
import SwiftUI
import DClutterCore
import DClutterPlatform

/// →/K keep, ←/X stage, Space skip, 1-3 file into a destination,
/// ↑ open the shelf then ←/→ and ⏎, ⌘Z undo, ⇧⌘Z or ⌘Y redo,
/// ⌘⏎ commit sheet, ⌘N add a destination, ↓ rename, ? help.
///
/// §6 assigned ↑ to focusing the preview. That focus is gone: it trapped
/// the keyboard, and it was the sole reason two-finger vertical could not
/// be used for the shelf.
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
    /// Destination shelf. Opened by two fingers up or ↑, steered by the
    /// fingers or ←/→, committed by lifting or Return. §6 originally put
    /// this on a click-drag to avoid colliding with preview scrolling —
    /// that collision is gone now that the preview is never focusable, so
    /// the gesture can live on the axis people reach for.
    @State private var shelfOpen = false
    @State private var selectedBin = 0
    /// The folder being triaged. State, not a constant: it is the one
    /// thing on this screen the user can change without quitting.
    @State private var folder: URL
    /// Held for as long as this folder is the source. Nil for Downloads,
    /// which the entitlement reaches without a bookmark.
    @State private var access: ScopedFolderAccess?
    @State private var recentFolders: [URL] = []
    /// A folder the user asked for while files were still staged. Held
    /// until they say what should happen to the staged set.
    @State private var pendingSwitch: URL?
    private let sourceFolderStore = SourceFolderStore()

    public init(folder: URL) {
        _folder = State(initialValue: folder)
    }

    /// In a sandboxed app, `homeDirectoryForCurrentUser` returns the
    /// container path, not the real home — appending "Downloads" to it
    /// would scan an empty folder inside the container.
    /// `.downloadsDirectory` is what the
    /// `com.apple.security.files.downloads.read-write` entitlement (§7)
    /// resolves to the real ~/Downloads.
    ///
    /// Note it resolves to a *symlink* into the real folder, not the
    /// folder itself; `DirectoryMetadataProvider` resolves that, since the
    /// URL-based directory enumeration refuses to follow symlinks.
    public static var defaultDownloadsFolder: URL {
        (try? FileManager.default.url(for: .downloadsDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    /// True when `folder` is the entitlement-granted Downloads folder,
    /// which needs neither a bookmark nor a held scope.
    private var isDownloads: Bool {
        folder.resolvingSymlinksInPath().standardizedFileURL
            == Self.defaultDownloadsFolder.resolvingSymlinksInPath().standardizedFileURL
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
                ProgressView().task(id: folder) { await loadSession() }
            }
        }
    }

    @ViewBuilder
    private func content(viewModel: SessionViewModel, context: QueueContext) -> some View {
        VStack(spacing: DesignTokens.Spacing.xLarge) {
            controlBar(viewModel: viewModel)
            DestinationShelf(
                destinations: viewModel.destinations,
                revealed: shelfOpen ? 1 : 0,
                highlighted: shelfOpen ? selectedBin : nil,
                onChooseFolder: { viewModel.chooseDestinationFolder() },
                onRemove: { index in
                    viewModel.removeDestination(at: index)
                    selectedBin = min(selectedBin, max(binCount(viewModel) - 1, 0))
                }
            )
            .frame(height: shelfOpen ? nil : 0)
            Spacer()
            if let current = viewModel.current {
                CardView(candidate: current, context: context,
                   lastDecision: lastDecision,
                   onOpen: { viewModel.openCurrentInDefaultApp() },
                   swipeOffset: swipeProgress,
                   onReveal: { viewModel.revealCurrentInFinder() },
                   onRename: { beginRename(viewModel: viewModel) },
                   onCopyName: { viewModel.copyCurrentName() })
                    // Shrinks back and fades while choosing a folder, so
                    // the shelf is unobstructed and the card reads as the
                    // thing being filed rather than the thing in focus.
                    .scaleEffect(shelfOpen ? 0.82 : 1)
                    .opacity(shelfOpen ? 0.45 : 1)
                    .animation(.spring(response: 0.26, dampingFraction: 0.85), value: shelfOpen)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignTokens.ColorToken.surface.ignoresSafeArea())
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress { press in handle(press, viewModel: viewModel) }
        .onAppear {
            isFocused = true
            recentFolders = sourceFolderStore.recents()
            swipeMonitor.onProgress = { amount in swipeProgress = amount }
            swipeMonitor.onCommit = { direction in
                // Exactly the keyboard's path. The offset is cleared inside
                // performDecision's animation rather than here: zeroing it a
                // pass early snapped the card back to centre and only then
                // played the exit, which is the hesitation a key press
                // doesn't have — and it left the incoming card's slide
                // outside the animated transaction entirely.
                decide(direction, using: viewModel)
            }
            swipeMonitor.onShelfOpen = { openShelf(viewModel: viewModel) }
            swipeMonitor.onShelfStep = { step in stepBin(by: step, viewModel: viewModel) }
            swipeMonitor.onShelfCommit = { confirmShelf(viewModel: viewModel) }
            swipeMonitor.onShelfCancel = {
                shelfOpen = false
                swipeMonitor.endShelfSteering()
                isFocused = true
            }
            swipeMonitor.onSnapBack = {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                    swipeProgress = 0
                }
            }
            swipeMonitor.start()
        }
        .onDisappear { swipeMonitor.stop() }
        .onChange(of: viewModel.isRenaming) { _, renaming in
            // A swipe landing mid-rename would decide the very file being
            // renamed, out from under the text field.
            swipeMonitor.isEnabled = !renaming
            if !renaming { isFocused = true }
        }
        .onChange(of: shelfOpen) { _, open in
            swipeMonitor.isShelfOpen = open
        }
        .confirmationDialog(
            "Start over?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Start Over", role: .destructive) { viewModel.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(resetMessage(viewModel: viewModel))
        }
        .confirmationDialog(
            "Switch folders?",
            isPresented: Binding(
                get: { pendingSwitch != nil },
                set: { if !$0 { pendingSwitch = nil } }
            ),
            titleVisibility: .visible
        ) {
            // `viewModel` here is `content(viewModel:)`'s non-optional
            // parameter, not the optional `@State` property — no unwrap
            // needed to reach it.
            Button("Trash \(viewModel.stagedForCommit.count) File\(viewModel.stagedForCommit.count == 1 ? "" : "s")", role: .destructive) {
                viewModel.confirmCommit()
                // Only leave if it worked. confirmCommit keeps the error
                // on the view model when a file could not be trashed, and
                // switching away would take that message off screen along
                // with the folder it belongs to.
                if viewModel.commitError == nil, let target = pendingSwitch {
                    switchFolder(to: target)
                }
                pendingSwitch = nil
            }
            Button("Leave Them Staged") {
                if let target = pendingSwitch { switchFolder(to: target) }
                pendingSwitch = nil
            }
            Button("Cancel", role: .cancel) { pendingSwitch = nil }
        } message: {
            Text("\(viewModel.stagedForCommit.count) file\(viewModel.stagedForCommit.count == 1 ? " is" : "s are") staged for trash. Files you already filed into folders stay where they are either way.")
        }
        .sheet(isPresented: Bindable(viewModel).showCommitSheet) {
            CommitSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.showCommitSheet) { _, isPresented in
            if !isPresented { isFocused = true }
        }
    }

    /// Says what Start Over will actually do to files on disk. A count
    /// matters here in a way it doesn't for a single undo: nobody can
    /// eyeball twenty files coming back.
    private func resetMessage(viewModel: SessionViewModel) -> String {
        let filed = viewModel.filedThisSessionCount
        var lines = ["Every keep, trash and skip decision becomes undecided again."]
        if filed == 1 {
            lines.append("1 file you filed into a folder moves back to Downloads.")
        } else if filed > 1 {
            lines.append("\(filed) files you filed into folders move back to Downloads.")
        }
        if viewModel.trashedCount > 0 {
            lines.append("Files already in the Trash stay there — committing to the Trash ends a session.")
        }
        return lines.joined(separator: " ")
    }

    private func openShelf(viewModel: SessionViewModel) {
        guard viewModel.current != nil else { return }
        selectedBin = min(selectedBin, max(binCount(viewModel) - 1, 0))
        shelfOpen = true
    }

    /// The row may end with an "Add folder…" bin, so selection runs one
    /// past the configured destinations whenever there is room for another.
    private func binCount(_ viewModel: SessionViewModel) -> Int {
        let extra = viewModel.destinations.count < DestinationStore.maximumDestinations ? 1 : 0
        return viewModel.destinations.count + extra
    }

    private func stepBin(by step: Int, viewModel: SessionViewModel) {
        guard shelfOpen else { return }
        selectedBin = min(max(selectedBin + step, 0), max(binCount(viewModel) - 1, 0))
    }

    private func confirmShelf(viewModel: SessionViewModel) {
        guard shelfOpen else { return }
        shelfOpen = false
        swipeMonitor.endShelfSteering()
        if selectedBin >= viewModel.destinations.count {
            viewModel.chooseDestinationFolder()
        } else {
            fileAway(selectedBin, viewModel: viewModel)
        }
        isFocused = true
    }

    private func fileAway(_ index: Int, viewModel: SessionViewModel) {
        guard viewModel.destinations.indices.contains(index) else { return }
        clearDirection {
            withAnimation(.easeOut(duration: 0.19)) {
                swipeProgress = 0
                viewModel.moveCurrent(toDestinationAt: index)
            }
        }
    }

    private func beginRename(viewModel: SessionViewModel) {
        guard let current = viewModel.current else { return }
        // Stem only — the extension is preserved automatically and is not
        // the user's to accidentally delete.
        draftName = current.url.deletingPathExtension().lastPathComponent
        viewModel.renameError = nil
        viewModel.isRenaming = true
        renameFieldFocused = true
    }

    private func handle(_ press: KeyPress, viewModel: SessionViewModel) -> KeyPress.Result {
        // The rename field owns the keyboard while it is open: Space is a
        // space, not a skip, and every other binding would act on the very
        // file being renamed. Esc is handled by the field's own exit command.
        if viewModel.isRenaming { return .ignored }
        // A message about destinations has been read by the time the user
        // presses anything else; leaving it up makes it look like a
        // permanent state rather than a reply to what they just did.
        if viewModel.moveError != nil { viewModel.moveError = nil }
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
            // ⌘Y mirrors ⇧⌘Z for anyone arriving from Windows.
            if letter == "y" { redo(viewModel); return .handled }
            // §6: add a destination mid-session, so hitting an
            // unclassifiable file doesn't send the user to Finder.
            if letter == "n" { viewModel.chooseDestinationFolder(); return .handled }
            return .ignored
        }
        // ⇧⌘Z is the macOS redo convention (⌘Y is the Windows one).
        if press.modifiers.subtracting(.capsLock) == [.command, .shift] {
            if letter == "z" { redo(viewModel); return .handled }
            return .ignored
        }
        // While the shelf is open the arrows steer it rather than deciding,
        // and Return files into the highlighted bin.
        if shelfOpen {
            switch press.key {
            case .leftArrow: stepBin(by: -1, viewModel: viewModel); return .handled
            case .rightArrow: stepBin(by: 1, viewModel: viewModel); return .handled
            case .return: confirmShelf(viewModel: viewModel); return .handled
            case .escape, .upArrow, .downArrow:
                shelfOpen = false
                swipeMonitor.endShelfSteering()
                return .handled
            default: break
            }
            // The Mac's Backspace reports U+0008 while KeyEquivalent.delete
            // is U+007F, so matching the constant alone never fired.
            if press.key == .delete || press.key == .deleteForward
                || press.characters == "\u{8}" || press.characters == "\u{7F}" {
                // Frees a slot for a replacement. Removing a destination
                // only forgets the folder — nothing already filed there
                // moves, and the folder itself is untouched.
                guard selectedBin < viewModel.destinations.count else { return .handled }
                viewModel.removeDestination(at: selectedBin)
                selectedBin = min(selectedBin, max(binCount(viewModel) - 1, 0))
                return .handled
            }
            return .ignored
        }
        switch press.key {
        case .rightArrow: decide(.keep, using: viewModel); return .handled
        case .leftArrow: decide(.stage, using: viewModel); return .handled
        case .upArrow: openShelf(viewModel: viewModel); return .handled
        case .downArrow:
            beginRename(viewModel: viewModel)
            return .handled
        case .space: decide(.skip, using: viewModel); return .handled
        // Opening the file is otherwise mouse-only; ⏎ is the obvious key
        // for "show me this one properly" and nothing else claims it here.
        case .return: viewModel.openCurrentInDefaultApp(); return .handled
        default: break
        }
        if press.key.character == "?" { showHelp.toggle(); return .handled }
        if let slot = Int(letter), (1...DestinationStore.maximumDestinations).contains(slot) {
            fileAway(slot - 1, viewModel: viewModel)
            return .handled
        }
        return .ignored
    }

    /// Every decision is reachable by pointer as well as by key. §2
    /// principle 5 says keyboard wins where the two conflict — it does not
    /// say pointer users get nothing, and a first-time user has no way to
    /// discover the bindings otherwise. Keys stay primary; these mirror them.
    @ViewBuilder
    private func controlBar(viewModel: SessionViewModel) -> some View {
        HStack(spacing: DesignTokens.Spacing.small) {
            BrandMark(size: 18)
                .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                .help("DClutter")

            Divider().frame(height: 16)
            FolderField(
                url: folder,
                recents: recentFolders,
                onPick: { requestSwitch(to: $0) },
                onChoose: { chooseSourceFolder() }
            )

            Spacer()

            if viewModel.current != nil {
                // "Stage", not "Trash": this marks a file for the commit
                // sheet, while the primary control at the far end is what
                // actually trashes. Two controls both reading "Trash" made
                // a staged, reversible decision look like a deletion.
                controlButton("Stage", systemImage: "trash", shortcut: "←") {
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
            controlButton("Redo", systemImage: "arrow.uturn.forward", shortcut: "⇧⌘Z or ⌘Y") {
                redo(viewModel)
            }
            .disabled(!viewModel.canRedo)
            controlButton("Start Over", systemImage: "arrow.counterclockwise", shortcut: nil) {
                showResetConfirm = true
            }

            Divider().frame(height: 16)

            // The terminal action, and the only one that removes anything:
            // it reads as the primary control and names the count, per §0
            // (files, never bytes).
            // Prominent only when there is something to do. A disabled
            // prominent button keeps its tint and washes out to a pale
            // pink in light mode, which reads as broken rather than
            // unavailable.
            if viewModel.stagedForCommit.isEmpty {
                controlButton("Nothing staged", systemImage: "trash", shortcut: "⌘⏎") {}
                    .disabled(true)
            } else {
                Button {
                    viewModel.showCommitSheet = true
                } label: {
                    HStack(spacing: DesignTokens.Spacing.unit) {
                        Image(systemName: "trash")
                        Text("Trash \(viewModel.stagedForCommit.count)")
                            .fixedSize()
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignTokens.ColorToken.consequence)
                .help("Review and trash staged files  (⌘⏎)")
            }

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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.unit) {
            if let moveError = viewModel.moveError {
                Text(moveError)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.ColorToken.consequence)
            }
            statusCounts(viewModel: viewModel)
        }
    }

    private func statusCounts(viewModel: SessionViewModel) -> some View {
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
                    .onExitCommand {
                        viewModel.isRenaming = false
                        viewModel.renameError = nil
                    }
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.large) {
            helpSection("Keyboard", rows: Self.keyboardHelp)
            helpSection("Trackpad & mouse", rows: Self.pointerHelp)
        }
        .padding(DesignTokens.Spacing.large)
        .frame(width: 420, alignment: .leading)
    }

    private func helpSection(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(title)
                .font(.system(size: 11, design: .monospaced))
                .kerning(0.5)
                .foregroundStyle(DesignTokens.ColorToken.textTertiary)
            Grid(alignment: .leading, horizontalSpacing: DesignTokens.Spacing.large, verticalSpacing: 7) {
                ForEach(rows, id: \.0) { key, action in
                    GridRow {
                        Text(key)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(DesignTokens.ColorToken.textSecondary)
                            .gridColumnAlignment(.leading)
                            .fixedSize()
                        Text(action)
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Ordered by how often a hand actually reaches for them, not by the
    /// order they were built.
    private static let keyboardHelp: [(String, String)] = [
        ("→", "Keep, next card"),
        ("←", "Stage for trash, next card"),
        ("Space", "Skip — comes back at the end"),
        ("1 – 3", "File into a destination folder"),
        ("↑", "Open the destination shelf"),
        ("← →", "Choose a folder, then ⏎ to file it"),
        ("⌫", "Remove the highlighted folder"),
        ("Esc  ↓", "Close the shelf"),
        ("⏎", "Open this file"),
        ("↓", "Rename this file"),
        ("⌘Z", "Undo"),
        ("⇧⌘Z  ⌘Y", "Redo"),
        ("⌘⏎", "Review and trash staged files"),
        ("⌘N", "Add a destination folder"),
        ("?", "Show this list"),
    ]

    private static let pointerHelp: [(String, String)] = [
        ("Swipe right", "Keep"),
        ("Swipe left", "Stage for trash"),
        ("Two fingers up", "Open the shelf, slide across, let go"),
        ("Drag back down", "Close the shelf without filing"),
        ("Double-click", "Open this file"),
        ("Right-click", "Reveal in Finder, rename, copy name"),
    ]

    private func controlButton(
        _ label: String,
        systemImage: String,
        shortcut: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            // Icon and label only. The binding lives in the tooltip and the
            // help card: printing it here a third time made every label
            // truncate to "Tra…", which costs more than it teaches.
            HStack(spacing: DesignTokens.Spacing.unit) {
                Image(systemName: systemImage)
                Text(label)
                    .fixedSize()
            }
            .font(.system(size: 11))
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
    /// Undo and redo cross-fade rather than sliding: the card is being
    /// replaced, not decided, and a directional slide would imply a
    /// decision. Clearing `lastDecision` needs its own pass first — a
    /// removal transition resolves from the departing view's last committed
    /// render, so clearing it alongside the mutation left the card still
    /// sliding in the direction of the decision being undone.
    private func undo(_ viewModel: SessionViewModel) {
        clearDirection {
            withAnimation(.easeInOut(duration: 0.19)) {
                // Same reason as performDecision: a swipe may have left an
                // offset behind, and clearing it outside this transaction
                // leaves the arriving card's slide unanimated.
                swipeProgress = 0
                viewModel.undo()
            }
        }
    }

    private func redo(_ viewModel: SessionViewModel) {
        clearDirection {
            withAnimation(.easeInOut(duration: 0.19)) {
                swipeProgress = 0
                viewModel.redo()
            }
        }
    }

    private func clearDirection(then work: @escaping () -> Void) {
        // Reclaim focus: an undo can leave the triage surface without it,
        // and every binding here is dead the moment that happens.
        defer { isFocused = true }
        guard lastDecision != nil else { work(); return }
        lastDecision = nil
        Task { @MainActor in
            work()
            isFocused = true
        }
    }

    private func performDecision(_ direction: DecisionDirection, using viewModel: SessionViewModel) {
        withAnimation(.easeInOut(duration: 0.19)) {
            // Cleared in the same transaction as the swap: the departing
            // card keeps the offset it was rendered with, and the arriving
            // one starts at rest. Clearing it a pass earlier snapped the
            // card back to centre before the exit — the hesitation a key
            // press doesn't have — and left the incoming card's slide
            // outside the animated transaction.
            swipeProgress = 0
            switch direction {
            case .keep: viewModel.keep()
            case .stage: viewModel.stage()
            case .skip: viewModel.skip()
            }
        }
    }

    private func loadSession() async {
        // Snapshot the folder this scan is for, and read only the snapshot
        // from here on. `folder` is `@State`, and `switchFolder` can retarget
        // it while `provider.candidates(in:)` is still running — that scan
        // has no suspension point SwiftUI's cancellation reaches, so it runs
        // to completion regardless. Without the snapshot, a stale scan would
        // resolve its filename and Downloads check against wherever `folder`
        // has since moved to, wiring folder A's candidates to folder B's
        // persistence file.
        let targetFolder = folder
        let provider = DirectoryMetadataProvider()
        let candidates: [FileCandidate]
        do {
            candidates = try await provider.candidates(in: targetFolder)
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
        let stateDir = supportDir ?? FileManager.default.temporaryDirectory
        let persistenceURL = stateDir
            .appendingPathComponent(SessionPersistence.filename(for: targetFolder))

        // Anyone upgrading from ≤0.4.0 has an in-progress session in the
        // old fixed filename. It can only ever have been Downloads, so
        // carry it onto Downloads' new name rather than silently dropping
        // someone's half-finished run.
        let legacy = stateDir.appendingPathComponent("session.json")
        let targetIsDownloads = targetFolder.resolvingSymlinksInPath().standardizedFileURL
            == Self.defaultDownloadsFolder.resolvingSymlinksInPath().standardizedFileURL
        if targetIsDownloads,
           FileManager.default.fileExists(atPath: legacy.path),
           !FileManager.default.fileExists(atPath: persistenceURL.path) {
            try? FileManager.default.moveItem(at: legacy, to: persistenceURL)
        }
        let session = DClutterSession(candidates: ranked, persistenceURL: persistenceURL)
        // The folder can have moved on again while the scan above was in
        // flight. Only apply this result if it is still the one showing —
        // otherwise it's a stale scan clobbering the in-flight replacement.
        guard folder == targetFolder else { return }
        self.context = QueueContext(candidates: ranked)
        self.viewModel = SessionViewModel(session: session)
    }

    /// Points the app at a different folder. The previous folder's scope is
    /// released only after the new one is held, and the session is torn
    /// down so `.task(id:)` rebuilds it against the new candidates.
    ///
    /// Decisions already carried out on disk are left alone — a move is a
    /// finished action, and having twenty of them fly back to Downloads
    /// because you glanced at another folder is a worse surprise than
    /// leaving them where you put them. Only staged trash is pending, and
    /// `confirmSwitch` resolves that before calling this.
    private func switchFolder(to url: URL) {
        guard url.standardizedFileURL != folder.standardizedFileURL else { return }
        access = ScopedFolderAccess(url: url)
        if url.resolvingSymlinksInPath().standardizedFileURL
            != Self.defaultDownloadsFolder.resolvingSymlinksInPath().standardizedFileURL {
            sourceFolderStore.remember(url)
            recentFolders = sourceFolderStore.recents()
        }
        viewModel = nil
        context = nil
        loadError = nil
        shelfOpen = false
        swipeMonitor.endShelfSteering()
        folder = url
        isFocused = true
    }

    /// Asks for a folder. The sandbox grants access only through the panel
    /// or a bookmark it minted — a typed path grants nothing — so this is
    /// the only way in.
    private func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Triage Folder"
        panel.message = "Pick a folder to sort through."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        requestSwitch(to: url)
    }

    /// Staged trash is the only genuinely pending state — a move already
    /// happened on disk and stays done. So a switch asks about staged files
    /// and nothing else.
    private func requestSwitch(to url: URL) {
        guard let viewModel, !viewModel.stagedForCommit.isEmpty else {
            switchFolder(to: url)
            return
        }
        pendingSwitch = url
    }
}
