#!/usr/bin/env python3
"""Recompute every contrast ratio design/colors.md claims, from design/tokens.css.

The Contrast table and the seven rules that follow it are the binding part of
the design system. They were hand-computed once. This makes them checkable:
edit a green step, run this, find out immediately which rule you just broke.

    scripts/verify-contrast.py            # table + pass/fail, exit 1 on drift
    scripts/verify-contrast.py --quiet    # exit code only

Values come from design/tokens.css, never from a copy. Ratios are WCAG 2.x
relative luminance, alpha composited onto the surface underneath.
"""

import argparse
import re
import sys
from pathlib import Path

TOKENS = Path(__file__).resolve().parent.parent / "design" / "tokens.css"
TOLERANCE = 0.01

# Every row design/colors.md asserts: (theme, foreground, background stack, expected).
# The background stack composites left to right, so a translucent tint names the
# opaque surface it sits on. Keep this list and the markdown table in step.
CASES = [
    ("light", "--color-accent", ["--color-surface-base"], 3.41),
    ("light", "--color-accent", ["--color-surface-grouped"], 3.06),
    ("light", "--color-accent", ["--color-accent-tint", "--color-surface-base"], 2.99),
    ("light", "--color-accent-text", ["--color-surface-base"], 4.94),
    ("light", "--color-accent-text", ["--color-surface-grouped"], 4.42),
    ("light", "--color-accent-text", ["--color-accent-tint", "--color-surface-base"], 4.32),
    ("light", "--color-accent-text-on-tint", ["--color-surface-base"], 7.36),
    ("light", "--color-accent-text-on-tint", ["--color-surface-grouped"], 6.60),
    ("light", "--color-accent-text-on-tint", ["--color-accent-tint", "--color-surface-base"], 6.45),
    ("light", "--label-2", ["--color-surface-base"], 3.44),
    ("light", "--label-2-web", ["--color-surface-base"], 5.16),
    ("light", "--label-2-web", ["--color-surface-grouped"], 4.85),
    ("light", "--label-3", ["--color-surface-base"], 1.73),
    ("light", "--color-on-accent", ["--color-accent"], 3.41),
    ("light", "--color-on-status", ["--color-status-error"], 3.55),
    ("light", "--color-status-success", ["--color-status-success-tint", "--color-surface-base"], 1.98),
    ("light", "--color-status-warning", ["--color-status-warning-tint", "--color-surface-base"], 1.96),
    ("light", "--color-status-error", ["--color-status-error-tint", "--color-surface-base"], 2.94),
    ("light", "--color-status-success", ["--color-surface-base"], 2.22),
    ("light", "--color-status-warning", ["--color-surface-base"], 2.20),
    ("light", "--color-status-error", ["--color-surface-base"], 3.55),
    ("light", "--color-status-info", ["--color-surface-base"], 4.02),
    ("dark", "--color-accent", ["--color-surface-base"], 9.44),
    ("dark", "--color-accent", ["--color-surface-card"], 7.65),
    ("dark", "--color-accent", ["--color-accent-tint", "--color-surface-base"], 7.72),
    ("dark", "--color-on-accent", ["--color-accent"], 7.19),
    ("dark", "--color-on-status", ["--color-status-error"], 3.41),
    ("dark", "--label-2", ["--color-surface-base"], 6.36),
]

# Rules that must hold whatever the values are. Checked after the table.
# (label, theme, fg, bg stack, comparison, threshold)
INVARIANTS = [
    ("accent fill clears 3:1 on base", "light", "--color-accent", ["--color-surface-base"], "min", 3.0),
    ("accent-text clears AA on base", "light", "--color-accent-text", ["--color-surface-base"], "min", 4.5),
    ("accent-text-on-tint clears AA on grouped", "light", "--color-accent-text-on-tint", ["--color-surface-grouped"], "min", 4.5),
    ("accent-text-on-tint clears AA on tint", "light", "--color-accent-text-on-tint", ["--color-accent-tint", "--color-surface-base"], "min", 4.5),
    ("web secondary clears AA on grouped", "light", "--label-2-web", ["--color-surface-grouped"], "min", 4.5),
    ("filled prominent clears 3:1", "light", "--color-on-accent", ["--color-accent"], "min", 3.0),
    ("filled destructive clears 3:1, light", "light", "--color-on-status", ["--color-status-error"], "min", 3.0),
    ("filled destructive clears 3:1, dark", "dark", "--color-on-status", ["--color-status-error"], "min", 3.0),
    ("focus ring outer band clears 3:1 on base", "light", "--color-accent", ["--color-surface-base"], "min", 3.0),
    ("focus ring inner band clears 3:1 on the accent fill", "light", "--color-surface-base", ["--color-accent"], "min", 3.0),
    ("tertiary is NOT a usable text color", "light", "--label-3", ["--color-surface-base"], "max", 3.0),
]


