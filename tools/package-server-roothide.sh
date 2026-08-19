#!/bin/sh
#
# Package frida-server for roothide Dopamine.
#
# roothide has NO /var/jb: the jailbreak root (jbroot) is at a randomized path.
# Per roothide's developer docs, a package uses a ROOTFUL layout (paths like
# /usr/sbin, /Library/LaunchDaemons, with NO /var/jb prefix); dpkg installs the
# files into the randomized jbroot automatically. Paths written into plists and
# scripts are jbroot-based (as if jbroot were "/"), and the `jbroot` command line
# tool converts a jbroot-based path to the real rootfs path when one is needed
# (e.g. for launchctl, which is the system's and speaks real paths).
#
# Usage: FRIDA_VERSION=x.y.z package-server-roothide.sh <arch> <prefix> <output.deb>
#   arch   = iphoneos-arm64e
#   prefix = tree containing usr/bin/frida-server and usr/lib/frida*/frida-agent.dylib
#

if [ -z "$FRIDA_VERSION" ]; then
  echo "FRIDA_VERSION must be set" > /dev/stderr
  exit 2
fi
if [ $# -ne 3 ]; then
  echo "Usage: $0 arch path/to/prefix output.deb" > /dev/stderr
  exit 3
fi
arch=$1
prefix=$2
output_deb=$3

executable=$prefix/usr/bin/frida-server
if [ ! -f "$executable" ]; then
  echo "$executable: not found" > /dev/stderr
  exit 4
fi
agent="$(ls "$prefix"/usr/lib/frida*/frida-agent.dylib 2>/dev/null | head -1)"
if [ -z "$agent" ] || [ ! -f "$agent" ]; then
  echo "frida-agent.dylib: not found under $prefix/usr/lib/frida*" > /dev/stderr
  exit 5
fi
agent_libdir="$(basename "$(dirname "$agent")")"

tmpdir="$(mktemp -d /tmp/package-roothide.XXXXXX)"

# rootful layout (NO /var/jb) - dpkg relocates into jbroot
mkdir -p "$tmpdir/usr/sbin/"
cp "$executable" "$tmpdir/usr/sbin/frida-server"
chmod 755 "$tmpdir/usr/sbin/frida-server"

mkdir -p "$tmpdir/usr/lib/$agent_libdir/"
cp "$agent" "$tmpdir/usr/lib/$agent_libdir/frida-agent.dylib"
chmod 755 "$tmpdir/usr/lib/$agent_libdir/frida-agent.dylib"

# LaunchDaemon: jbroot-based paths (roothide's daemon loader resolves them at boot)
mkdir -p "$tmpdir/Library/LaunchDaemons/"
cat >"$tmpdir/Library/LaunchDaemons/re.frida.server.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>re.frida.server</string>
	<key>Program</key>
	<string>/usr/sbin/frida-server</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/sbin/frida-server</string>
	</array>
	<key>UserName</key>
	<string>root</string>
	<key>POSIXSpawnType</key>
	<string>Interactive</string>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>ThrottleInterval</key>
	<integer>5</integer>
	<key>ExecuteAllowed</key>
	<true/>
</dict>
</plist>
EOF
chmod 644 "$tmpdir/Library/LaunchDaemons/re.frida.server.plist"

installed_size=$(du -sk "$tmpdir" | cut -f1)

mkdir -p "$tmpdir/DEBIAN/"
cat >"$tmpdir/DEBIAN/control" <<EOF
Package: re.frida.server
Name: Frida
Version: $FRIDA_VERSION
Priority: optional
Size: 1337
Installed-Size: $installed_size
Architecture: $arch
Description: Observe and reprogram running programs. (roothide build)
Homepage: https://frida.re/
Maintainer: Frida Developers <oleavr@nowsecure.com>
Author: Frida Developers <oleavr@nowsecure.com>
Section: Development
Conflicts: re.frida.server64
EOF
chmod 644 "$tmpdir/DEBIAN/control"

# Maintainer scripts: resolve the real plist path via the roothide `jbroot`
# command, then (re)load it. If launchd cannot exec the jbroot-based Program
# immediately, roothide's own daemon loader picks it up on the next respring/reboot.
cat >"$tmpdir/DEBIAN/extrainst_" <<'EOF'
#!/bin/sh
if [ "$1" = install ] || [ "$1" = upgrade ]; then
  plist="/Library/LaunchDaemons/re.frida.server.plist"
  real="$(jbroot "$plist" 2>/dev/null)"; [ -n "$real" ] || real="$plist"
  launchctl bootout system "$real" 2>/dev/null || launchctl unload "$real" 2>/dev/null || true
  launchctl bootstrap system "$real" 2>/dev/null || launchctl load "$real" 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$tmpdir/DEBIAN/extrainst_"

cat >"$tmpdir/DEBIAN/prerm" <<'EOF'
#!/bin/sh
if [ "$1" = remove ] || [ "$1" = purge ]; then
  plist="/Library/LaunchDaemons/re.frida.server.plist"
  real="$(jbroot "$plist" 2>/dev/null)"; [ -n "$real" ] || real="$plist"
  launchctl bootout system "$real" 2>/dev/null || launchctl unload "$real" 2>/dev/null || true
fi
exit 0
EOF
chmod 755 "$tmpdir/DEBIAN/prerm"

dpkg_options="-Zxz --root-owner-group"

dpkg-deb $dpkg_options --build "$tmpdir" "$output_deb"
package_size=$(expr $(du -sk "$output_deb" | cut -f1) \* 1024)
sed -e "s,^Size: 1337$,Size: $package_size,g" "$tmpdir/DEBIAN/control" > "$tmpdir/DEBIAN/control_"
mv "$tmpdir/DEBIAN/control_" "$tmpdir/DEBIAN/control"
dpkg-deb $dpkg_options --build "$tmpdir" "$output_deb"

rm -rf "$tmpdir"
