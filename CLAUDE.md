# Con Dao Ferry Watch — Claude Code project brief

Read `condao-ferry-watch-design.md` in this folder first — that's the
full spec. This file is just the short, every-session context Claude
Code should hold onto without being re-told.

## Why this project exists

This is primarily a **learning project**, not a product. The ferry
watcher is a realistic, low-stakes example for Michael to learn:

1. **Git and GitHub** — commits, version history, reverting, pushing,
   and running scheduled jobs in the cloud with **GitHub Actions** so
   nothing depends on his Mac being on.
2. **Xcode and macOS app development** — building, signing and running
   a small native Mac app.

The core thing being tested is the end-to-end chain: a **scheduled
GitHub Action produces data and that data reaches the macOS app**
(fetched `state.json`, and later push notifications).

When choosing between options, favor the one that teaches the
GitHub/Xcode workflow clearly over the one that makes the ferry
forecast more accurate. Keep the weather/scoring logic as simple as
possible until the pipeline works end to end. Explain git, GitHub and
Xcode steps as you do them — Michael wants to understand them, while
Claude handles the GitHub side (commits, pushes, workflows) for him.

## What it does

A personal tool for Michael that watches sea conditions along the Vung
Tau ⇄ Con Dao ferry route (a specific vessel, "Thăng Long," operated by
Phú Quốc Express) and pushes a native macOS notification when an
upcoming scheduled departure looks smooth enough to book. Single user,
not a product — optimize for correctness and low maintenance, not
generality or polish.

## Current status (update this section as work progresses)

- GitHub repo is **public** at
  https://github.com/schlafin/condao-ferry-watch, local copy at
  `~/Claude/Projects/condao-ferry-watch`. Initial commit pushed
  (CLAUDE.md, design doc, reference sketch, .gitignore).
- Milestone 1 backend lives in `backend/` (run locally with
  `.venv/bin/python backend/main.py [--test-event]`), with the workflow at
  `.github/workflows/ferry-check.yml`. It writes `state.json` at the repo
  root: `departures` (latest ratings) plus `events` (rating changes from
  this run, each with a unique `id`). The Mac app posts events it hasn't
  seen; it never compares ratings itself. Events last only until the next
  run (6h), so a Mac asleep longer than that misses them — acceptable
  until APNs (milestone 2). Built on branch `m1-backend` → PR.
- Pushing workflow files needs the GitHub CLI's `workflow` scope:
  `gh auth refresh -s workflow` (one browser approval).
- `reference-sketch/README.md` is out of date vs. the design doc (says
  twice daily instead of every 6 hours, and mentions a `ROUTE_ACTIVE`
  flag the design dropped). The design doc wins.
- Xcode is installed (/Applications/Xcode.app). No Apple Developer Program
  enrollment yet, no APNs credentials generated yet.
- **Planned first milestone (agreed 2026-10-18): skip APNs at first.**
  Have the Mac app fetch `state.json` on a timer and post a **local**
  macOS notification when a rating changes. This tests the full
  GitHub Action → repo → Mac app chain with no $99 Apple Developer
  enrollment, no .p8 key and no secrets. Add real APNs push afterwards
  as a second milestone.
- `reference-sketch/` in this folder is a rough v1 code draft from an
  earlier design conversation — untested, never run. Treat it as a
  starting point to rewrite or restructure freely, not a spec to follow
  literally. The design doc is the spec; the sketch is just scaffolding.

## Hold onto these — easy to accidentally drift from across sessions

- Data source is **Open-Meteo** (free, keyless marine + weather APIs).
  Never Windy — its API isn't viable for automation (design doc §3).
- Route/path model: **7 waypoints** along the route, each queried at its
  own ETA-adjusted forecast hour (not "now" for every point), scored,
  and aggregated as **worst-waypoint-wins** per departure — not an
  average, not a single point.
- **No automated route-active gate and no automated live check** of the
  ferry operator's booking/status site. This was a deliberate decision
  (design doc §2), not a missing feature — don't add either without
  checking with Michael first.
- Notification on/off is controlled by Michael at the **macOS System
  Settings** level, not by any flag or toggle in this codebase.
- APNs defaults to the **sandbox** endpoint, matching a plain Xcode
  Debug build. Don't switch to production without confirming there's an
  actual signed release build to match it.
- **iOS is explicitly deferred.** Build macOS only unless told
  otherwise; don't add an iOS target speculatively.
- The repo is public specifically so the macOS app can fetch
  `state.json` with a plain unauthenticated request. Don't reintroduce
  a token-based fetch without a reason.

## Working style

Michael prefers direct, precise answers over reassurance, and removing
complexity before adding it — don't over-build. He's technical (builds
his own equity research/valuation pipelines) but new to git/GitHub,
Xcode, and the Apple developer ecosystem specifically — go step by step
on those parts rather than assuming familiarity, the same way this
project's design conversation did.
