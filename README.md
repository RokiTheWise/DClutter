# DClutter

Swipe-based file triage for macOS. One file at a time, with a real preview and
the metadata that actually decides its fate: how big it is, when you last opened
it, and where it came from. Keep it, trash it, or file it — with a gesture or a
keystroke.

**Status:** pre-alpha, in active development.

## Building

Requires Xcode 16+ and macOS 14+.

```
open DClutter.xcodeproj
```

Core logic tests run standalone:

```
swift test --package-path DClutterKit
```

## License

Apache-2.0. See [LICENSE](LICENSE).
