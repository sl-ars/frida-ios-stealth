# Install on roothide Dopamine (rootless, arm64e)

The package installs frida-server as a LaunchDaemon under `/var/jb`.

## Plain install

```sh
# copy the .deb to the device, then (as root, in a rootless shell):
dpkg -i frida_17.17.0_iphoneos-arm64e.deb
# the maintainer script auto-loads the daemon:
#   launchctl load /var/jb/Library/LaunchDaemons/re.frida.server.plist
# if it did not start:
launchctl reload /var/jb/Library/LaunchDaemons/re.frida.server.plist \
  || launchctl load /var/jb/Library/LaunchDaemons/re.frida.server.plist
```

Layout after install:

```
/var/jb/usr/sbin/frida-server
/var/jb/usr/lib/frida-1.0/frida-agent.dylib
/var/jb/Library/LaunchDaemons/re.frida.server.plist
```

By default frida-server listens on `127.0.0.1:27042`. Reach it over USB with
`frida-ls-devices` / `frida -U ...`, or forward the port.

## Custom port

Add a `-l` argument to the daemon. Edit
`/var/jb/Library/LaunchDaemons/re.frida.server.plist` and extend
`ProgramArguments`:

```xml
<key>ProgramArguments</key>
<array>
    <string>/var/jb/usr/sbin/frida-server</string>
    <string>-l</string>
    <string>127.0.0.1:47821</string>   <!-- your port; 0.0.0.0:PORT to expose on the network -->
</array>
```

Then `launchctl unload` and `launchctl load` the plist.

## Rename the daemon (reduce on-disk signature)

The build hides some in-binary strings, but the on-disk names
(`frida-server`, `re.frida.server`) are still default. To rename:

```sh
NEW=com.apple.mobilegestalthelper      # pick anything inconspicuous
launchctl unload /var/jb/Library/LaunchDaemons/re.frida.server.plist

# rename the binary IN PLACE (keep it under /var/jb/usr/sbin so the agent at
# ../lib/frida-1.0/frida-agent.dylib is still found relative to the binary)
mv /var/jb/usr/sbin/frida-server /var/jb/usr/sbin/${NEW}

# new plist
mv /var/jb/Library/LaunchDaemons/re.frida.server.plist \
   /var/jb/Library/LaunchDaemons/${NEW}.plist
```

Edit `/var/jb/Library/LaunchDaemons/${NEW}.plist` so `Label`, `Program` and the
first `ProgramArguments` string all point at the new name:

```xml
<key>Label</key>            <string>com.apple.mobilegestalthelper</string>
<key>Program</key>          <string>/var/jb/usr/sbin/com.apple.mobilegestalthelper</string>
<key>ProgramArguments</key>
<array>
    <string>/var/jb/usr/sbin/com.apple.mobilegestalthelper</string>
    <string>-l</string>
    <string>127.0.0.1:47821</string>
</array>
```

```sh
launchctl load /var/jb/Library/LaunchDaemons/${NEW}.plist
```

Note: keep `frida-agent.dylib` at `/var/jb/usr/lib/frida-1.0/`. The server finds
the agent relative to its own location, so renaming the binary is fine but moving
it out of `/var/jb/usr/sbin` (or removing the agent) breaks injection.

## What is and is not hidden

Applied anti-detect (real effect on the iOS binary):

- process name spoofed to `ggbond` (`g_set_prgname`, frida-core + frida-gum)
- plaintext `frida:rpc` literal removed from the binary (base64-obfuscated,
  runtime protocol unchanged)

Not hidden in this build (Florida does these on Android via an ELF post-pass
that does not apply to a Mach-O):

- the `frida_agent_main` exported symbol
- the `gum-js-loop` / `gmain` / `gdbus` thread names
- on-disk names (`frida-server`, `re.frida.server`) unless you rename as above

A binary-level, equal-length rename of the thread names on the Mach-O can be
added to CI if you want those hidden too.
