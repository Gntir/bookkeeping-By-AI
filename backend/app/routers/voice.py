# -*- coding: utf-8 -*-
"""语音转文字：App 上传录音（wav/mp3）-> aihubmix 多模态模型转写 -> 返回文字
方案已于 2026-10-09 实测：gemini-2.5-flash 中文转写完美（含数字），约 3-4s / $0.0002 每次
"""
import base64

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File

from ..ai_parser import _get_client
from ..config import get_settings
from ..deps import get_current_user
from ..models import User

router = APIRouter(prefix="/api/ai", tags=["voice"])

MAX_AUDIO_BYTES = 5 * 1024 * 1024  # 5MB 上限，约 2 分钟 16kHz wav


@router.post("/voice")
async def voice_to_text(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """语音识别：返回 {'text': '转写结果'}"""
    settings = get_settings()
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="音频内容为空")
    if len(data) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="音频太大（超过5MB）")

    # wav / mp3 之外的扩展名直接拒绝（模型只认这两种）
    ext = (file.filename or "").rsplit(".", 1)[-1].lower()
    if ext not in ("wav", "mp3", "wave"):
        raise HTTPException(status_code=400, detail="仅支持 wav / mp3 格式")

    audio_b64 = base64.b64encode(data).decode()
    payload = {
        "model": settings.ASR_MODEL,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "把这段语音逐字转写成文字，只输出转写结果，不要解释。"},
                    {"type": "input_audio", "input_audio": {"data": audio_b64, "format": "wav" if ext != "mp3" else "mp3"}},
                ],
            }
        ],
        "max_tokens": 300,
        "reasoning_effort": "none",  # 纯转写不需要思考，实测提速明显
    }

    try:
        client = _get_client()
        resp = await client.post(
            f"{settings.AI_BASE_URL}/chat/completions",
            headers={"Authorization": f"Bearer {settings.AIHUBMIX_API_KEY}"},
            json=payload,
        )
        resp.raise_for_status()
        text = (resp.json()["choices"][0]["message"].get("content") or "").strip()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"语音识别失败：{e}")

    return {"text": text}
