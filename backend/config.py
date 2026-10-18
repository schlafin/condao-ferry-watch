"""
Configuration for the Vung Tau <-> Con Dao ferry smoothness watcher.

There's no reliable API for "what's this month's schedule," so this file
is the single place to update by hand when the operator changes it.
Deliberately no route-active flag: the job always runs (design doc §2).
"""

# --- Ports ----------------------------------------------------------------
# Approximate coordinates -- good enough for sampling a marine forecast.
CAU_DA_PORT = (10.3360, 107.0850)   # Vung Tau
BEN_DAM_PORT = (8.6975, 106.6017)   # Con Dao

LEG_LABELS = {
    "VT_TO_CD": "Vung Tau → Con Dao",
    "CD_TO_VT": "Con Dao → Vung Tau",
}

# --- Schedule ---------------------------------------------------------
# "standard" = 3x/week each direction (year-round baseline)
# "peak"     = daily except Monday (mid-Apr - mid-Jun 2026, and
#              historically some summer weekends)
SCHEDULE_MODE = "standard"

SCHEDULES = {
    # weekday: 0=Mon ... 6=Sun
    "standard": {
        "VT_TO_CD": {"weekdays": [1, 3, 5], "depart_local": "07:30"},   # Tue/Thu/Sat
        "CD_TO_VT": {"weekdays": [2, 4, 6], "depart_local": "13:00"},   # Wed/Fri/Sun
    },
    "peak": {
        "VT_TO_CD": {"weekdays": [1, 2, 3, 4, 5, 6], "depart_local": "07:30"},
        "CD_TO_VT": {"weekdays": [1, 2, 3, 4, 5, 6], "depart_local": "13:00"},
    },
}

CROSSING_HOURS = 3.5
TIMEZONE = "Asia/Ho_Chi_Minh"
LOOKAHEAD_DAYS = 7

# --- Seasonal caveat (design doc §2) ----------------------------------------
# Not a gate -- only adds a warning line to notification text for
# departures in this month range (wraps the new year: Aug..Feb).
TYPICAL_CLOSURE_MONTHS = (8, 2)
ROUTE_STATUS_CHECK_URL = "https://taucaotocthanglong.com/"

# --- Path model -----------------------------------------------------------
NUM_WAYPOINTS = 7  # including both endpoints, evenly spaced along the route

# --- Scoring --------------------------------------------------------------
# Starting guesses, NOT calibrated (design doc §7).
GREEN_MAX = 1.0
YELLOW_MAX = 1.6

RESONANCE_PERIOD_RANGE = (6, 11)  # seconds, heuristic
RESONANCE_MULTIPLIER = 1.3

WIND_WAVE_WEIGHT = 0.7
SECONDARY_SWELL_WEIGHT = 0.8
WIND_SPEED_DIVISOR_KT = 50.0
