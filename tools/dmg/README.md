# Build the Mac disk image

On macOS with Python 3.10+, install the pinned packaging dependencies in the
ignored build directory:

```sh
python3 -m venv build/dmg-tools
build/dmg-tools/bin/python -m pip install -r tools/dmg/requirements.txt
```

Package an existing release app, without rebuilding or re-signing it:

```sh
tools/build-dmg.sh "build/releases/1.1.0/DClutter 1.1.0/DClutter.app"
```

The app's Info.plist determines the version. The output defaults to
`build/releases/<version>/DClutter-<version>.dmg`, alongside a SHA-256 checksum.
Pass a second argument to choose another output directory. Existing files are
never overwritten.

The compressed, read-only HFS+ image contains the app, an Applications shortcut,
first-launch instructions, and the project license. The Finder layout is written
by dmgbuild without driving Finder or requiring AppleScript permissions.

Creating a DMG does not require an Apple Developer account. This step neither
signs nor notarizes the app; the current release still needs one-time Gatekeeper
approval. No security checks or quarantine attributes are disabled.

Before publishing, mount the final image, verify its app version and contents,
and compare the app executable with the original release. Publishing the DMG and
switching the website download URL are separate release steps.
