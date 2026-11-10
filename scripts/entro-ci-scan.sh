#!/usr/bin/env bash
# Scans a list of files with the Entro CLI.
# Usage: scripts/entro-ci-scan.sh <file-with-one-path-per-line>
# ENTRO_FAIL_MODE:
#   block (default) — exit 1 when a secret is found. Annotations are errors.
#   warn            — still scan, annotate, and summarize, but exit 0 so the PR can merge.
# Authentication and scan-tooling failures exit 1 in both modes.
set -uo pipefail

list_file="${1:?usage: $0 <file-list>}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

fail_mode="${ENTRO_FAIL_MODE:-block}"
case "$fail_mode" in
  warn|block) ;;
  *)
    echo "::error::ENTRO_FAIL_MODE must be warn or block (got: ${fail_mode})."
    exit 1
    ;;
esac
echo "Entro fail mode: ${fail_mode}"

scanned=0
files_with_secrets=0
rows=""

# The CLI published by the install script scans with `entro scan <file>` and reports "Exposed Secrets: 0" when clean. Newer builds (e.g. 2.x) use `entro scan path <file>` and a --fail-on-findings flag. Detect which one we have.
if entro scan --help 2>&1 | grep -q -- '--fail-on-findings'; then
  scan_mode=modern
else
  scan_mode=legacy
fi
echo "Entro CLI scan mode: ${scan_mode}"

while IFS= read -r file; do
  [ -n "$file" ] && [ -f "$file" ] || continue
  scanned=$((scanned + 1))
  echo "🔎 Scanning: $file"

  if [ "$scan_mode" = modern ]; then
    # --fail-on-findings is the hard-block signal. Warn mode omits it and reads the report.
    if [ "$fail_mode" = block ]; then
      out=$(entro scan path "$file" --generic --fail-on-findings 2>&1)
    else
      out=$(entro scan path "$file" --generic 2>&1)
    fi
    rc=$?
    if printf '%s' "$out" | grep -q 'failed to validate credentials\|the provided token is invalid'; then
      echo "$out"
      echo "::error::Entro CLI could not authenticate. Check ENTRO_SECURITY_PLATFORM_TOKEN."
      exit 1
    fi
    if [ "$fail_mode" = block ]; then
      # A zero exit means the scan ran and found nothing.
      [ "$rc" -eq 0 ] && continue
    else
      # Without the flag, a non-zero exit is a tooling failure, not a finding.
      if [ "$rc" -ne 0 ]; then
        echo "$out"
        echo "::error::Entro CLI scan failed for ${file} (exit ${rc})."
        exit 1
      fi
      printf '%s' "$out" | grep -q 'No Exposed Secrets' && continue
    fi
  else
    out=$(entro scan "$file" --generic 2>&1)
    rc=$?
    # Legacy builds exit 0 even when they find secrets, so the summary line decides.
    [[ "$out" == *"Exposed Secrets: 0"* ]] && continue
  fi

  files_with_secrets=$((files_with_secrets + 1))
  echo "::group::❌ Exposed secrets in $file"
  echo "$out"
  echo "::endgroup::"

  # Pull type/line pairs out of whichever report format the CLI printed.
  findings=$(printf '%s' "$out" | python3 -c '
import json, re, sys
text = sys.stdin.read().replace("\r", "")
text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)
origin = None
for raw in text.splitlines():
    m = re.search(r"Secret:\s*(.+?)\s*$", raw)
    if m:
        origin = m.group(1)
        continue
    m = re.search(r"Line:\s*(\d+)", raw)
    if m and origin:
        print("%s\t%s" % (origin, m.group(1)))
        origin = None
start = text.find("{")
if start != -1:
    try:
        data, _ = json.JSONDecoder().raw_decode(text[start:])
    except Exception:
        data = None
    if isinstance(data, dict):
        for item in data.get("exposed_secrets") or []:
            for r in (item.get("scan_result") or {}).get("results") or []:
                print("%s\t%s" % (r.get("origin", "UNKNOWN"), r.get("line", 1)))
')

  annotation=error
  [ "$fail_mode" = warn ] && annotation=warning

  if [ -n "$findings" ]; then
    while IFS=$'\t' read -r origin line; do
      echo "::${annotation} file=${file},line=${line},title=Entro: exposed secret::${origin} detected in ${file}"
      rows+="| \`${file}\` | ${line} | ${origin} |"$'\n'
    done <<< "$findings"
  else
    echo "::${annotation} file=${file},title=Entro: exposed secret::Exposed secret(s) detected in ${file} (exit code ${rc})"
    rows+="| \`${file}\` | - | (see log) |"$'\n'
  fi
done < "$list_file"

{
  echo "## 🔐 Entro Secret Scan"
  echo
  echo "- Fail mode: **${fail_mode}**"
  echo "- Files scanned: **${scanned}**"
  echo "- Files with exposed secrets: **${files_with_secrets}**"
  if [ "$fail_mode" = warn ] && [ "$files_with_secrets" -gt 0 ]; then
    echo "- Result: **Secrets detected, not blocking**"
  fi
  if [ -n "$rows" ]; then
    echo
    echo "| File | Line | Secret type |"
    echo "| --- | --- | --- |"
    printf '%s' "$rows"
  fi
} >> "$summary"

echo
echo "✅ Scan Completed!"
echo "📂 Total Scanned Files: ${scanned}"
echo "🚨 Files Containing Exposed Secrets: ${files_with_secrets}"

if [ "$files_with_secrets" -gt 0 ]; then
  if [ "$fail_mode" = block ]; then
    echo "❌ Failing the build: exposed secrets found."
    exit 1
  fi
  echo "⚠️ Secrets detected. Fail mode is warn, so the check does not block."
  exit 0
fi
echo "✅ No exposed secrets found."
