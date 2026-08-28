# Cutting a release

1. Bump `MARKETING_VERSION` in `DClutter.xcodeproj` (all configs).
2. Build a **universal** Release binary — the default build is this Mac's
   architecture only, which would exclude Intel:

   ```bash
   xcodebuild -project DClutter.xcodeproj -scheme DClutter \
     -configuration Release -destination 'generic/platform=macOS' \
     ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build
   ```

3. Verify the artifact rather than the source. Both of these have been
   wrong before, and neither is visible in the code:

   ```bash
   lipo -archs <app>/Contents/MacOS/DClutter          # expect: x86_64 arm64
   otool -l <app>/Contents/MacOS/DClutter | grep minos # expect: 14.0
   defaults read <app>/Contents/Info.plist CFBundleShortVersionString
   ```

4. Package the app together with `dist/READ ME FIRST.txt`:

   ```bash
   mkdir "DClutter <version>" && cp -R <app> "DClutter <version>/"
   cp "dist/READ ME FIRST.txt" "DClutter <version>/"
   ditto -c -k --sequesterRsrc --keepParent "DClutter <version>" DClutter-<version>.zip
   ```

5. Publish the release on GitHub, tagging `v<version>`, ticking
   **Set as a pre-release** while still unsigned.

6. **Update the download link in `README.md`** — it points at a specific
   tag and filename, so it goes stale the moment a new version ships.
   Update `dist/READ ME FIRST.txt`'s version line too.
