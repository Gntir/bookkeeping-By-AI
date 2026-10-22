# -*- coding: utf-8 -*-
# 语音接口端到端测试：注册登录 -> 上传 wav -> 校验转写结果 + 401 鉴权
import json
import time
import urllib.error
import urllib.request

BASE = "http://127.0.0.1:8000"


def call_json(method, path, body=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        BASE + path,
        data=json.dumps(body).encode() if body else None,
        headers=headers,
        method=method,
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.status, json.loads(r.read())


# 注册/登录拿 token
try:
    call_json("POST", "/api/auth/register",
              {"phone": "13900001111", "password": "pass123456", "nickname": "语音测试"})
except urllib.error.HTTPError:
    pass  # 已注册
_, body = call_json("POST", "/api/auth/login",
                    {"phone": "13900001111", "password": "pass123456"})
token = body["token"]

# multipart 上传 wav
boundary = "----testboundary123"
wav = open("tool/voice_test.wav", "rb").read()
parts = (
    f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
    f'filename="voice.wav"\r\nContent-Type: audio/wav\r\n\r\n'
).encode() + wav + f"\r\n--{boundary}--\r\n".encode()

t0 = time.perf_counter()
req = urllib.request.Request(
    BASE + "/api/ai/voice",
    data=parts,
    headers={
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Authorization": "Bearer " + token,
    },
    method="POST",
)
with urllib.request.urlopen(req, timeout=90) as r:
    result = json.loads(r.read())
    print(f"voice 接口 {r.status} | {time.perf_counter() - t0:.1f}s | 转写: {result['text']}")

# 未登录应 401
req2 = urllib.request.Request(
    BASE + "/api/ai/voice",
    data=parts,
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    method="POST",
)
try:
    urllib.request.urlopen(req2, timeout=30)
    print("异常：未登录居然能访问!")
except urllib.error.HTTPError as e:
    print(f"未登录: {e.code} (预期401)")

# 错误格式应 400
bad = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
       f'filename="voice.ogg"\r\nContent-Type: audio/ogg\r\n\r\n').encode() + b"xx" + f"\r\n--{boundary}--\r\n".encode()
req3 = urllib.request.Request(
    BASE + "/api/ai/voice",
    data=bad,
    headers={
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "Authorization": "Bearer " + token,
    },
    method="POST",
)
try:
    urllib.request.urlopen(req3, timeout=30)
    print("异常：ogg 居然能过!")
except urllib.error.HTTPError as e:
    print(f"ogg 格式: {e.code} (预期400)")
