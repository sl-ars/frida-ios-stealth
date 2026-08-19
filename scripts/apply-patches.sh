#!/usr/bin/env bash
#
# Apply anti-detect source patches to a frida checkout, from two sources:
#   1. Ylarod/Florida (pinned)      -> upstream Florida patch set
#   2. this repo's patches-ios/      -> patches re-derived for the current frida
#                                       (e.g. rpc string obfuscation ported to 17.x)
#
# Application is ATOMIC per patch. GNU patch applies hunks independently by
# default, so a patch whose method-definition hunk fails but whose call-site
# hunks succeed leaves the source half-edited and unbuildable (this bit us on
# rpc.vala). We gate every real apply behind a full --dry-run: only if ALL hunks
# apply do we write; otherwise the file is left pristine and the patch is logged
# as skipped. Non-applicable patches never break the build.
#
set -uo pipefail

FRIDA_ROOT="${1:?frida root required}"
REPORT="${2:-${FRIDA_ROOT}/../patch-report.txt}"
LOCAL_PATCH_ROOT="${3:-}"
WORK="$(dirname "${FRIDA_ROOT}")"

# Pin Florida to a known commit for reproducibility.
FLORIDA_SHA="6d4b2e88ebe2bace12322db93470b0e68d4240c9"

: > "${REPORT}"
{
  echo "# patch report  (frida root: ${FRIDA_ROOT})"
  echo "# Florida pinned: ${FLORIDA_SHA}"
  echo
} >> "${REPORT}"

rm -rf "${WORK}/florida-src"
git clone --quiet https://github.com/Ylarod/Florida "${WORK}/florida-src"
git -C "${WORK}/florida-src" checkout --quiet "${FLORIDA_SHA}" \
  || echo "WARN: could not pin Florida to ${FLORIDA_SHA}, using default branch" >> "${REPORT}"
FLORIDA_PATCH_ROOT="${WORK}/florida-src/patches"

# apply_one <patch-root> <subdir> <target-subdir-in-frida> <tag>
apply_one() {
  local proot="$1" sub="$2" dir="$3" tag="$4"
  local target="${FRIDA_ROOT}/${dir}"
  [ -d "${proot}/${sub}" ] || return 0
  if [ ! -d "${target}" ]; then
    echo "MISSING-TARGET  [${tag}] ${dir}" >> "${REPORT}"
    return 0
  fi
  shopt -s nullglob
  for p in "${proot}/${sub}"/*.patch; do
    local name="[${tag}] ${sub}/$(basename "${p}")"
    if patch -p1 -d "${target}" --forward --batch --dry-run -r - < "${p}" >/dev/null 2>&1; then
      if patch -p1 -d "${target}" --forward --batch -r - < "${p}" >/dev/null 2>&1; then
        echo "APPLIED                   ${name}" >> "${REPORT}"
      else
        echo "ERROR-DURING-APPLY        ${name}" >> "${REPORT}"
      fi
    elif patch -p1 -d "${target}" --reverse --batch --dry-run -r - < "${p}" >/dev/null 2>&1; then
      echo "SKIPPED(already-applied)  ${name}" >> "${REPORT}"
    else
      echo "SKIPPED(does-not-apply)   ${name}" >> "${REPORT}"
    fi
  done
  shopt -u nullglob
}

# 1) Florida upstream set
apply_one "${FLORIDA_PATCH_ROOT}" "frida-core" "subprojects/frida-core" "florida"
apply_one "${FLORIDA_PATCH_ROOT}" "frida-gum"  "subprojects/frida-gum"  "florida"

# 2) iOS-adapted patches shipped in this repo (applied after Florida, so they
#    land on pristine files when the matching Florida patch did not apply).
if [ -n "${LOCAL_PATCH_ROOT}" ] && [ -d "${LOCAL_PATCH_ROOT}" ]; then
  apply_one "${LOCAL_PATCH_ROOT}" "frida-core" "subprojects/frida-core" "ios"
  apply_one "${LOCAL_PATCH_ROOT}" "frida-gum"  "subprojects/frida-gum"  "ios"
fi

{
  echo
  echo "# Patches touching linux/*, droidy/*, memfd (Linux/Android code paths) may"
  echo "# apply to files present in the tree but those files are not compiled into"
  echo "# the iOS/Darwin server. The anti-anti-frida.py symbol pass is ELF-oriented"
  echo "# and only runs on the non-Darwin embed path; on iOS it is effectively a no-op."
  echo "# [ios] patches are re-derived for the current frida and carry the real"
  echo "# iOS-relevant anti-detect edits (e.g. rpc-string obfuscation)."
} >> "${REPORT}"

echo "=== patch report ==="
cat "${REPORT}"
