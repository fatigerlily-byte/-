---
title: "Notion APIで仕事を自動化する：Python実践ガイド"
emoji: "📋"
type: "tech"
topics: ["notion", "python", "api", "自動化", "生産性"]
published: true
---

# Notion APIで仕事を自動化する：Python実践ガイド

Notionを「書くだけ」のツールで終わらせていませんか？APIを使えば、外部データの自動取込・定期更新・他サービスとの連携ができます。この記事では実際に動くコードで具体的な自動化パターンを解説します。

## 事前準備

### 1. インテグレーションの作成

1. [Notion Integrations](https://www.notion.so/my-integrations) にアクセス
2. 「+ 新しいインテグレーション」をクリック
3. 名前（例: `my-automation`）を入力して作成
4. 表示された **Internal Integration Token** をコピー（`secret_xxxxx`）

### 2. データベースをインテグレーションと接続

自動化したいNotionデータベースを開く →「...」→「接続」→ 作成したインテグレーションを選択

### 3. データベースIDの確認

データベースのURLから取得：
```
https://www.notion.so/xxxxx/[データベースID]?v=xxxxx
```

### 4. ライブラリのインストール

```bash
pip install notion-client python-dotenv
```

```python
# .env
NOTION_TOKEN=secret_xxxxx
DATABASE_ID=xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

---

## 基本操作

```python
import os
from notion_client import Client
from dotenv import load_dotenv

load_dotenv()
notion = Client(auth=os.environ["NOTION_TOKEN"])
DATABASE_ID = os.environ["DATABASE_ID"]
```

### ページ一覧の取得

```python
def get_all_pages() -> list:
    results = []
    cursor = None
    
    while True:
        response = notion.databases.query(
            database_id=DATABASE_ID,
            start_cursor=cursor,
            page_size=100
        )
        results.extend(response["results"])
        
        if not response["has_more"]:
            break
        cursor = response["next_cursor"]
    
    return results

pages = get_all_pages()
print(f"{len(pages)}件取得しました")
```

### プロパティ値の読み取り

Notionのプロパティはタイプによって構造が違います。

```python
def get_property_value(page: dict, property_name: str) -> str | None:
    """プロパティ値を文字列として取得するユーティリティ"""
    prop = page["properties"].get(property_name)
    if not prop:
        return None
    
    prop_type = prop["type"]
    
    if prop_type == "title":
        items = prop["title"]
        return items[0]["plain_text"] if items else None
    
    elif prop_type == "rich_text":
        items = prop["rich_text"]
        return items[0]["plain_text"] if items else None
    
    elif prop_type == "select":
        sel = prop["select"]
        return sel["name"] if sel else None
    
    elif prop_type == "multi_select":
        return [s["name"] for s in prop["multi_select"]]
    
    elif prop_type == "date":
        date = prop["date"]
        return date["start"] if date else None
    
    elif prop_type == "checkbox":
        return prop["checkbox"]
    
    elif prop_type == "number":
        return prop["number"]
    
    elif prop_type == "status":
        status = prop["status"]
        return status["name"] if status else None
    
    return None

# 使用例
for page in pages[:3]:
    title = get_property_value(page, "タスク名")
    status = get_property_value(page, "ステータス")
    print(f"{title}: {status}")
```

---

## 実践パターン5選

### パターン① Googleカレンダーの予定をNotionに自動取込

毎朝、翌日の予定をNotionのタスクDBに自動追加。

```python
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from datetime import datetime, timedelta
import pytz

def fetch_tomorrow_events() -> list[dict]:
    """Google Calendar APIから翌日の予定を取得"""
    creds = Credentials.from_authorized_user_file("token.json")
    service = build("calendar", "v3", credentials=creds)
    
    jst = pytz.timezone("Asia/Tokyo")
    tomorrow = datetime.now(jst) + timedelta(days=1)
    start = tomorrow.replace(hour=0, minute=0, second=0).isoformat()
    end = tomorrow.replace(hour=23, minute=59, second=59).isoformat()
    
    events = service.events().list(
        calendarId="primary",
        timeMin=start,
        timeMax=end,
        singleEvents=True,
        orderBy="startTime"
    ).execute()
    
    return events.get("items", [])


def add_event_to_notion(event: dict):
    """カレンダーイベントをNotionのタスクとして追加"""
    start = event["start"].get("dateTime", event["start"].get("date"))
    
    notion.pages.create(
        parent={"database_id": DATABASE_ID},
        properties={
            "タスク名": {
                "title": [{"text": {"content": f"📅 {event['summary']}"}}]
            },
            "ステータス": {
                "status": {"name": "未着手"}
            },
            "期限": {
                "date": {"start": start[:10]}  # YYYY-MM-DD形式
            },
            "カテゴリ": {
                "multi_select": [{"name": "会議"}]
            }
        }
    )
    print(f"追加: {event['summary']}")


# メイン処理
events = fetch_tomorrow_events()
for event in events:
    add_event_to_notion(event)
```

---

### パターン② GitHubのIssueをNotionタスクと同期

GitHubにIssueが作られたら自動でNotionに追加。webhook or 定期バッチで動かす。

```python
import requests

def sync_github_issues_to_notion(github_repo: str, github_token: str):
    """GitHubのOpenIssueをNotionに同期"""
    
    # 既存のNotionページのGitHub Issue URLを収集（重複防止）
    existing = notion.databases.query(database_id=DATABASE_ID)
    existing_urls = set()
    for page in existing["results"]:
        url = get_property_value(page, "GitHubURL")
        if url:
            existing_urls.add(url)
    
    # GitHub APIからIssue取得
    issues = requests.get(
        f"https://api.github.com/repos/{github_repo}/issues",
        headers={"Authorization": f"token {github_token}"},
        params={"state": "open", "per_page": 50}
    ).json()
    
    added = 0
    for issue in issues:
        if issue["html_url"] in existing_urls:
            continue  # 既に登録済みはスキップ
        
        # 優先度をラベルから判定
        labels = [l["name"] for l in issue.get("labels", [])]
        priority = "🔴 高" if "priority:high" in labels else \
                   "🟡 中" if "priority:medium" in labels else "🟢 低"
        
        notion.pages.create(
            parent={"database_id": DATABASE_ID},
            properties={
                "タスク名": {
                    "title": [{"text": {"content": f"[GH] {issue['title']}"}}]
                },
                "優先度": {
                    "select": {"name": priority}
                },
                "カテゴリ": {
                    "multi_select": [{"name": "開発"}]
                },
                "GitHubURL": {
                    "url": issue["html_url"]
                }
            }
        )
        added += 1
    
    print(f"{added}件のIssueをNotionに追加しました")
```

---

### パターン③ 期限切れタスクの自動アラート

毎朝、期限切れ・当日締切のタスクをSlackに通知。

```python
from datetime import date
import requests

def notify_overdue_tasks(slack_webhook: str):
    today = date.today().isoformat()
    
    response = notion.databases.query(
        database_id=DATABASE_ID,
        filter={
            "and": [
                {
                    "property": "ステータス",
                    "status": {"does_not_equal": "完了"}
                },
                {
                    "property": "期限",
                    "date": {"on_or_before": today}
                }
            ]
        },
        sorts=[{"property": "期限", "direction": "ascending"}]
    )
    
    if not response["results"]:
        return
    
    overdue = []
    for page in response["results"]:
        title = get_property_value(page, "タスク名")
        deadline = get_property_value(page, "期限")
        url = page["url"]
        
        if deadline == today:
            overdue.append(f"🟡 *今日締切*: <{url}|{title}>")
        else:
            overdue.append(f"🔴 *期限切れ* ({deadline}): <{url}|{title}>")
    
    message = "⚠️ *要対応タスク*\n" + "\n".join(overdue)
    requests.post(slack_webhook, json={"text": message})
    print(f"{len(overdue)}件の期限タスクを通知しました")
```

---

### パターン④ CSVからNotionへの一括インポート

Excelの顧客リストや在庫データをNotionに一括登録。

```python
import csv
import time

def import_csv_to_notion(csv_filepath: str):
    """CSVファイルをNotionデータベースに一括インポート"""
    
    with open(csv_filepath, encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    
    print(f"{len(rows)}行をインポートします...")
    
    for i, row in enumerate(rows):
        try:
            notion.pages.create(
                parent={"database_id": DATABASE_ID},
                properties={
                    "タスク名": {
                        "title": [{"text": {"content": row.get("タスク名", "")}}]
                    },
                    "ステータス": {
                        "status": {"name": row.get("ステータス", "未着手")}
                    },
                    "優先度": {
                        "select": {"name": row.get("優先度", "🟡 中")}
                    },
                    "メモ": {
                        "rich_text": [{"text": {"content": row.get("メモ", "")}}]
                    }
                }
            )
            
            # APIレートリミット対策（1秒に3リクエストが上限）
            if (i + 1) % 3 == 0:
                time.sleep(1)
                
        except Exception as e:
            print(f"行{i+1}でエラー: {e}")
            continue
    
    print("インポート完了")

# 使用例
import_csv_to_notion("tasks.csv")
```

:::message
**Notion APIのレートリミット**
1秒あたり3リクエストが上限です。大量データの処理時は`time.sleep(0.34)`を挟んでください。
:::

---

### パターン⑤ Notionデータベースの集計レポート自動生成

タスクの完了率・ステータス別集計をMarkdownレポートとして出力。

```python
from collections import Counter
from datetime import datetime

def generate_weekly_report() -> str:
    pages = get_all_pages()
    
    status_count = Counter()
    priority_count = Counter()
    overdue_tasks = []
    today = date.today().isoformat()
    
    for page in pages:
        status = get_property_value(page, "ステータス") or "不明"
        priority = get_property_value(page, "優先度") or "未設定"
        deadline = get_property_value(page, "期限")
        title = get_property_value(page, "タスク名") or "無題"
        
        status_count[status] += 1
        if status != "完了":
            priority_count[priority] += 1
        
        if deadline and deadline < today and status != "完了":
            overdue_tasks.append((title, deadline))
    
    total = len(pages)
    completed = status_count.get("完了", 0)
    completion_rate = (completed / total * 100) if total > 0 else 0
    
    report = f"""# 週次タスクレポート {datetime.now().strftime('%Y/%m/%d')}

## 全体サマリー
- 総タスク数: {total}件
- 完了: {completed}件（達成率 {completion_rate:.1f}%）
- 未完了: {total - completed}件

## ステータス別
"""
    for status, count in status_count.most_common():
        bar = "█" * int(count / total * 20)
        report += f"- {status}: {count}件 {bar}\n"
    
    report += "\n## 未完了タスクの優先度分布\n"
    for priority, count in priority_count.most_common():
        report += f"- {priority}: {count}件\n"
    
    if overdue_tasks:
        report += f"\n## ⚠️ 期限切れタスク ({len(overdue_tasks)}件)\n"
        for title, deadline in overdue_tasks[:10]:
            report += f"- {title}（{deadline}）\n"
    
    return report

print(generate_weekly_report())
```

---

## GitHub Actionsで定期実行する

上記の自動化を毎朝自動実行する設定：

```yaml
# .github/workflows/notion-sync.yml
name: Notion Daily Sync
on:
  schedule:
    - cron: '0 0 * * 1-5'  # 平日朝9時 JST
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install notion-client python-dotenv requests
      - name: Run sync
        env:
          NOTION_TOKEN: ${{ secrets.NOTION_TOKEN }}
          DATABASE_ID: ${{ secrets.NOTION_DATABASE_ID }}
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
        run: python scripts/notion_sync.py
```

---

## まとめ

Notion APIで自動化できる主なパターン：

| パターン | 効果 |
|---------|------|
| 外部データ取込（カレンダー・GitHub） | 手動コピペ削減 |
| 定期バッチ更新 | 常に最新状態を維持 |
| Slack通知連携 | 見落とし防止 |
| CSVインポート | 初期データ投入を一瞬で |
| 集計レポート生成 | 週次レビューを自動化 |

Notionは「書くツール」から「データプラットフォーム」に変わります。APIを使い始めると、Notionの活用幅が一気に広がります。

---

## 参考

- [Notion API公式ドキュメント](https://developers.notion.com/)
- [notion-client PyPIページ](https://pypi.org/project/notion-client/)
