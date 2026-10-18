# Con Dao Ferry Watch — Claude Code project brief

Read `condao-ferry-watch-design.md` in this folder first — that's the
full spec. This file is just the short, every-session context Claude
Code should hold onto without being re-told.

## What this is

A personal tool for Michael that watches sea conditions along the Vung
Tau ⇄ Con Dao ferry route (a specific vessel, "Thăng Long," operated by
Phú Quốc Express) and pushes a native macOS notification when an
upcoming scheduled departure looks smooth enough to book. Single user,
not a product — optimize for correctness and low maintenance, not
generality or polish.

## Current status (update this section as work progresses)

- GitHub repo created and set to **public**:
  https://github.com/schlafin/condao-ferry-watch — currently empty,
  nothing pushed yet.
- Xcode is being installed locally. No Apple Developer Program
  enrollment yet, no APNs credentials generated yet.
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
