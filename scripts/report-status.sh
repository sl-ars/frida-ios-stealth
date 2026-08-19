#!/usr/bin/env bash
#
# Self-report build status back into the repository on an orphan branch
# `ci-status` (files status.md + build-tail.log), so an operator driving this
# via the GitHub MCP (which lacks Actions log access) can read run outcomes
# with get_file_contents(ref=ci-status). Does not trigger CI (branch filtered).
#
set -uo pipefail

STATUS="${1:-unknown}"
WORK="${GITHUB_WORKSPACE:-$(pwd)}"

TMP="$(mktemp -d)"

# Log tail, capped to keep get_file_contents readable.
if [ -f "${WORK}/build.log" ]; then
  tail -c 120000 "${WORK}/build.log" > "${TMP}/build-tail.log"
else
  echo "no build.log produced" > "${TMP}/build-tail.log"
fi

{
  echo "# CI build status"
  echo
  echo "- status: **${STATUS}**"
  echo "- frida_version: $(cat "${WORK}/out/FRIDA_VERSION.txt" 2>/dev/null || echo unknown)"
  echo "- commit: ${GITHUB_SHA:-?}"
  echo "- run: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-?}/actions/runs/${GITHUB_RUN_ID:-?}"
  echo "- utc: $(date -u +%FT%TZ)"
  echo
  echo "## deb artifacts"
  echo '```'
  ls -la "${WORK}/out" 2>/dev/null || echo "no out/ dir"
  echo '```'
  echo
  echo "## patch report"
  echo '```'
  cat "${WORK}/patch-report.txt" 2>/dev/null || echo "no patch report"
  echo '```'
  echo
  echo "_full tail in build-tail.log on this branch_"
} > "${TMP}/status.md"

cd "${WORK}"
git config user.name "ci-bot"
git config user.email "ci-bot@users.noreply.github.com"

# Build a clean orphan branch containing only the two report files.
git checkout --orphan ci-status 2>/dev/null || { git branch -D ci-status 2>/dev/null; git checkout --orphan ci-status; }
git rm -rf . >/dev/null 2>&1 || true
cp "${TMP}/status.md" ./status.md
cp "${TMP}/build-tail.log" ./build-tail.log
git add status.md build-tail.log
git commit -m "ci: status ${STATUS} [skip ci]" >/dev/null 2>&1 || true

if git push -f origin ci-status >/dev/null 2>&1; then
  echo "[report] pushed ci-status (origin)"
elif [ -n "${GH_TOKEN:-}" ]; then
  git push -f "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" HEAD:ci-status \
    && echo "[report] pushed ci-status (token)"
else
  echo "[report] FAILED to push ci-status"
fi