def parse_tokens(css):
    """--name -> raw value, comments stripped, multiple declarations per line."""
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    out = {}
    for name, value in re.findall(r"(--[a-z0-9-]+)\s*:\s*([^;]+);", css):
        out.setdefault(name, value.strip())
    return out


def resolve(name, tokens, theme, seen=None):
    """Resolve a token to an (r, g, b, a) tuple for one theme."""
    seen = seen or set()
    if name in seen:
        raise ValueError(f"circular token reference at {name}")
    seen.add(name)
    if name not in tokens:
        raise KeyError(f"{name} is not defined in {TOKENS.name}")
    return parse_color(tokens[name], tokens, theme, seen)


def split_args(s):
    """Split on top-level commas only, so rgba(...) survives intact."""
    parts, depth, current = [], 0, ""
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += ch
    parts.append(current.strip())
    return parts


def parse_color(value, tokens, theme, seen=None):
    value = value.strip()

    m = re.fullmatch(r"light-dark\(\s*(.*)\s*\)", value, flags=re.S)
    if m:
        args = split_args(m.group(1))
        if len(args) != 2:
            raise ValueError(f"light-dark() needs 2 arguments, got {len(args)} in {value!r}")
        return parse_color(args[0 if theme == "light" else 1], tokens, theme, seen)

    m = re.fullmatch(r"var\(\s*(--[a-z0-9-]+)\s*\)", value)
    if m:
        return resolve(m.group(1), tokens, theme, seen)

    m = re.fullmatch(r"#([0-9a-fA-F]{6})", value)
    if m:
        h = m.group(1)
        return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 1.0)

    m = re.fullmatch(r"rgba?\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*(?:,\s*([0-9.]+)\s*)?\)", value)
    if m:
        a = float(m.group(4)) if m.group(4) is not None else 1.0
        return (float(m.group(1)), float(m.group(2)), float(m.group(3)), a)

    raise ValueError(f"cannot parse color {value!r}")


def composite(fg, bg):
    """Source-over. bg is assumed opaque by the time we get here."""
    a = fg[3]
    return tuple(fg[i] * a + bg[i] * (1 - a) for i in range(3)) + (1.0,)


def flatten(stack, tokens, theme):
    """Resolve a background stack to one opaque color, back to front."""
    colors = [resolve(n, tokens, theme) for n in stack]
    result = colors[-1]
    if result[3] < 1.0:
        raise ValueError(f"bottom of stack {stack[-1]} is not opaque")
    for layer in reversed(colors[:-1]):
        result = composite(layer, result)
    return result


def luminance(c):
    def channel(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

    return 0.2126 * channel(c[0]) + 0.7152 * channel(c[1]) + 0.0722 * channel(c[2])


def ratio(fg, bg):
    a, b = luminance(fg), luminance(bg)
    lo, hi = sorted((a, b))
    return (hi + 0.05) / (lo + 0.05)


def measure(theme, fg_name, bg_stack, tokens):
    bg = flatten(bg_stack, tokens, theme)
    fg = resolve(fg_name, tokens, theme)
    if fg[3] < 1.0:
        fg = composite(fg, bg)
    return ratio(fg, bg)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    tokens = parse_tokens(TOKENS.read_text())
    failures = []
    rows = []

    for theme, fg, stack, expected in CASES:
        got = measure(theme, fg, stack, tokens)
        ok = abs(got - expected) <= TOLERANCE
        if not ok:
            failures.append(f"{theme}: {fg} on {' / '.join(stack)} is {got:.2f}, colors.md says {expected:.2f}")
        rows.append((theme, fg, " on ".join([" over ".join(stack)]), got, expected, ok))

    for label, theme, fg, stack, kind, threshold in INVARIANTS:
        got = measure(theme, fg, stack, tokens)
        ok = got >= threshold if kind == "min" else got <= threshold
        if not ok:
            word = "below" if kind == "min" else "above"
            failures.append(f"invariant broken: {label} ({got:.2f} is {word} {threshold:.2f})")

    if not args.quiet:
        width = max(len(r[1]) for r in rows)
        print(f"{'theme':<6} {'foreground':<{width}} {'on':<46} {'got':>6} {'doc':>6}")
        for theme, fg, bg, got, expected, ok in rows:
            mark = " " if ok else "  <-- drift"
            print(f"{theme:<6} {fg:<{width}} {bg:<46} {got:>6.2f} {expected:>6.2f}{mark}")
        print()
        print(f"{len(CASES)} documented ratios, {len(INVARIANTS)} invariants")

    if failures:
        print("\nFAIL")
        for f in failures:
            print(f"  {f}")
        print("\nUpdate design/colors.md, or revert the token change.")
        return 1

    if not args.quiet:
        print("OK: design/colors.md matches design/tokens.css")
    return 0


if __name__ == "__main__":
    sys.exit(main())
