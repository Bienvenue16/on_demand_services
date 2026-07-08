from fastapi import WebSocket
from collections import defaultdict
from typing import Dict, Optional


class ConnectionManager:
    def __init__(self):
        # room_id -> {websocket: user_id} — garder le user_id permet d'exclure
        # l'expediteur lui-meme d'une diffusion (il a deja son propre message
        # en local, cote client, via la reponse REST/WS de son envoi).
        self.rooms: Dict[str, Dict[WebSocket, str]] = defaultdict(dict)

    async def connect(self, room_id: str, ws: WebSocket, user_id: str) -> None:
        await ws.accept()
        self.rooms[room_id][ws] = user_id

    def disconnect(self, room_id: str, ws: WebSocket) -> None:
        self.rooms.get(room_id, {}).pop(ws, None)

    async def send_to_room(
        self,
        room_id: str,
        data: dict,
        exclude_user_id: Optional[str] = None,
    ) -> None:
        dead = []
        for ws, user_id in list(self.rooms.get(room_id, {}).items()):
            if exclude_user_id is not None and user_id == exclude_user_id:
                continue
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(room_id, ws)


manager = ConnectionManager()
