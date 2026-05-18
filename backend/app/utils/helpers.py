import secrets
import hashlib


def generate_room_id(uid_a: str, uid_b: str) -> str:
    """Génère un room_id stable et symétrique depuis deux IDs utilisateurs."""
    pair = sorted([str(uid_a), str(uid_b)])
    return hashlib.sha256("".join(pair).encode()).hexdigest()[:32]


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
