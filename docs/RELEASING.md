# Cutting a release

1. Bump `MARKETING_VERSION` in `DClutter.xcodeproj` (all configs), update
   `dist/READ ME FIRST.txt`, and write notes in `docs/releases/v<version>.md`.
   Run `swift test --package-path DClutterKit --configuration release`.
2. Build a **universal** Release binary — the default build is this Mac's
   architecture only, which would exclude Intel:

   ```bash
   xcodebuild -project DClutter.xcodeproj -scheme DClutter \
     -configuration Release -destination 'generic/platform=macOS' \
     -derivedDataPath /tmp/dclutter-release-<version> \
     ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
     CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build
   ```

   This uses an ad-hoc signature with the app's sandbox entitlements. It does
   not provide an Apple Developer identity or notarization.

3. Verify the artifact rather than the source. Both of these have been
   wrong before, and neither is visible in the code:

   ```bash
   lipo -archs <app>/Contents/MacOS/DClutter          # expect: x86_64 arm64
   otool -l <app>/Contents/MacOS/DClutter | grep minos # expect: 14.0
   defaults read <app>/Contents/Info.plist CFBundleShortVersionString
   codesign --verify --deep --strict <app>
   codesign -d --entitlements :- <app>
   ```

   Confirm the version matches the release and both architecture slices have
   a macOS 14.0 minimum. The entitlements must include the sandbox, Downloads
   read/write, user-selected read/write, and app-scoped bookmarks, without
   `get-task-allow` (debugger access). Release disables base-entitlement injection
   so a local ad-hoc build does not inherit that entitlement. Launch this
   Release app and check the layout and Settings before packaging.

4. Package the app together with `dist/READ ME FIRST.txt`:

   ```bash
   mkdir "DClutter <version>" && cp -R <app> "DClutter <version>/"
   cp "dist/READ ME FIRST.txt" "DClutter <version>/"
   ditto -c -k --sequesterRsrc --keepParent "DClutter <version>" DClutter-<version>.zip
   unzip -t DClutter-<version>.zip
   shasum -a 256 DClutter-<version>.zip > SHA256SUMS.txt
   ```

   Extract the ZIP into a fresh directory and verify the extracted app's
   signature and version too. Keep the archive, checksum, notes, and a record
   of the source commit and verification results together.

5. Merge the reviewed release changes before tagging. Publish on GitHub with
   tag `v<version>` targeting that merge commit, and upload the ZIP and checksum.
   Use the title and notes from `docs/releases/v<version>.md`. Tick
   **Set as a pre-release** while the app lacks an Apple Developer signature.
   Preparing files locally does not publish a release or create a tag.

6. **Update the download link in `README.md`** — it points at a specific
   tag and filename, so it goes stale the moment a new version ships.
   Change the README's release status and remove the pending-release note
   once the download is live.
