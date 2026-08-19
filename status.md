# CI build status

- status: **success**
- frida_version: 17.17.0
- commit: 552194b4f8b2a16d2b15b1df836f1d7000ae6b62
- run: https://github.com/sl-ars/frida-ios-stealth/actions/runs/32236473262
- utc: 2026-08-19T09:17:00Z

## deb artifacts
```
total 65560
drwxr-xr-x   5 runner  staff       160 Aug 19 09:16 .
drwxr-xr-x  16 runner  staff       512 Aug 19 09:16 ..
-rw-r--r--   1 runner  staff         8 Aug 19 09:16 FRIDA_VERSION.txt
-rw-r--r--   1 runner  staff  16609316 Aug 19 09:16 frida_17.17.0_iphoneos-arm64e-roothide.deb
-rw-r--r--   1 runner  staff  16608940 Aug 19 09:16 frida_17.17.0_iphoneos-arm64e.deb
```

## patch report
```
# patch report  (frida root: /Users/runner/work/frida-ios-stealth/frida-ios-stealth/frida)
# Florida pinned: 6d4b2e88ebe2bace12322db93470b0e68d4240c9

SKIPPED(does-not-apply)   [florida] frida-core/0001-Florida-string_frida_rpc.patch
APPLIED                   [florida] frida-core/0002-Florida-frida_agent_so.patch
SKIPPED(does-not-apply)   [florida] frida-core/0003-Florida-symbol_frida_agent_main.patch
SKIPPED(does-not-apply)   [florida] frida-core/0004-Florida-thread_gum_js_loop.patch
SKIPPED(does-not-apply)   [florida] frida-core/0005-Florida-thread_gmain.patch
APPLIED                   [florida] frida-core/0006-Florida-protocol_unexpected_command.patch
SKIPPED(does-not-apply)   [florida] frida-core/0007-Florida-update-python-script.patch
APPLIED                   [florida] frida-core/0008-Florida-pool-frida.patch
APPLIED                   [florida] frida-core/0009-Florida-memfd-name-jit-cache.patch
APPLIED                   [florida] frida-core/0010-exec-anti-anti-frida.py.patch
APPLIED                   [florida] frida-gum/0001-Florida-pool-frida.patch
APPLIED                   [ios] frida-core/0001-ios-rpc-string-obfuscation.patch

# Patches touching linux/*, droidy/*, memfd (Linux/Android code paths) may
# apply to files present in the tree but those files are not compiled into
# the iOS/Darwin server. The anti-anti-frida.py symbol pass is ELF-oriented
# and only runs on the non-Darwin embed path; on iOS it is effectively a no-op.
# [ios] patches are re-derived for the current frida and carry the real
# iOS-relevant anti-detect edits (e.g. rpc-string obfuscation).
```

_full tail in build-tail.log on this branch_
