---
title: "FastAPIで10分で作るREST API【CRUD完全実装＋実践パターン集】"
emoji: "🚀"
type: "tech"
topics: ["fastapi", "python", "api", "rest", "backend"]
published: true
---

# FastAPIで10分で作るREST API【CRUD完全実装＋実践パターン集】

FastAPIはPythonのWebフレームワークの中で最も生産性が高い選択肢の一つです。型ヒントを書くだけで自動ドキュメントが生成され、バリデーションも自動で行われます。この記事では基本のCRUDから実務で使えるパターンまで一気に解説します。

---

## セットアップ

```bash
pip install fastapi uvicorn[standard] sqlmodel
```

```python
# main.py
from fastapi import FastAPI

app = FastAPI(title="My API", version="1.0.0")

@app.get("/")
def root():
    return {"message": "Hello, FastAPI"}
```

```bash
uvicorn main:app --reload
```

`http://localhost:8000/docs` を開くと自動生成されたSwagger UIが確認できます。

---

## 基本のCRUD実装

SQLModelを使ってSQLiteとの組み合わせで実装します。SQLModelはPydanticとSQLAlchemyを統合したライブラリで、モデル定義が1回で済みます。

```python
# main.py
from fastapi import FastAPI, HTTPException, Depends
from sqlmodel import Field, Session, SQLModel, create_engine, select
from typing import Optional
from datetime import datetime

# --- モデル定義 ---

class TaskBase(SQLModel):
    title: str
    description: Optional[str] = None
    completed: bool = False

class Task(TaskBase, table=True):  # table=True でDBテーブルになる
    id: Optional[int] = Field(default=None, primary_key=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)

class TaskCreate(TaskBase):  # 作成時のスキーマ（idなし）
    pass

class TaskUpdate(SQLModel):  # 更新時のスキーマ（全フィールドOptional）
    title: Optional[str] = None
    description: Optional[str] = None
    completed: Optional[bool] = None

# --- DB設定 ---

engine = create_engine("sqlite:///tasks.db")
SQLModel.metadata.create_all(engine)

def get_session():
    with Session(engine) as session:
        yield session

# --- アプリ ---

app = FastAPI(title="Task API")

# CREATE
@app.post("/tasks", response_model=Task, status_code=201)
def create_task(task: TaskCreate, session: Session = Depends(get_session)):
    db_task = Task.model_validate(task)
    session.add(db_task)
    session.commit()
    session.refresh(db_task)
    return db_task

# READ (一覧)
@app.get("/tasks", response_model=list[Task])
def get_tasks(
    skip: int = 0,
    limit: int = 100,
    completed: Optional[bool] = None,
    session: Session = Depends(get_session)
):
    query = select(Task)
    if completed is not None:
        query = query.where(Task.completed == completed)
    return session.exec(query.offset(skip).limit(limit)).all()

# READ (単件)
@app.get("/tasks/{task_id}", response_model=Task)
def get_task(task_id: int, session: Session = Depends(get_session)):
    task = session.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task

# UPDATE
@app.patch("/tasks/{task_id}", response_model=Task)
def update_task(
    task_id: int,
    task_update: TaskUpdate,
    session: Session = Depends(get_session)
):
    task = session.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    update_data = task_update.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(task, key, value)
    
    session.add(task)
    session.commit()
    session.refresh(task)
    return task

# DELETE
@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: int, session: Session = Depends(get_session)):
    task = session.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    session.delete(task)
    session.commit()
```

これで完全なCRUD APIの完成です。`/docs` で全エンドポイントをブラウザからテストできます。

---

## 実践パターン集

### パターン① 認証（APIキー）

```python
from fastapi import Security
from fastapi.security import APIKeyHeader
import secrets

API_KEY_HEADER = APIKeyHeader(name="X-API-Key")
VALID_API_KEYS = {"your-secret-key-here"}  # 実際はDBや環境変数で管理

def verify_api_key(api_key: str = Security(API_KEY_HEADER)):
    if api_key not in VALID_API_KEYS:
        raise HTTPException(status_code=403, detail="Invalid API key")
    return api_key

# 認証が必要なエンドポイント
@app.post("/tasks", dependencies=[Depends(verify_api_key)])
def create_task_protected(task: TaskCreate, session: Session = Depends(get_session)):
    ...
```

