"""
Configuration for the Vung Tau <-> Con Dao ferry smoothness watcher.

Most of this needs periodic manual updates -- there's no reliable API for
"is the route running" or "what's this month's schedule," so rather than
build something fragile to auto-detect it, this file is the single place
you update by hand a few times a year.
"""

from datetime import date

# --- Route status -------------------------------------------------------
# Phu Quoc Express pulls the Thang Long ferry off this route every year for
# the monsoon season. In the last three years that's meant suspending
# somewhere between late Aug and mid-Sep, and resuming between early Feb
# and late Feb. As of this writing (Sep 2026) it has been suspended since
# Aug 1, 2026 with no announced restart date.
#
# Check https://taucaotocthanglong.com/ or https://condao.express/ before
# flipping this, and update ROUTE_LAST_CHECKED every time you check (even
# if the answer didn't change) so the script can nag you if it's gone stale.
ROUTE_ACTIVE = False
ROUTE_LAST_CHECKED = date(2026, 9, 13)
ROUTE_CHECK_STALE_AFTER_DAYS = 10

# --- Ports ----------------------------------------------------------------
# Approximate coordinates -- good enough for sampling a marine forecast
# along the route, but verify against a map/GPS if you want to tighten
# these up.
CAU_DA_PORT = (10.3360, 107.0850)   # Vung Tau
BEN_DAM_PORT = (8.6975, 106.6017)   # Con Dao

# --- Schedule ---------------------------------------------------------
# "standard" = 3x/week each direction (the year-round baseline schedule)
# "peak"     = daily except Monday (documented for mid-Apr - mid-Jun 2026;
#              historically extended informally through summer weekends too)
# Update this by hand when the operator announces a schedule change.
SCHEDULE_MODE = "standard"

SCHEDULES = {
    "standard": {
        # weekday: 0=Mon ... 6=Sun
        "VT_TO_CD": {"weekdays": [1, 3, 5], "depart_local": "07:30"},   # Tue/Thu/Sat
        "CD_TO_VT": {"weekdays": [2, 4, 6], "depart_local": "13:00"},   # Wed/Fri/Sun
    },
    "peak": {
        "VT_TO_CD": {"weekdays": [0, 1, 2, 3, 4, 5, 6], "exclude": [0], "depart_local": "07:30"},
        "CD_TO_VT": {"weekdays": [0, 1, 2, 3, 4, 5, 6], "exclude": [0], "depart_local": "13:00"},
    },
}

CROSSING_HOURS = 3.5
TIMEZONE = "Asia/Ho_Chi_Minh"

# --- Path model -----------------------------------------------------------
NUM_WAYPOINTS = 7  # including both endpoints, evenly spaced along the route

# --- Scoring --------------------------------------------------------------
# These thresholds are starting guesses, NOT calibrated against your actual
# rides. If you can give me the approximate dates of your calm crossing and
# your choppy crossing, I can pull Open-Meteo's historical marine data for
# those two days and set real, evidence-based numbers here instead of
# guesses -- worth doing before you trust this for real trip planning.
GREEN_MAX = 1.0
YELLOW_MAX = 1.6

# Heuristic, not vessel-specific: swell periods in this band are treated as
# higher-risk for a ~77m monohull. This is a guess pending real data (see
# calibration note above) -- monohull roll-resonance periods vary by hull
# design, loading, and speed, and I don't have Thang Long's actual figures.
RESONANCE_PERIOD_RANGE = (6, 11)  # seconds
RESONANCE_MULTIPLIER = 1.3

WIND_WAVE_WEIGHT = 0.7
SECONDARY_SWELL_WEIGHT = 0.8
WIND_SPEED_DIVISOR_KT = 50.0

LOOKAHEAD_DAYS = 7
