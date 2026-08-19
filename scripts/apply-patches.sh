#!/usr/bin/env bash
#
# Clone Ylarod/Florida (pinned) and apply its frida-core / frida-gum source
# patches to a frida checkout.
#
# IMPORTANT: application is ATOMIC per patch. GNU patch applies hunks
# independently by default, so a patch whose method-definition hunk fails but
# whose call-site hunks succeed leaves the source half-edited and unbuildable
# (this bit us on rpc.vala). We gate every real apply behind a full --dry-run:
# only if ALL hunks apply do we write; otherwise the file is left pristine and
# the patch is logged as skipped. Non-applicable patches never break the build.
#
set -uo pipefail

FRIDA_ROOT="${1:?frida root required}"
REPORT="${2:-${FRIDA_ROOT}/../patch-report.txt}"
WORK="$(dirname "${FRIDA_ROOT}")"

# Pin Florida to a known commit for reproducibility.
FLORIDA_SHA="6d4b2e88ebe2bace12322db93470b0e68d4240c9"

: > "${REPORT}"
{
  echo "# Florida patch report  (frida root: ${FRIDA_ROOT})"
  echo "# Florida pinned: ${FLORIDA_SHA}"
  echo
} >> "${REPORT}"

rm -rf "${WORK}/florida-src"
git clone --quiet https://github.com/Ylarod/Florida "${WORK}/florida-src"
git -C "${WORK}/florida-src" checkout --quiet "${FLORIDA_SHA}" \
  || echo "WARN: could not pin Florida to ${FLORIDA_SHA}, using default branch" >> "${REPORT}"
PATCH_ROOT="${WORK}/florida-src/patches"

apply_dir() {
  local sub="$1" dir="$2"
  local target="${FRIDA_ROOT}/${dir}"
  if [ ! -d "${target}" ]; then
    echo "MISSING-TARGET  ${dir}  (submodule not checked out?)" >> "${REPORT}"
    return
  fi
  shopt -s nullglob
  for p in "${PATCH_ROOT}/${sub}"/*.patch; do
    local name="${sub}/$(basename "${p}")"
    if patch -p1 -d "${target}" --forward --batch --dry-run -r - < "${p}" >/dev/null 2>&1; then
      # All hunks apply cleanly -> safe to write for real.
      if patch -p1 -d "${target}" --forward --batch -r - < "${p}" >/dev/null 2>&1; then
        echo "APPLIED                   ${name}" >> "${REPORT}"
      else
        echo "ERROR-DURING-APPLY        ${name}" >> "${REPORT}"
      fi
    elif patch -p1 -d "${target}" --reverse --batch --dry-run -r - < "${p}" >/dev/null 2>&1; then
      echo "SKIPPED(already-applied)  ${name}" >> "${REPORT}"
    else
      # Do NOT write anything: leaves the tree pristine and buildable.
      echo "SKIPPED(does-not-apply)   ${name}" >> "${REPORT}"
    fi
  done
  shopt -u nullglob
}

apply_dir "frida-core" "subprojects/frida-core"
apply_dir "frida-gum"  "subprojects/frida-gum"

{
  echo
  echo "# Patches touching linux/*, droidy/*, memfd (Linux/Android code paths) may"
  echo "# apply to files present in the tree but those files are not compiled into"
  echo "# the iOS/Darwin server. The anti-anti-frida.py symbol pass is ELF-oriented"
  echo "# and only runs on the non-Darwin embed path; on iOS it is effectively a no-op."
} >> "${REPORT}"

echo "=== patch report ==="
cat "${REPORT}"
