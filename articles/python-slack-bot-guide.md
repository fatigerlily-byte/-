---
title: "PythonでSlack Botを作る完全ガイド【業務自動化に使える実践レシピ付き】"
emoji: "🤖"
type: "tech"
topics: ["slack", "python", "bot", "自動化", "business"]
published: true
---

# PythonでSlack Botを作る完全ガイド【業務自動化に使える実践レシピ付き】

Slackを使っている会社なら、Botを作るだけで毎日の繰り返し作業が一気に減ります。「定時に日報リマインド」「キーワードに自動返信」「外部APIのデータを通知」など、実際に使えるレシピをコード付きで解説します。

---

## 事前準備

### Slack Appの作成

1. [api.slack.com/apps](https://api.slack.com/apps) を開き「Create New App」
2. 「From scratch」を選択、App名とワークスペースを設定
3. 左メニュー「OAuth & Permissions」→「Scopes」に以下を追加：
   - `chat:write`（メッセージ送信）
   - `channels:read`（チャンネル一覧取得）
   - `reactions:write`（リアクション追加）
   - `users:read`（ユーザー情報取得）
4. 「Install to Workspace」→ `Bot User OAuth Token`（`xoxb-`から始まる）をコピー

```bash
pip install slack-sdk python-dotenv
```

```
# .env
SLACK_BOT_TOKEN=xoxb-your-token-here
SLACK_CHANNEL_ID=C0XXXXXXXX  # チャンネルIDはURLから取得
```

---

## 基本：メッセージ送信

```python
import os
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError
from dotenv import load_dotenv

load_dotenv()
client = WebClient(token=os.environ["SLACK_BOT_TOKEN"])
CHANNEL = os.environ["SLACK_CHANNEL_ID"]

def post_message(text: str, channel: str = CHANNEL):
    try:
        response = client.chat_postMessage(channel=channel, text=text)
        print(f"送信完了: {response['ts']}")
        return response
    except SlackApiError as e:
        print(f"エラー: {e.response['error']}")

post_message("テスト送信です")
```

---

## Block Kit でリッチなメッセージを送る

テキストだけでなく、ボタンや区切り線を使ったリッチなメッセージを送れます。

```python
def post_rich_message(title: str, items: list[dict]):
    """
    items: [{"label": "売上", "value": "¥1,250,000", "emoji": "📈"}, ...]
    """
    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": title}
        },
        {"type": "divider"}
    ]
    
    for item in items:
        blocks.append({
            "type": "section",
            "fields": [
                {"type": "mrkdwn", "text": f"*{item['label']}*"},
                {"type": "mrkdwn", "text": f"{item['emoji']} {item['value']}"}
            ]
        })
    
    blocks.append({"type": "divider"})
    blocks.append({
        "type": "context",
        "elements": [
            {"type": "mrkdwn", "text": f"自動生成 | {__import__('datetime').datetime.now().strftime('%Y/%m/%d %H:%M')}"}
        ]
    })
    
    client.chat_postMessage(channel=CHANNEL, blocks=blocks, text=title)

# 使用例
post_rich_message("📊 本日の売上サマリー", [
    {"label": "売上合計", "value": "¥1,250,000", "emoji": "💰"},
    {"label": "受注件数", "value": "45件", "emoji": "📦"},
    {"label": "新規顧客", "value": "3社", "emoji": "🆕"},
    {"label": "目標達成率", "value": "125%", "emoji": "🎯"},
])
```

---

## 実践レシピ

### レシピ① 毎朝の日報リマインダー

```python
# scripts/morning_reminder.py
import os
from slack_sdk import WebClient
from datetime import datetime

client = WebClient(token=os.environ["SLACK_BOT_TOKEN"])
CHANNEL = os.environ["SLACK_CHANNEL_ID"]

def send_morning_reminder():
    today = datetime.now().strftime("%Y年%m月%d日（%a）")
    
    blocks = [
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"☀️ *おはようございます！{today}の日報をお願いします*"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*テンプレート:*\n```【今日の予定】\n- \n\n【昨日の成果】\n- \n\n【課題・相談】\n- なし```"
            }
        }
    ]
    
    client.chat_postMessage(
        channel=CHANNEL,
        blocks=blocks,
        text="日報リマインダー"
    )

send_morning_reminder()
```

```yaml
# .github/workflows/morning-reminder.yml
name: Morning Reminder
on:
  schedule:
    - cron: '0 0 * * 1-5'  # 平日 朝9時JST
jobs:
  remind:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install slack-sdk
      - run: python scripts/morning_reminder.py
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
          SLACK_CHANNEL_ID: ${{ secrets.SLACK_CHANNEL_ID }}
```

---

### レシピ② GitHubのPRをSlackに通知

新しいPRが作られたらSlackに即通知。GitHub Actionsから呼び出す。

```python
# scripts/notify_pr.py
import os
import sys
from slack_sdk import WebClient

client = WebClient(token=os.environ["SLACK_BOT_TOKEN"])
CHANNEL = os.environ["SLACK_CHANNEL_ID"]

pr_title = os.environ.get("PR_TITLE", "")
pr_url = os.environ.get("PR_URL", "")
pr_author = os.environ.get("PR_AUTHOR", "")
pr_body = os.environ.get("PR_BODY", "")[:100]  # 最初の100文字

blocks = [
    {
        "type": "section",
        "text": {
            "type": "mrkdwn",
            "text": f"🔔 *新しいPRが作成されました*\n<{pr_url}|{pr_title}>"
        }
    },
    {
        "type": "section",
        "fields": [
            {"type": "mrkdwn", "text": f"*作成者*\n{pr_author}"},
            {"type": "mrkdwn", "text": f"*概要*\n{pr_body or '（説明なし）'}"}
        ]
    },
    {
        "type": "actions",
        "elements": [
            {
                "type": "button",
                "text": {"type": "plain_text", "text": "PRを確認する"},
                "url": pr_url,
                "style": "primary"
            }
        ]
    }
]

client.chat_postMessage(channel=CHANNEL, blocks=blocks, text=f"新PR: {pr_title}")
```

```yaml
# .github/workflows/pr-notify.yml
name: PR Slack Notification
on:
  pull_request:
    types: [opened]
jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install slack-sdk
      - run: python scripts/notify_pr.py
        env:
          SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
          SLACK_CHANNEL_ID: ${{ secrets.SLACK_CHANNEL_ID }}
          PR_TITLE: ${{ github.event.pull_request.title }}
          PR_URL: ${{ github.event.pull_request.html_url }}
          PR_AUTHOR: ${{ github.event.pull_request.user.login }}
          PR_BODY: ${{ github.event.pull_request.body }}
```

---

### レシピ③ 外部APIのデータを定期通知

天気・為替・株価などの外部データを定期的にSlackへ。

```python
# scripts/notify_weather.py
import os
import requests
from slack_sdk import WebClient

client = WebClient(token=os.environ["SLACK_BOT_TOKEN"])
CHANNEL = os.environ["SLACK_CHANNEL_ID"]
OPENWEATHER_KEY = os.environ["OPENWEATHER_API_KEY"]

def get_weather(city: str = "Tokyo") -> dict:
    res = requests.get(
        "https://api.openweathermap.org/data/2.5/weather",
        params={
            "q": city,
            "appid": OPENWEATHER_KEY,
            "units": "metric",
            "lang": "ja"
        }
    )
    data = res.json()
    return {
        "description": data["weather"][0]["description"],
        "temp": round(data["main"]["temp"]),
        "humidity": data["main"]["humidity"],
        "wind": round(data["wind"]["speed"])
    }

weather = get_weather()

emoji_map = {
    "晴れ": "☀️", "曇": "☁️", "雨": "🌧️", "雪": "❄️", "霧": "🌫️"
}
emoji = next((v for k, v in emoji_map.items() if k in weather["description"]), "🌡️")

client.chat_postMessage(
    channel=CHANNEL,
    text=f"{emoji} 今日の東京の天気: {weather['description']} {weather['temp']}°C 湿度{weather['humidity']}% 風速{weather['wind']}m/s"
)
```

---

### レシピ④ メッセージへのリアクションで承認フロー

特定のリアクションが押されたら処理を実行するEvent API版。

```python
# app.py (Flask + Slack Events API)
from flask import Flask, request, jsonify
from slack_sdk import WebClient
import os, hmac, hashlib, time

app = Flask(__name__)
client = WebClient(token=os.environ["SLACK_BOT_TOKEN"])
SIGNING_SECRET = os.environ["SLACK_SIGNING_SECRET"]

def verify_slack_signature(req) -> bool:
    """Slackからのリクエストを検証"""
    timestamp = req.headers.get("X-Slack-Request-Timestamp", "")
    if abs(time.time() - int(timestamp)) > 60 * 5:
        return False
    sig_basestring = f"v0:{timestamp}:{req.get_data(as_text=True)}"
    expected = "v0=" + hmac.new(
        SIGNING_SECRET.encode(), sig_basestring.encode(), hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, req.headers.get("X-Slack-Signature", ""))

@app.route("/slack/events", methods=["POST"])
def slack_events():
    if not verify_slack_signature(request):
        return jsonify({"error": "unauthorized"}), 403
    
    data = request.json
    
    # URL検証
    if data.get("type") == "url_verification":
        return jsonify({"challenge": data["challenge"]})
    
    event = data.get("event", {})
    
    # ✅リアクションが押されたら承認通知
    if event.get("type") == "reaction_added" and event.get("reaction") == "white_check_mark":
        item = event.get("item", {})
        if item.get("type") == "message":
            client.chat_postMessage(
                channel=item["channel"],
                thread_ts=item["ts"],
                text=f"✅ <@{event['user']}> が承認しました"
            )
    
    return jsonify({"ok": True})

if __name__ == "__main__":
    app.run(port=3000)
```

---

### レシピ⑤ スケジュールされたメッセージ送信

特定の日時にメッセージを予約送信。

```python
from datetime import datetime
import pytz

def schedule_message(text: str, send_at: datetime, channel: str = CHANNEL):
    """指定日時にメッセージを予約送信"""
    jst = pytz.timezone("Asia/Tokyo")
    if send_at.tzinfo is None:
        send_at = jst.localize(send_at)
    
    unix_timestamp = int(send_at.timestamp())
    
    response = client.chat_scheduleMessage(
        channel=channel,
        text=text,
        post_at=unix_timestamp
    )
    print(f"予約完了: {send_at.strftime('%Y/%m/%d %H:%M')} に送信予定")
    return response["scheduled_message_id"]

def cancel_scheduled_message(message_id: str, channel: str = CHANNEL):
    """予約済みメッセージをキャンセル"""
    client.chat_deleteScheduledMessage(
        channel=channel,
        scheduled_message_id=message_id
    )

# 来週月曜9時に送信予約
from datetime import timedelta
next_monday = datetime.now() + timedelta(days=(7 - datetime.now().weekday()))
send_time = next_monday.replace(hour=9, minute=0, second=0, microsecond=0)
schedule_message("📋 週次ミーティングの時間です！アジェンダを確認してください", send_time)
```

---

## セキュリティの注意点

:::message alert
`SLACK_BOT_TOKEN`は絶対にコードに直書きしないこと。Gitに上がった場合、Slackがトークンを自動で無効化します。
:::

```bash
# .gitignore に追加必須
.env
*.env
```

---

## まとめ

Slack Botで自動化できる主なユースケース：

| ユースケース | 難易度 | 効果 |
|------------|--------|------|
| 定時リマインダー | ★☆☆ | 見落とし防止 |
| 外部API通知 | ★★☆ | 情報収集の自動化 |
| GitHub連携通知 | ★★☆ | 開発チームの情報共有 |
| 承認フロー | ★★★ | 手動確認作業の削減 |
| スケジュール送信 | ★☆☆ | 定期連絡の自動化 |

まず「毎日手動でSlackに投稿していること」をリストアップして、簡単なものから自動化してみてください。
