#!/usr/bin/env bash
# Regression gates for the optimized Microsoft/Growth Mindset flavor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
assert_file() { local p="$1" n="$2"; [ -f "$ROOT/$p" ] && pass "$n" || fail "$n"; }
assert_grep() { local pat="$1" file="$2" n="$3"; grep -qE "$pat" "$ROOT/$file" && pass "$n" || fail "$n"; }
assert_not_grep() { local pat="$1" file="$2" n="$3"; ! grep -qE "$pat" "$ROOT/$file" && pass "$n" || fail "$n"; }

echo "=== Microsoft Flavor Gates ==="
assert_file skills/pua/references/methodology-microsoft.md "Microsoft methodology reference exists"
assert_grep 'microsoft|微软' hooks/flavor-helper.sh "flavor helper recognizes Microsoft aliases"
assert_grep 'methodology-microsoft\.md' hooks/flavor-helper.sh "flavor helper maps Microsoft methodology file"
assert_grep 'PUA_ICON="🪟"|PUA_ICON="🟦"' hooks/flavor-helper.sh "Microsoft flavor has icon"
assert_grep 'Growth Mindset|成长心态' skills/pua/references/methodology-microsoft.md "methodology anchors on growth mindset"
assert_grep 'impact evidence|影响证据|learning loop|学习闭环|AI fluency|AI 工具' skills/pua/references/methodology-microsoft.md "methodology uses low-risk evidence language"
assert_grep '🪟 Microsoft味|微软味' skills/pua/references/flavors.md "flavors reference includes Microsoft"
assert_grep '思维固化|拒绝成长|Fixed thinking|Microsoft' skills/pua/SKILL.md "core skill routes fixed-thinking failures to Microsoft"
assert_grep '14 Corporate Flavors|14 种大厂|14種の大企業' README.md "README English count updated to 14"
assert_grep '14 种大厂' README.zh-CN.md "README Chinese count updated to 14"
assert_grep '14種の大企業' README.ja.md "README Japanese count updated to 14"
assert_grep '14 种味道|14 corporate flavors|14 flavours|14 flavors' commands/flavor.md "flavor command count updated"
assert_grep '14 corporate methodologies|14 种企业方法论|14の企業メソドロジー' landing/src/i18n.ts "landing copy count updated"
# Keep optimized flavor away from high-risk factual/legal claims copied from the PR.
for file in hooks/flavor-helper.sh skills/pua/SKILL.md skills/pua/references/flavors.md skills/pua/references/methodology-microsoft.md README.md README.zh-CN.md README.ja.md; do
  assert_not_grep 'GVSA|RSU|two-year|两年|manager-only|经理可见|裁员通知|rehire ban|LITE|SLITE' "$file" "no high-risk Microsoft employment claims in $file"
done

echo "=============================="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo "Total:  $((PASS+FAIL))"
echo "=============================="
[ "$FAIL" -eq 0 ] || exit 1
