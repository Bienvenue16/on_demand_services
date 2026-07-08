import math


def haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Retourne la distance en kilomètres entre deux points GPS."""
    R = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def filter_nearby(items: list, user_lat: float, user_lng: float, radius_km: float) -> list:
    """Filtre une liste d'objets ayant un champ location.lat / location.lng."""
    return [
        item for item in items
        if item.location and
        haversine_distance(user_lat, user_lng, item.location.lat, item.location.lng) <= radius_km
    ]
