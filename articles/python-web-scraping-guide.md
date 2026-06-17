---
title: "Pythonでウェブスクレイピング完全ガイド【requests + BeautifulSoup実践】"
emoji: "🕷️"
type: "tech"
topics: ["python", "scraping", "beautifulsoup", "requests", "自動化"]
published: true
---

# Pythonでウェブスクレイピング完全ガイド【requests + BeautifulSoup実践】

「毎日同じサイトを開いて情報をコピーしている」「競合の価格を手動でチェックしている」。これらはPythonのスクレイピングで自動化できます。基本から実務で使えるパターンまで、動くコードで解説します。

:::message
スクレイピングを行う前に必ず対象サイトの利用規約・robots.txtを確認してください。アクセス間隔は必ず1秒以上空け、サーバーに負荷をかけないよう注意してください。
:::

---

## セットアップ

```bash
pip install requests beautifulsoup4 lxml
```

---

## 基本：HTMLを取得してパース

```python
import requests
from bs4 import BeautifulSoup
import time

def fetch_page(url: str) -> BeautifulSoup:
    headers = {
        "User-Agent": "Mozilla/5.0 (compatible; MyBot/1.0)"
    }
    response = requests.get(url, headers=headers, timeout=10)
    response.raise_for_status()  # 4xx/5xxはエラーを投げる
    response.encoding = response.apparent_encoding  # 文字化け防止
    return BeautifulSoup(response.text, "lxml")

soup = fetch_page("https://example.com")
print(soup.title.text)
```

---

## 要素の取得方法

```python
# タグで取得
h1 = soup.find("h1")
print(h1.text.strip())

# CSSセレクタで取得（最もよく使う）
price = soup.select_one(".price")
items = soup.select("ul.list > li")

# 属性で絞り込む
link = soup.find("a", {"class": "btn-primary"})
print(link["href"])  # 属性値を取得

# 複数取得してループ
for item in soup.select(".product-card"):
    name = item.select_one(".name").text.strip()
    price = item.select_one(".price").text.strip()
    print(f"{name}: {price}")

# テキストのみ取得（タグを除去）
body_text = soup.get_text(separator="\n", strip=True)
```

---

## 実践レシピ

### レシピ① ニュースサイトの見出しを毎朝収集

```python
import requests
from bs4 import BeautifulSoup
import csv
from datetime import datetime

def collect_tech_news() -> list[dict]:
    """Zennのトレンド記事タイトルを収集する例"""
    soup = fetch_page("https://zenn.dev")
    articles = []

    for card in soup.select("article"):
        title_el = card.select_one("h2, h3")
        link_el = card.select_one("a[href]")
        if not title_el or not link_el:
            continue

        articles.append({
            "title": title_el.text.strip(),
            "url": "https://zenn.dev" + link_el["href"],
            "collected_at": datetime.now().isoformat()
        })

    return articles

def save_to_csv(articles: list[dict], filepath: str):
    if not articles:
        return
    with open(filepath, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=articles[0].keys())
        if f.tell() == 0:
            writer.writeheader()
        writer.writerows(articles)

articles = collect_tech_news()
save_to_csv(articles, "news_log.csv")
print(f"{len(articles)}件収集")
```

---

### レシピ② 複数ページにまたがるデータを収集（ページネーション対応）

```python
import time

def scrape_all_pages(base_url: str, max_pages: int = 10) -> list[dict]:
    all_items = []

    for page in range(1, max_pages + 1):
        url = f"{base_url}?page={page}"
        soup = fetch_page(url)

        items = soup.select(".item")
        if not items:
            print(f"p{page}: データなし → 終了")
            break

        for item in items:
            all_items.append({
                "name": item.select_one(".name").text.strip(),
                "price": item.select_one(".price").text.strip(),
                "page": page
            })

        print(f"p{page}: {len(items)}件取得（累計 {len(all_items)}件）")
        time.sleep(1)  # 必ず1秒待機

    return all_items
```

---

### レシピ③ JavaScript描画のページを取得（Playwright）

requestsはJavaScriptを実行しません。SPAや動的サイトにはPlaywrightを使います。

```bash
pip install playwright
playwright install chromium
```

