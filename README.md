# frida-ios-stealth

Fully automated CI that builds an **anti-detect frida-server** for iOS
(**roothide Dopamine, rootless, `/var/jb`, arm64e**) with **Florida** patches,
entirely in **GitHub Actions on a macOS runner**. Nothing is built locally.

Output: `frida_<ver>_iphoneos-arm64e.deb`, attached to a GitHub Release.

## How it runs

- Trigger: every push to `main` that touches the build, and manual
  `workflow_dispatch` (input `frida_version`, blank = latest stable `frida/frida`).
- Runner: `macos-14` (Xcode, iOS SDK, `lipo`, `codesign`). iOS Frida cannot be
  built on Linux; it needs Apple's toolchain.
- Steps: resolve version -> clone `frida` at the tag with submodules -> clone
  `Ylarod/Florida` (pinned) and apply its frida-core/frida-gum patches
  (`patch -p1`, non-applicable ones logged, never fatal) -> `./configure
  --prefix=/var/jb/usr --host=ios-arm64e -- -Dfrida-core:assets=installed` ->
  `gmake` -> ad-hoc `codesign` with entitlements preserved -> package rootless
  `.deb` -> GitHub Release.

`--host=ios-arm64e` emits a fat **arm64 + arm64e** binary in one pass, so the
single `arm64e` package runs on every A12+ device. `arm64eoabi` (old-ABI, needs
Xcode 11.7) is intentionally dropped - Dopamine targets the new arm64e ABI - so
no separate `mkfatmacho` merge is required.

## Status channel

The GitHub MCP used to drive this has no Actions-log access, so each run
self-reports to the orphan branch **`ci-status`** (`status.md`,
`build-tail.log`). That branch is CI-filtered and never triggers a build.

## Install on roothide Dopamine

```sh
# on the device (rootless)
dpkg -i frida_<ver>_iphoneos-arm64e.deb
# daemon auto-loads via /var/jb/Library/LaunchDaemons/re.frida.server.plist
launchctl reload /var/jb/Library/LaunchDaemons/re.frida.server.plist   # if needed
```

See the release notes for the exact applied/skipped patch list per build, and
the repo notes for renaming the daemon / setting a custom port.

## Credits

- Frida - https://frida.re
- Florida anti-detect patches - https://github.com/Ylarod/Florida
- iOS build + packaging recipe - miticollo's gists
