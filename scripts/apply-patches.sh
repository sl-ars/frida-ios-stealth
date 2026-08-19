#!/usr/bin/env bash
#
# Clone Ylarod/Florida (pinned) and apply its frida-core / frida-gum source
# patches to a frida checkout. Non-applicable patches are logged, not fatal.
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
    if patch -p1 -d "${target}" --forward --batch -r - < "${p}" >/dev/null 2>&1; then
      echo "APPLIED                   ${name}" >> "${REPORT}"
    elif patch -p1 -d "${target}" --reverse --batch --dry-run -r - < "${p}" >/dev/null 2>&1; then
      echo "SKIPPED(already-applied)  ${name}" >> "${REPORT}"
    else
      echo "SKIPPED(does-not-apply)   ${name}" >> "${REPORT}"
    fi
  done
  shopt -u nullglob
}

apply_dir "frida-core" "subprojects/frida-core"
apply_dir "frida-gum"  "subprojects/frida-gum"

{
  echo
  echo "# NOTE: patches touching linux/*, droidy/*, memfd (Linux/Android code paths)"
  echo "#       still apply to files present in the tree but have no effect on the"
  echo "#       iOS/Darwin server. anti-anti-frida.py symbol pass is ELF-oriented and"
  echo "#       is invoked only on the non-Darwin embed path; on iOS it is a no-op."
} >> "${REPORT}"

echo "=== patch report ==="
cat "${REPORT}"
