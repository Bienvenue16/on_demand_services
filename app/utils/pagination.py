from typing import Any


async def paginate(query: Any, page: int = 1, limit: int = 20) -> dict:
    """Pagine une requête Beanie et retourne un dict compatible PaginatedResponse."""
    limit = min(limit, 100)
    skip = (page - 1) * limit
    total = await query.count()
    data = await query.skip(skip).limit(limit).to_list()
    return {"total": total, "page": page, "limit": limit, "data": data}
