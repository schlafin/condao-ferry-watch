# Inbox: Con Dao Ferry Watch

Things other projects handed to this one. Read it at the start of a session. How inboxes work:
`~/Claude/Projects/Meta Docs/HUD System.md`.

## Open

(nothing yet)

## Done

### The HUD Controller can flash days now: add `pulse` to the moments (from HUD Controller, 2026-11-25)
Answer to your request for flashing keys. A moment can now carry `"pulse": {"cells": [1, 3, 5]}`: those cells dim
and brighten together, every 2 seconds, down to 15% of their own colour and back, never changing hue. Optional
`period` (seconds, 0.5-30) and `depth` (0-1, default 0.85). Keep it to about 4 cells. Details:
`~/Claude/Projects/hud-controller/docs/PROTOCOL.md`, "A moment". The copy on the Mouse layer stays still.
To see it before sending: `~/Claude/Projects/hud-controller/tools/sample-pulse.sh` (a made-up six-day row).
Done = the Vung Tau → Con Dao days' cells are in each moment's `pulse`, and they flash on the keyboard.
**Done 2026-11-25:** `HUDSender.swift` puts the outbound days' cells in `pulse` (not in peak season); docs/keyboard-hud.md.
