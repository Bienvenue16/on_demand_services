from fastapi import WebSocket
from collections import defaultdict
from typing import Dict, List


class ConnectionManager:
    def __init__(self):
        self.rooms: Dict[str, List[WebSocket]] = defaultdict(list)

    async def connect(self, room_id: str, ws: WebSocket) -> None:
        await ws.accept()
        self.rooms[room_id].append(ws)

    def disconnect(self, room_id: str, ws: WebSocket) -> None:
        room = self.rooms.get(room_id, [])
        if ws in room:
            room.remove(ws)

    async def send_to_room(self, room_id: str, data: dict) -> None:
        dead = []
        for ws in self.rooms.get(room_id, []):
            try:
                await ws.send_json(data)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(room_id, ws)


manager = ConnectionManager()
