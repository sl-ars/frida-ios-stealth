#!/usr/bin/env bash
#
# Build anti-detect frida-server for iOS (roothide Dopamine, rootless, arm64e).
# Runs on a macOS runner. Produces out/frida_<ver>_iphoneos-arm64e.deb
#
set -uo pipefail

WORK="$(pwd)"
INPUT_VERSION="${1:-}"

log() { echo -e "\033[0;32m[build]\033[0m $*"; }
err() { echo -e "\033[0;31m[build]\033[0m $*" >&2; }

# --- resolve frida version ---------------------------------------------------
if [ -n "${INPUT_VERSION}" ]; then
  FRIDA_TAG="${INPUT_VERSION}"
else
  FRIDA_TAG="$(curl -fsSL https://api.github.com/repos/frida/frida/releases/latest \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"])')"
fi
[ -z "${FRIDA_TAG}" ] && { err "could not resolve frida version"; exit 1; }
log "Frida version to build: ${FRIDA_TAG}"

# --- clone frida -------------------------------------------------------------
rm -rf "${WORK}/frida"
git clone https://github.com/frida/frida.git "${WORK}/frida"
cd "${WORK}/frida"
git checkout "${FRIDA_TAG}"
git submodule update --init --recursive --depth 1

# --- python venv + build deps ------------------------------------------------
python3 -m venv .venv
# shellcheck source=/dev/null
source .venv/bin/activate
python3 -m pip install --upgrade pip setuptools wheel
python3 -m pip install lief || echo "[build] lief install failed (anti-anti-frida symbol pass may be skipped)"

export PYTHON="$(command -v python3)"
export PYTHONWARNINGS=all

# --- packaging version string ------------------------------------------------
FRIDA_VERSION="$(releng/frida_version.py 2>/dev/null || echo "${FRIDA_TAG#v}")"
# frida_version.py may append commit distance for non-exact checkouts; keep base x.y.z
FRIDA_VERSION="$(echo "${FRIDA_VERSION}" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
export FRIDA_VERSION
log "FRIDA_VERSION=${FRIDA_VERSION}"

# --- apply Florida anti-detect patches ---------------------------------------
bash "${WORK}/scripts/apply-patches.sh" "${WORK}/frida" "${WORK}/patch-report.txt"

# --- configure + build: ios-arm64e (fat arm64 + arm64e), installed assets ----
# rootless prefix /var/jb/usr ; --host=ios-arm64e emits a fat arm64+arm64e binary.
log "configuring (host=ios-arm64e, prefix=/var/jb/usr)"
./configure \
  --prefix=/var/jb/usr \
  --host=ios-arm64e \
  -- \
  -Dfrida-core:assets=installed

NPROC=$(( $(/usr/sbin/sysctl -n hw.logicalcpu) + 1 ))
log "building with -j${NPROC}"
gmake -j"${NPROC}"

rm -rf "${WORK}/dist"
DESTDIR="${WORK}/dist" gmake -j"${NPROC}" install

# --- locate outputs ----------------------------------------------------------
SERVER="${WORK}/dist/var/jb/usr/bin/frida-server"
AGENT="${WORK}/dist/var/jb/usr/lib/frida/frida-agent.dylib"
if [ ! -f "${SERVER}" ]; then
  err "frida-server not found at ${SERVER}"
  find "${WORK}/dist" \( -name 'frida-server' -o -name 'frida-agent.dylib' \) | sed 's/^/  found: /'
  exit 2
fi
if [ ! -f "${AGENT}" ]; then
  err "frida-agent.dylib not found at ${AGENT}"
  find "${WORK}/dist" -name 'frida-agent.dylib' | sed 's/^/  found: /'
  exit 2
fi

log "server slices: $(lipo -archs "${SERVER}" 2>/dev/null)"
log "agent  slices: $(lipo -archs "${AGENT}" 2>/dev/null)"

# --- codesign (adhoc, preserve entitlements) ---------------------------------
codesign -vf -s "-" --preserve-metadata=entitlements --timestamp=none "${SERVER}"
codesign -vf -s "-" --preserve-metadata=entitlements --timestamp=none "${AGENT}"
log "codesign done"

# --- package rootless .deb (iphoneos-arm64e, /var/jb) ------------------------
mkdir -p "${WORK}/out"
DEB="${WORK}/out/frida_${FRIDA_VERSION}_iphoneos-arm64e.deb"
FRIDA_VERSION="${FRIDA_VERSION}" bash "${WORK}/tools/package-server-fruity.sh" \
  "iphoneos-arm64e" \
  "${WORK}/dist/var/jb" \
  "${DEB}"

echo "${FRIDA_VERSION}" > "${WORK}/out/FRIDA_VERSION.txt"
log "packaged: ${DEB}"
ls -la "${WORK}/out"
dpkg-deb -I "${DEB}" || true
dpkg-deb -c "${DEB}" || true
