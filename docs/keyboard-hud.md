# Keyboard HUD

Agreed with Michael 2026-11-25. The ferry app is an **ambient HUD client** of the HUD Controller: it describes a
row, the controller plays it on the UHK's top row. How the parts fit: `~/Claude/Projects/Meta Docs/HUD System.md`;
the controller's side: `~/Claude/Projects/hud-controller/docs/PROTOCOL.md`.

## What the row shows

```
cell:   1    2    3    4    5    6  |  7 ... 14
key:    `    1    2    3    4    5  |  6 ... Backspace
        tomorrow ... tomorrow + 5    |  white (not in use)
```

- **Cells 1-6 = the next six days, starting tomorrow** (Vietnam dates). Six, not seven: the forecast runs 7 days
  from today and is already iffy at the far end, so the row stops at the last day with data. Michael doesn't
  raise the look-ahead (2026-11-25).
- **Colour = that day's departure, as a smooth gradient** (Michael, 2026-11-25): the exact shade for the day's
  score (worst point), the same continuous scale as the app: 0 green, through yellow-green, 1 yellow, orange, to
  red at 2 and above. Never just three solid colours: a 0.7 day is a different shade from a 0.4 day.
- **Monday is white:** no ferry. It also shows where the week turns, so the row reads without counting days.
- **No forecast data = black (unlit).** The app's gray would look like dim white on a key.
- **Vung Tau → Con Dao days flash; Con Dao → Vung Tau days stay still.** Michael lives in Vung Tau and looks at
  the outbound crossing first; the return days show the trend. Flashing needs a controller feature that doesn't
  exist yet (asked for in its inbox, 2026-11-25); until then all days are still.
- **Peak timetable** (both directions daily): the key shows Vung Tau → Con Dao.
- **Cells 7-14 are white.** Today isn't shown: Michael books at the last minute, and the app shows today.

## Keys (hold Mouse, press what you see)

| Key | Link |
|---|---|
| A day's key | `condaoferry://day/2026-11-26`: opens the app on that departure's detail |
| Monday and white keys | `condaoferry://home`: opens the app's main window |

The app starts if it isn't running.

## Keeping it current with the app closed

- The app sends a **schedule** whose moments change at each Vietnam midnight, ending (`until`) at the end of
  tomorrow. It sends whenever it fetches new data.
- Because less than two days are always left, the controller opens `condaoferry://hud/refresh` in the background
  (at most every 6 hours, matching the backend's runs). The app fetches `state.json`, sends a new schedule and quits
  if it was started only for that, without showing a window.
- If nothing refreshes for over a day, the row goes blank: a visible sign something stopped.

## Settings

Settings → **Keyboard HUD** on/off (on by default). Off removes the HUD from the controller. Which HUD is on the
keyboard right now is the controller's menu, as for every app.
