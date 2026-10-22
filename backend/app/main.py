import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, SessionLocal, engine
from .models import Category  # noqa: F401 (确保建表)
from .routers import ai, app_update, auth, categories, ledgers, salary, stats, transactions
from .scheduler import start_scheduler
from .seed import PRESET_CATEGORIES

logging.basicConfig(level=logging.INFO)

app = FastAPI(title="AI 记账 Demo", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # demo 阶段放开，上架前收紧
    allow_methods=["*"],
    allow_headers=["*"],
)

for r in (auth, ledgers, categories, transactions, ai, salary, stats, app_update):
    app.include_router(r.router)


@app.on_event("startup")
def on_startup():
    # 建表
    Base.metadata.create_all(bind=engine)
    # 写入预置分类（幂等）
    db = SessionLocal()
    try:
        if db.query(Category).count() == 0:
            for name, type_, icon, sort in PRESET_CATEGORIES:
                db.add(Category(name=name, type=type_, icon=icon, sort=sort))
            db.commit()
    finally:
        db.close()
    # 启动定时任务（发薪日自动记账）
    start_scheduler()


@app.get("/api/health")
def health():
    return {"ok": True}
