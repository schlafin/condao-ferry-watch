"""Route geometry and the smoothness scoring model.

The scoring is deliberately transparent and tunable from config.py rather
than a black box -- adjust the weights there as you learn more about how
this specific boat actually behaves.
"""

import math
from datetime import timedelta

import config


def interpolate_point(p1, p2, frac):
    """Linear interpolation between two (lat, lon) points. Fine at this
    scale (~100nm); no need for great-circle math."""
    lat = p1[0] + (p2[0] - p1[0]) * frac
    lon = p1[1] + (p2[1] - p1[1]) * frac
    return (lat, lon)


def bearing(p1, p2):
    """Initial bearing in degrees (0-360, 0=North) from p1 to p2."""
    lat1, lon1 = map(math.radians, p1)
    lat2, lon2 = map(math.radians, p2)
    dlon = lon2 - lon1
    x = math.sin(dlon) * math.cos(lat2)
    y = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dlon)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


def angle_off_bow(route_bearing, wave_direction):
    """0 = wave arriving from dead ahead or dead astern (pitching only,
    which a long hull handles well). 90 = wave hitting broadside (beam
    seas -- the rolling condition that actually makes people seasick)."""
    diff = abs(route_bearing - wave_direction) % 360
    if diff > 180:
        diff = 360 - diff
    return 90 - abs(diff - 90)


def build_waypoints(origin, destination, n=config.NUM_WAYPOINTS):
    return [interpolate_point(origin, destination, i / (n - 1)) for i in range(n)]


def eta_for_waypoint(depart_dt, index, n, crossing_hours=config.CROSSING_HOURS):
    frac = index / (n - 1)
    return depart_dt + timedelta(hours=crossing_hours * frac)


def score_segment(hourly_marine, hourly_wind, hour_index, route_bearing):
    """Combine wave/swell/wind data at one waypoint and hour into a single
    discomfort score. Higher = rougher. See config.py for thresholds."""
    swell_h = hourly_marine["swell_wave_height"][hour_index] or 0
    swell_period = hourly_marine["swell_wave_period"][hour_index] or 0
    swell_dir = hourly_marine["swell_wave_direction"][hour_index] or 0
    wind_wave_h = hourly_marine["wind_wave_height"][hour_index] or 0
    sec_swell_series = hourly_marine.get("secondary_swell_wave_height") or []
    sec_swell_h = sec_swell_series[hour_index] if hour_index < len(sec_swell_series) else 0
    sec_swell_h = sec_swell_h or 0

    wind_speed_kmh = hourly_wind["wind_speed_10m"][hour_index] or 0
    wind_speed_kt = wind_speed_kmh * 0.539957

    score = swell_h

    lo, hi = config.RESONANCE_PERIOD_RANGE
    if lo <= swell_period <= hi:
        score *= config.RESONANCE_MULTIPLIER

    beam_angle = angle_off_bow(route_bearing, swell_dir)
    score *= (1 + 0.5 * math.sin(math.radians(beam_angle)))

    score += wind_wave_h * config.WIND_WAVE_WEIGHT
    score += sec_swell_h * config.SECONDARY_SWELL_WEIGHT
    score += wind_speed_kt / config.WIND_SPEED_DIVISOR_KT

    return score


def classify(score):
    if score < config.GREEN_MAX:
        return "GREEN"
    if score < config.YELLOW_MAX:
        return "YELLOW"
    return "RED"
