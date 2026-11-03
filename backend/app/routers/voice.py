# -*- coding: utf-8 -*-
"""语音转文字：App 上传录音（wav/mp3）-> aihubmix Whisper /audio/transcriptions -> 返回文字
2026-11-03 实测对比：whisper-large-v3 1.8s/次、质量最佳，比 gemini-2.5-pro 快 2.5 倍
"""
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

    # aihubmix 偶发渠道故障（超时/5xx），自动重试一次提升成功率
    last_err = None
    for _ in range(2):
        try:
            client = _get_client()
            resp = await client.post(
                f"{settings.AI_BASE_URL}/audio/transcriptions",
                headers={"Authorization": f"Bearer {settings.AIHUBMIX_API_KEY}"},
                # Whisper 专用转写端点：直接传原始音频，无需 base64（省 33% 流量）
                files={"file": (f"audio.{ext}", data, "audio/wav")},
                data={"model": settings.ASR_MODEL, "language": "zh"},
            )
            resp.raise_for_status()
            text = (resp.json().get("text") or "").strip()
            return {"text": text}
        except Exception as e:
            last_err = e

    raise HTTPException(status_code=502, detail=f"语音识别失败：{last_err}")
