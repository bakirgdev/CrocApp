#!/usr/bin/env bash
# Enforces the three rules design/AGENTS.md leaves to a machine.
#
#   1. Mirror parity. design/tokens.css is canonical; DesignTokens.swift and the
#      asset catalog color sets are hand-written mirrors. Every shared value
#      must be equal in all three, every token must either be mirrored or
#      listed as deliberately not mirrored. The numeric half (spacing, radius,
#      control sizes, durations, curves) compares tokens.css with Swift
#      constants only, so it needs no value tables in the docs.
#   2. Contrast. Every ratio design/principles.md ("Contrast") claims is
#      recomputed from tokens.css (WCAG 2.x relative luminance, alpha
#      composited onto the surface underneath), and the contrast guidance holds
#      as invariants. Edit an olive step and this names the guidance you just
#      broke. The focus ring and the web manifest colors are checked too.
#   3. No raw colors in web code. Web CSS, HTML and scripts write color
#      tokens, not hex, rgb()/hsl() or named colors (design/implementation.md,
#      "Raw colors on web"). Swift is not linted: reviewers keep views on
#      tokens and text styles.
#
#   scripts/verify-design.sh           # findings as path:line: message, exit 1 on any
#   scripts/verify-design.sh --quiet   # findings and FAIL lines only, no OK lines
#
# Pure bash and awk on purpose: no toolchain, so CI runs it on a bare runner.
# The awk programs live in scripts/verify-design/ (common.awk, then one file per
# phase); the tables they read stay here and travel as exported variables.
# Only POSIX awk features are used (BSD awk on macOS, mawk on the Ubuntu
# runner): no interval expressions, no gawk extensions.
# Exit 0 clean, 1 findings, 2 usage or unreadable input.
set -euo pipefail
cd "$(dirname "$0")/.."
. scripts/lib.sh
help_flag "$@"

QUIET=0
case "${1-}" in
  --quiet) QUIET=1 ;;
  "") ;;
  *)
    echo "usage: $0 [--quiet]" >&2
    exit 2
    ;;
esac
export LC_ALL=C