### パターン② バリデーション強化

```python
from pydantic import field_validator, model_validator

class TaskCreate(TaskBase):
    title: str
    priority: int = Field(ge=1, le=5)  # 1〜5の整数のみ
    due_date: Optional[datetime] = None
    
    @field_validator("title")
    @classmethod
    def title_must_not_be_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("タイトルは空白のみ不可")
        return v.strip()
    
    @model_validator(mode="after")
    def due_date_must_be_future(self):
        if self.due_date and self.due_date < datetime.utcnow():
            raise ValueError("期限は未来の日時を指定してください")
        return self
```

### パターン③ ページネーション

```python
from math import ceil

class PaginatedResponse(SQLModel):
    items: list[Task]
    total: int
    page: int
    per_page: int
    total_pages: int

@app.get("/tasks/paginated", response_model=PaginatedResponse)
def get_tasks_paginated(
    page: int = 1,
    per_page: int = 20,
    session: Session = Depends(get_session)
):
    offset = (page - 1) * per_page
    total = session.exec(select(func.count(Task.id))).one()
    items = session.exec(select(Task).offset(offset).limit(per_page)).all()
    
    return PaginatedResponse(
        items=items,
        total=total,
        page=page,
        per_page=per_page,
        total_pages=ceil(total / per_page)
    )
```

### パターン④ バックグラウンドタスク

時間がかかる処理は非同期で実行してすぐにレスポンスを返す。

```python
from fastapi import BackgroundTasks
import time

def send_notification_email(task_id: int, email: str):
    """メール送信（時間がかかる処理の例）"""
    time.sleep(2)  # 実際はSMTP送信
    print(f"タスク{task_id}の通知を{email}に送信しました")

@app.post("/tasks/{task_id}/notify")
def notify_task(
    task_id: int,
    email: str,
    background_tasks: BackgroundTasks,
    session: Session = Depends(get_session)
):
    task = session.get(Task, task_id)
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # バックグラウンドで実行（レスポンスはすぐ返る）
    background_tasks.add_task(send_notification_email, task_id, email)
    return {"message": "通知を送信中です"}
```

### パターン⑤ ミドルウェア（リクエストログ）

```python
import time
import logging
from fastapi import Request

logger = logging.getLogger(__name__)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start
    
    logger.info(
        f"{request.method} {request.url.path} "
        f"→ {response.status_code} ({duration:.3f}s)"
    )
    return response
```

### パターン⑥ CORS設定（フロントエンド連携）

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://your-frontend.com"],
    allow_methods=["GET", "POST", "PATCH", "DELETE"],
    allow_headers=["*"],
)
```

---

## Dockerで本番デプロイ

```dockerfile
# Dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker-compose.yml
services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:password@db/mydb
    depends_on:
      - db
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: mydb
    volumes:
      - pgdata:/var/lib/postgresql/data

volumes:
  pgdata:
```

```bash
docker compose up -d
```

---

## テストの書き方

```python
# test_main.py
from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, create_engine
from sqlmodel.pool import StaticPool
import pytest
from main import app, get_session

@pytest.fixture(name="session")
def session_fixture():
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SQLModel.metadata.create_all(engine)
    with Session(engine) as session:
        yield session

@pytest.fixture(name="client")
def client_fixture(session: Session):
    def override_get_session():
        return session
    app.dependency_overrides[get_session] = override_get_session
    client = TestClient(app)
    yield client
    app.dependency_overrides.clear()

def test_create_task(client: TestClient):
    response = client.post("/tasks", json={"title": "テストタスク"})
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "テストタスク"
    assert data["completed"] == False

def test_get_task_not_found(client: TestClient):
    response = client.get("/tasks/999")
    assert response.status_code == 404
```

---

## まとめ

FastAPIの強みを一言で言うと「型ヒントがそのままAPIの仕様になる」点です。

| 機能 | FastAPIの対応 |
|------|------------|
| バリデーション | Pydanticモデルで自動 |
| ドキュメント | `/docs` で自動生成 |
| 非同期処理 | `async def` で対応 |
| 型安全 | Python型ヒントで実現 |
| テスト | TestClientで簡単に |

まず `pip install fastapi uvicorn` してHello WorldのAPIを作ることから始めてみてください。
