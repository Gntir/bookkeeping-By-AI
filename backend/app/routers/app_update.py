# -*- coding: utf-8 -*-
"""App 内更新：版本检查 + APK 下载
服务器发布方式：把新 APK 和 release.json 放到 backend/release/ 目录（无需重启服务）
release.json 格式：{"version": "0.1.0+6", "note": "更新说明"}
"""
import json
import os

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse

from ..config import get_settings

router = APIRouter(prefix="/api/app", tags=["app-update"])

RELEASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "release")


@router.get("/version")
async def check_version():
    """App 启动时调用：返回最新版本号和更新说明"""
    meta_path = os.path.join(RELEASE_DIR, "release.json")
    apk_path = os.path.join(RELEASE_DIR, "app-release.apk")
    if not os.path.exists(meta_path) or not os.path.exists(apk_path):
        return {"available": False}
    with open(meta_path, encoding="utf-8") as f:
        info = json.load(f)
    info["available"] = True
    return info


@router.get("/download")
async def download_apk():
    """下载最新安装包"""
    apk_path = os.path.join(RELEASE_DIR, "app-release.apk")
    if not os.path.exists(apk_path):
        raise HTTPException(status_code=404, detail="安装包不存在")
    return FileResponse(
        apk_path,
        filename="ai-jizhang.apk",
        media_type="application/vnd.android.package-archive",
    )
