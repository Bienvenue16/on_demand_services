import re
from fastapi import HTTPException


def validate_phone(phone: str) -> str:
    """Valide et normalise un numéro de téléphone (8-15 chiffres)."""
    cleaned = re.sub(r"[\s\-\(\)\+]", "", phone)
    if not re.match(r"^\d{8,15}$", cleaned):
        raise HTTPException(400, detail="Numéro de téléphone invalide (8-15 chiffres)")
    return cleaned


def validate_image_type(content_type: str) -> None:
    """Vérifie que le type MIME est une image autorisée."""
    allowed = {"image/jpeg", "image/png", "image/webp"}
    if content_type not in allowed:
        raise HTTPException(400, detail=f"Type de fichier non autorisé. Acceptés : {', '.join(allowed)}")


def validate_file_size(size_bytes: int, max_mb: int) -> None:
    """Vérifie que la taille du fichier ne dépasse pas le maximum."""
    if size_bytes > max_mb * 1024 * 1024:
        raise HTTPException(400, detail=f"Fichier trop lourd (max {max_mb} Mo)")