```python
from playwright.sync_api import sync_playwright
import time

def fetch_dynamic_page(url: str) -> str:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()

        page.goto(url, wait_until="networkidle")
        time.sleep(1)  # 追加の待機

        # 特定の要素が表示されるまで待つ
        page.wait_for_selector(".product-list", timeout=10000)

        content = page.content()
        browser.close()
        return content

html = fetch_dynamic_page("https://example.com/spa")
soup = BeautifulSoup(html, "lxml")
```

---

### レシピ④ ログインが必要なサイト（セッション管理）

```python
import requests
from bs4 import BeautifulSoup

session = requests.Session()
session.headers.update({"User-Agent": "Mozilla/5.0"})

def login(login_url: str, username: str, password: str):
    # ログインページのCSRFトークンを取得
    soup = BeautifulSoup(session.get(login_url).text, "lxml")
    csrf = soup.find("input", {"name": "_token"})
    csrf_token = csrf["value"] if csrf else ""

    # ログイン実行
    response = session.post(login_url, data={
        "email": username,
        "password": password,
        "_token": csrf_token
    })
    return response.ok

def fetch_private_page(url: str) -> BeautifulSoup:
    response = session.get(url)
    return BeautifulSoup(response.text, "lxml")

login("https://example.com/login", "user@example.com", "password")
soup = fetch_private_page("https://example.com/dashboard")
```

---

### レシピ⑤ スクレイピング結果をSlackに自動通知

GitHub Actionsと組み合わせて毎日定時実行。

```python
# scripts/price_monitor.py
import requests
from bs4 import BeautifulSoup
import os

SLACK_WEBHOOK = os.environ["SLACK_WEBHOOK"]
TARGET_URL = os.environ["TARGET_URL"]
PRICE_THRESHOLD = int(os.environ.get("PRICE_THRESHOLD", "10000"))

def get_price(url: str) -> int:
    soup = fetch_page(url)
    price_text = soup.select_one(".price").text.strip()
    # "¥12,800" → 12800
    return int(price_text.replace("¥", "").replace(",", ""))

price = get_price(TARGET_URL)
print(f"現在価格: ¥{price:,}")

if price <= PRICE_THRESHOLD:
    requests.post(SLACK_WEBHOOK, json={
        "text": f"🔔 価格アラート！¥{price:,}（閾値: ¥{PRICE_THRESHOLD:,}以下）\n{TARGET_URL}"
    })
```

```yaml
# .github/workflows/price-monitor.yml
name: Price Monitor
on:
  schedule:
    - cron: '0 0 * * *'  # 毎朝9時JST
jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install requests beautifulsoup4 lxml
      - run: python scripts/price_monitor.py
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
          TARGET_URL: ${{ secrets.TARGET_URL }}
          PRICE_THRESHOLD: "9800"
```

---

## エラー対策まとめ

```python
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_session() -> requests.Session:
    session = requests.Session()

    # 自動リトライ設定
    retry = Retry(
        total=3,
        backoff_factor=1,  # 1秒, 2秒, 4秒で再試行
        status_forcelist=[429, 500, 502, 503, 504]
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("http://", adapter)
    session.mount("https://", adapter)

    session.headers.update({
        "User-Agent": "Mozilla/5.0 (compatible; ResearchBot/1.0)"
    })
    return session
```

---

## よくあるエラーと対処法

| エラー | 原因 | 対処 |
|--------|------|------|
| `403 Forbidden` | ボット判定 | User-Agentを設定する |
| `429 Too Many Requests` | アクセス過多 | `time.sleep()`を増やす |
| 文字化け | エンコーディング | `response.encoding = response.apparent_encoding` |
| `None`エラー | 要素が見つからない | `if el:` で存在確認 |
| JS描画のページが取れない | requestsの限界 | Playwrightに切り替え |

---

## まとめ

スクレイピングで自動化できる作業：

| 作業 | 効果 |
|------|------|
| 競合の価格チェック | 毎日30分→0分 |
| ニュース・トレンド収集 | 情報収集を完全自動化 |
| 求人情報の監視 | 条件に合う求人を即通知 |
| 在庫・価格アラート | 購入タイミングを逃さない |

まず「毎日手動で確認しているサイト」を1つ選んでスクレイピングしてみてください。
