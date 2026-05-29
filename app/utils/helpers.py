import secrets


def make_room_id(request_id: str, uid1: str, uid2: str) -> str:
    """Génère un room_id stable et déterministe.
    Format : {request_id}_{uid_min}_{uid_max} (uids triés lexicographiquement).
    Deux appels avec les mêmes arguments dans n'importe quel ordre donnent le même résultat.
    """
    a, b = sorted([str(uid1), str(uid2)])
    return f"{str(request_id)}_{a}_{b}"


def parse_room_id(room_id: str) -> tuple[str, str, str]:
    """Extrait (request_id, uid_a, uid_b) depuis un room_id.
    Lève ValueError si le format est invalide.
    """
    parts = room_id.split("_")
    if len(parts) != 3:
        raise ValueError(f"room_id invalide : '{room_id}' (attendu: request_id_uid_a_uid_b)")
    return parts[0], parts[1], parts[2]


def generate_token(length: int = 32) -> str:
    """Token URL-safe sécurisé pour vérification email / reset MDP."""
    return secrets.token_urlsafe(length)


def slugify(text: str) -> str:
    """Convertit un texte en slug URL (ex: 'Bâtiment & Réparations' → 'batiment-reparations')."""
    import unicodedata
    import re
    text = unicodedata.normalize("NFD", text)
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")
