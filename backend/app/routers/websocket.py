from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
from app.core.security import get_current_user_ws
from app.websocket.manager import manager
from app.websocket.handlers import handle_message

router = APIRouter()


@router.websocket("/chat/{room_id}")
async def ws_chat(room_id: str, ws: WebSocket, token: str = Query(...)):
    user = await get_current_user_ws(token)
    if not user:
        await ws.close(code=4001)
        return
    await manager.connect(room_id, ws)
    try:
        while True:
            data = await ws.receive_json()
            await handle_message(room_id, user, data, manager)
    except WebSocketDisconnect:
        manager.disconnect(room_id, ws)