TOKENS=design/tokens.css
SWIFT_TOKENS=app/CrocApp/Support/DesignTokens.swift
COLORSETS=app/CrocApp/Assets.xcassets
PRINCIPLES_MD=design/principles.md
MANIFEST=web/landing/assets/img/favicon/site.webmanifest
[ -r "$TOKENS" ] || {
  echo "FAIL: $TOKENS not readable" >&2
  exit 2
}
[ -r "$SWIFT_TOKENS" ] || {
  echo "FAIL: $SWIFT_TOKENS not readable" >&2
  exit 2
}
[ -r "$PRINCIPLES_MD" ] || {
  echo "FAIL: $PRINCIPLES_MD not readable" >&2
  exit 2
}
[ -r "$MANIFEST" ] || {
  echo "FAIL: $MANIFEST not readable" >&2
  exit 2
}
[ -d "$COLORSETS" ] || {
  echo "FAIL: $COLORSETS not a directory" >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Parity table: numeric and curve tokens. token|Swift Enum.constant[|curve]
#
# Values compare after unit normalization: px is dropped, ms becomes seconds,
# cubic-bezier(a, b, c, d) is compared to .timingCurve(a, b, c, d, ...).
# Add a shared token here (or to the not-mirrored block) in the same commit
# that adds it to tokens.css: design/AGENTS.md -> Adding or removing a token.
# ---------------------------------------------------------------------------
NUMERIC_TABLE='
--space-1|Spacing.space1
--space-2|Spacing.space2
--space-3|Spacing.space3
--space-4|Spacing.space4
--space-5|Spacing.space5
--space-6|Spacing.space6
--space-7|Spacing.space7
--space-8|Spacing.space8
--space-9|Spacing.space9
--space-10|Spacing.space10
--space-11|Spacing.space11
--radius-xs|Radius.xs
--radius-sm|Radius.sm
--radius-md|Radius.md
--radius-lg|Radius.lg
--radius-xl|Radius.xl
--radius-2xl|Radius.xxl
--radius-capsule|Radius.capsule
--border-hairline|BorderWidth.hairline
--border-hairline-half|BorderWidth.hairlineHalf
--control-height-lg|ControlHeight.large
--control-height-md|ControlHeight.medium
--control-height-sm|ControlHeight.small
--hit-target-min|ControlHeight.hitTargetMin
--icon-size-sm|IconSize.small
--icon-size-md|IconSize.medium
--icon-size-lg|IconSize.large
--content-max-width|LayoutCap.contentMaxWidth
--opacity-disabled-container|Opacity.disabledContainer
--dur-fast|Motion.durationFast
--dur-base|Motion.durationBase
--dur-slow|Motion.durationSlow
--tracking-code|Tracking.code
--tracking-eyebrow|Tracking.eyebrow
--ease-out|Motion.easeOut|curve
--ease-standard|Motion.easeStandard|curve
'

# ---------------------------------------------------------------------------
# Parity table: color sets. ColorSetName|token. Each is resolved through
# var() and light-dark() for both themes and compared with the set's "any"
# (light) and "dark" appearances: 1/255 per channel, 0.01 alpha. A set with no
# dark appearance must have a token whose two themes are equal.
# ---------------------------------------------------------------------------
COLOR_TABLE='
AccentColor|--color-accent
ColorAccentSolid|--color-accent-solid
ColorAccentPressed|--color-accent-pressed
ColorAccentTint|--color-accent-tint
ColorAccentText|--color-accent-text
ColorAccentTextOnTint|--color-accent-text-on-tint
ColorOnAccent|--color-on-accent
ColorPaper|--paper
ColorTextSecondary|--color-text-secondary
ColorScrim|--color-scrim
ColorStatusSuccessTint|--color-status-success-tint
ColorStatusWarningTint|--color-status-warning-tint
ColorStatusErrorTint|--color-status-error-tint
ColorStatusInfoTint|--color-status-info-tint
'

# ---------------------------------------------------------------------------
# Not mirrored: shared token names (no `web` segment) the app deliberately has
# no Swift form for. One ERE per line, anchored. Source: design/implementation.md,
# "Not mirrored", plus the semantic aliases it routes to system semantics (text, status, surface, separator). A token that matches
# neither this block nor a table above fails the check, so a new shared token
# forces the mirror decision in the same commit.
# ---------------------------------------------------------------------------
NOT_MIRRORED='
^--(olive|khaki)-
^--sys-
^--label-
^--fill-
^--bg-
^--separator
^--glass-
^--blur-
^--color-surface-
^--color-glass-border$
^--shadow-
^--type-
^--weight-
^--font-
^--tracking-
^--icon-stroke
^--color-text-(primary|tertiary|quaternary|link)$
^--color-fill
^--color-separator$
^--color-border-control$
^--color-on-status$
^--color-status-(success|warning|error|info)$
'

# ---------------------------------------------------------------------------
# Contrast table. Above the first marker: every row design/principles.md asserts,
# as theme|foreground|background stack|expected. The stack composites front to
# back, so a translucent tint names the opaque surface under it. Each expected
# ratio must also appear in the Contrast section of design/principles.md: keep
# the two in step. Below the first marker: rules that must hold whatever the values
# are, as label|theme|foreground|stack|min or max|threshold. Below the second
# marker: alias rules, label|theme|token|target, true when the token resolves
# to the same color as the target in that theme. The focus ring bands (rule 7)
# are parsed from --shadow-focus-ring, not listed here.
# ---------------------------------------------------------------------------
CONTRAST_TABLE='
light|--color-accent|--color-surface-base|4.06
light|--color-accent|--color-surface-grouped|3.63
light|--color-accent|--color-accent-tint>--color-surface-base|3.54
light|--color-accent-text|--color-surface-base|5.84
light|--color-accent-text|--color-surface-grouped|5.23
light|--color-accent-text|--color-accent-tint>--color-surface-base|5.09
light|--color-accent-text|--color-surface-card|5.84
light|--color-accent-text|--color-fill-tertiary>--color-surface-base|5.06
light|--color-accent-text-on-tint|--color-fill-tertiary>--color-surface-base|6.54
light|--color-accent-text-on-tint|--color-surface-base|7.54
light|--color-accent-text-on-tint|--color-surface-grouped|6.76
light|--color-accent-text-on-tint|--color-accent-tint>--color-surface-base|6.58
light|--label-2|--color-surface-base|3.44
light|--label-2-text|--color-surface-base|5.63
light|--label-2-text|--color-surface-grouped|5.26
light|--label-2|--color-surface-grouped|3.30
light|--color-border-control|--color-surface-base|3.44
light|--color-border-control|--color-surface-grouped|3.30
light|--color-text-secondary|--color-accent-tint>--color-surface-base|5.17
light|--color-text-secondary|--color-fill-tertiary>--color-surface-grouped|4.83
light|--color-text-secondary|--color-status-error-tint>--color-surface-grouped|4.70
light|--label-3|--color-surface-base|1.73
light|--color-on-accent|--color-accent-solid|5.84
light|--color-on-accent|--color-accent-pressed|7.54
light|--color-on-status|--color-status-error|3.55
light|--color-status-success|--color-status-success-tint>--color-surface-base|1.98
light|--color-status-warning|--color-status-warning-tint>--color-surface-base|1.96
light|--color-status-error|--color-status-error-tint>--color-surface-base|2.94
light|--color-status-success|--color-surface-base|2.22
light|--color-status-warning|--color-surface-base|2.20
light|--color-status-error|--color-surface-base|3.55
light|--color-status-info|--color-surface-base|4.02
light|--glass-tint-accent|--color-surface-base|1.14
dark|--color-accent|--color-surface-base|9.62
dark|--color-accent|--color-surface-card|7.80
dark|--color-accent|--color-accent-tint>--color-surface-base|7.81
dark|--color-on-accent|--color-accent-solid|5.99
dark|--color-on-accent|--color-accent-pressed|7.13
dark|--color-on-status|--color-status-error|3.41
dark|--label-2|--color-surface-base|6.36
dark|--color-border-control|--color-surface-base|6.36
dark|--color-text-secondary|--color-surface-card|5.95
dark|--color-text-secondary|--color-status-success-tint>--color-surface-card|4.74
dark|--color-status-success|--color-status-success-tint>--color-surface-base|8.05
dark|--color-status-warning|--color-status-warning-tint>--color-surface-base|7.93
dark|--color-status-error|--color-status-error-tint>--color-surface-base|5.25
dark|--color-status-info|--color-status-info-tint>--color-surface-base|4.92
== invariants ==
accent fill clears 3:1 on base|light|--color-accent|--color-surface-base|min|3.0
accent-text clears AA on base|light|--color-accent-text|--color-surface-base|min|4.5
accent-text-on-tint clears AA on grouped|light|--color-accent-text-on-tint|--color-surface-grouped|min|4.5
accent-text-on-tint clears AA on tint|light|--color-accent-text-on-tint|--color-accent-tint>--color-surface-base|min|4.5
secondary text clears AA on grouped|light|--label-2-text|--color-surface-grouped|min|4.5
filled prominent clears AA, light|light|--color-on-accent|--color-accent-solid|min|4.5
filled prominent clears AA, dark|dark|--color-on-accent|--color-accent-solid|min|4.5
filled prominent pressed clears AA, light|light|--color-on-accent|--color-accent-pressed|min|4.5
filled prominent pressed clears AA, dark|dark|--color-on-accent|--color-accent-pressed|min|4.5
accent-text-on-tint clears AA on a fill-tertiary wash (link in code or table)|light|--color-accent-text-on-tint|--color-fill-tertiary>--color-surface-base|min|4.5
filled destructive clears 3:1, light|light|--color-on-status|--color-status-error|min|3.0
filled destructive clears 3:1, dark|dark|--color-on-status|--color-status-error|min|3.0
focus ring outer band clears 3:1 on base|light|--color-accent|--color-surface-base|min|3.0
focus ring inner band clears 3:1 on the accent solid fill|light|--color-surface-base|--color-accent-solid|min|3.0
tertiary is NOT a usable text color|light|--label-3|--color-surface-base|max|3.0
secondary text clears AA on the accent tint (rule 4)|light|--color-text-secondary|--color-accent-tint>--color-surface-base|min|4.5
secondary text clears AA on a success tint over grouped (rule 4)|light|--color-text-secondary|--color-status-success-tint>--color-surface-grouped|min|4.5
secondary text clears AA on a warning tint over grouped (rule 4)|light|--color-text-secondary|--color-status-warning-tint>--color-surface-grouped|min|4.5
secondary text clears AA on an error tint over grouped (rule 4)|light|--color-text-secondary|--color-status-error-tint>--color-surface-grouped|min|4.5
secondary text clears AA on an info tint over grouped (rule 4)|light|--color-text-secondary|--color-status-info-tint>--color-surface-grouped|min|4.5
secondary text clears AA on the fill-tertiary wash over grouped (rule 4)|light|--color-text-secondary|--color-fill-tertiary>--color-surface-grouped|min|4.5
secondary text clears AA on a success tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-success-tint>--color-surface-card|min|4.5
secondary text clears AA on a warning tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-warning-tint>--color-surface-card|min|4.5
secondary text clears AA on an error tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-error-tint>--color-surface-card|min|4.5
secondary text clears AA on an info tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-status-info-tint>--color-surface-card|min|4.5
secondary text clears AA on the accent tint over a card, dark (rule 4)|dark|--color-text-secondary|--color-accent-tint>--color-surface-card|min|4.5
the system secondary label clears the 3:1 glyph floor on grouped (rule 4)|light|--label-2|--color-surface-grouped|min|3.0
the system secondary label is NOT text on grouped (rule 4)|light|--label-2|--color-surface-grouped|max|4.5
a text field border clears 3:1 on grouped (rule 8)|light|--color-border-control|--color-surface-grouped|min|3.0
a text field border clears 3:1 on base, dark (rule 8)|dark|--color-border-control|--color-surface-base|min|3.0
accent-text clears AA on a card|light|--color-accent-text|--color-surface-card|min|4.5
accent-text clears AA on grouped|light|--color-accent-text|--color-surface-grouped|min|4.5
accent-text clears AA on the accent tint|light|--color-accent-text|--color-accent-tint>--color-surface-base|min|4.5
accent-text clears AA on a fill-tertiary wash|light|--color-accent-text|--color-fill-tertiary>--color-surface-base|min|4.5
the accent tint is NOT a visible focus indicator (rule 7)|light|--glass-tint-accent|--color-surface-base|max|1.5
dark status success clears AA on its own tint|dark|--color-status-success|--color-status-success-tint>--color-surface-base|min|4.5
dark status warning clears AA on its own tint|dark|--color-status-warning|--color-status-warning-tint>--color-surface-base|min|4.5
dark status error clears AA on its own tint|dark|--color-status-error|--color-status-error-tint>--color-surface-base|min|4.5
dark status info clears AA on its own tint|dark|--color-status-info|--color-status-info-tint>--color-surface-base|min|4.5
== aliases ==
rule 4: secondary text is label-2-text, light|light|--color-text-secondary|--label-2-text
rule 4: secondary text is label-2-text, dark|dark|--color-text-secondary|--label-2-text
rule 6: link is accent-text, light|light|--color-text-link|--color-accent-text
rule 6: link is accent-text, dark|dark|--color-text-link|--color-accent-text
dark accent collapses to olive-400|dark|--color-accent|--olive-400
dark accent-solid collapses to olive-400|dark|--color-accent-solid|--olive-400
light accent-solid is olive-700, the step white clears AA on|light|--color-accent-solid|--olive-700
dark accent-text collapses to olive-400|dark|--color-accent-text|--olive-400
dark accent-text-on-tint collapses to olive-400|dark|--color-accent-text-on-tint|--olive-400
'

# ---------------------------------------------------------------------------
# Web raw-color allowlist. path ERE @@ source-line ERE @@ reason. A finding is
# suppressed only when both match, so an allowance cannot silently widen to a
# whole file. Never suppress with a comment in CSS: add a row here.
# ---------------------------------------------------------------------------
ALLOW_WEB='
'

WEB_FILES=$(
  for f in web/landing/styles.css web/docs/src/css/custom.css web/landing/app.js web/landing/theme-init.js web/landing/r/receive.js web/docs/src/prismTheme.ts; do
    [ -r "$f" ] || {
      echo "FAIL: $f not readable" >&2
      exit 2
    }
    echo "$f"
  done
  find web/landing -name '*.html' | sort
)

export TOKENS SWIFT_TOKENS COLORSETS PRINCIPLES_MD MANIFEST NUMERIC_TABLE COLOR_TABLE CONTRAST_TABLE NOT_MIRRORED \
  ALLOW_WEB WEB_FILES
export QUIET

# One awk program per phase, in scripts/verify-design/, after the helpers in
# common.awk. Inputs travel through the exported variables above because a
# literal newline cannot pass through `awk -v`.
status=0
run_phase() { # run_phase NAME
  local rc=0
  awk -f scripts/verify-design/common.awk -f "scripts/verify-design/$1.awk" < /dev/null || rc=$?
  if [ "$rc" -ge 2 ]; then exit 2; fi
  if [ "$rc" -ne 0 ]; then status=1; fi
}

run_phase parity
run_phase contrast
run_phase web

if [ "$status" -ne 0 ]; then
  echo
  echo "FAIL: fix the code, or update design/ and its mirrors together. Never weaken the check."
  exit 1
fi
if [ "$QUIET" -eq 0 ]; then echo "OK: mirrors match design/tokens.css, every contrast ratio holds and no raw colors in web code"; fi
