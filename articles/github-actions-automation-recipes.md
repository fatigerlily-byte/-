---
title: "GitHub Actionsで毎日の作業を自動化する実践レシピ10選"
emoji: "⚙️"
type: "tech"
topics: ["githubactions", "automation", "ci", "python", "devops"]
published: true
---

# GitHub Actionsで毎日の作業を自動化する実践レシピ10選

「定期的に動かしたいスクリプトがある」「毎朝手動でやっている確認作業を自動化したい」。GitHub Actionsはそのための最強ツールです。無料枠（パブリックリポジトリは無制限、プライベートは月2000分）だけでほとんどのユースケースをカバーできます。

すぐ使えるYAMLとPythonをセットで紹介します。

---

## GitHub Actionsの基本構造（30秒で理解）

```yaml
name: ワークフロー名
on:
  schedule:
    - cron: '0 0 * * *'   # UTC基準。日本時間は+9時間
  push:                    # pushでも動かす場合
    branches: [main]

jobs:
  job名:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4   # リポジトリをチェックアウト
      - name: ステップ名
        run: echo "ここにコマンド"
```

**cron記法早見表:**

| 日本時間 | cron (UTC) |
|---------|-----------|
| 毎朝9時 | `0 0 * * *` |
| 平日9時 | `0 0 * * 1-5` |
| 毎時 | `0 * * * *` |
| 月曜9時 | `0 0 * * 1` |

---

## レシピ①：毎朝のSlack日報を自動送信

チームの日次スタンドアップ情報をGitHub Issues/PRから収集してSlackに通知。

```yaml
# .github/workflows/morning-standup.yml
name: Morning Standup Report
on:
  schedule:
    - cron: '0 0 * * 1-5'
jobs:
  standup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install requests
      - name: Send standup
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
          REPO: ${{ github.repository }}
        run: python scripts/standup.py
```

```python
# scripts/standup.py
import requests
import os
from datetime import datetime, timedelta

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
SLACK_WEBHOOK = os.environ["SLACK_WEBHOOK"]
REPO = os.environ["REPO"]

headers = {"Authorization": f"token {GITHUB_TOKEN}"}
yesterday = (datetime.utcnow() - timedelta(days=1)).strftime("%Y-%m-%dT%H:%M:%SZ")

# 昨日マージされたPRを取得
prs = requests.get(
    f"https://api.github.com/repos/{REPO}/pulls?state=closed&sort=updated",
    headers=headers
).json()

merged_yesterday = [
    pr for pr in prs
    if pr.get("merged_at") and pr["merged_at"] > yesterday
]

# オープン中のPRを取得
open_prs = requests.get(
    f"https://api.github.com/repos/{REPO}/pulls?state=open",
    headers=headers
).json()

message = f"""*📋 デイリーレポート {datetime.now().strftime('%Y/%m/%d')}*

*昨日マージされたPR: {len(merged_yesterday)}件*
{chr(10).join(f"  • <{pr['html_url']}|{pr['title']}>" for pr in merged_yesterday[:5])}

*レビュー待ちPR: {len(open_prs)}件*
{chr(10).join(f"  • <{pr['html_url']}|{pr['title']}>" for pr in open_prs[:5])}
"""

requests.post(SLACK_WEBHOOK, json={"text": message})
print("Slack通知完了")
```

---

## レシピ②：依存パッケージの自動アップデートPR

`pip-compile` や `npm outdated` を定期実行してアップデートPRを自動作成。

```yaml
# .github/workflows/update-deps.yml
name: Weekly Dependency Update
on:
  schedule:
    - cron: '0 0 * * 1'  # 毎週月曜9時
permissions:
  contents: write
  pull-requests: write
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install pip-tools
      - name: Update requirements
        run: pip-compile --upgrade requirements.in -o requirements.txt
      - name: Create PR if changed
        uses: peter-evans/create-pull-request@v6
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          commit-message: "chore: update dependencies"
          title: "⬆️ 依存パッケージの自動アップデート"
          body: |
            pip-compileによる自動アップデートです。
            変更内容を確認してマージしてください。
          branch: auto-update-deps
          labels: dependencies
```

---

## レシピ③：定期的なデータ収集＆CSV保存

APIからデータを収集してリポジトリにコミット。ダッシュボードや分析に使える。

```yaml
# .github/workflows/collect-data.yml
name: Daily Data Collection
on:
  schedule:
    - cron: '0 1 * * *'  # 毎朝10時JST
permissions:
  contents: write
jobs:
  collect:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install requests
      - run: python scripts/collect.py
      - name: Commit data
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add data/
          git diff --staged --quiet || git commit -m "data: $(date +'%Y-%m-%d') 自動収集"
          git push
```

```python
# scripts/collect.py
import requests
import csv
import os
from datetime import datetime

# 例: GitHub自リポジトリのスター数を記録
REPO = "your-username/your-repo"
token = os.environ.get("GITHUB_TOKEN", "")

res = requests.get(
    f"https://api.github.com/repos/{REPO}",
    headers={"Authorization": f"token {token}"}
)
data = res.json()

os.makedirs("data", exist_ok=True)
filepath = "data/stats.csv"
is_new = not os.path.exists(filepath)

with open(filepath, "a", newline="") as f:
    writer = csv.writer(f)
    if is_new:
        writer.writerow(["date", "stars", "forks", "open_issues"])
    writer.writerow([
        datetime.now().strftime("%Y-%m-%d"),
        data.get("stargazers_count", 0),
        data.get("forks_count", 0),
        data.get("open_issues_count", 0),
    ])

print(f"データを記録しました: stars={data.get('stargazers_count')}")
```

---

## レシピ④：古いIssueの自動クローズ

90日以上放置されたIssueに警告コメント→さらに7日後にクローズ。

```yaml
# .github/workflows/stale-issues.yml
name: Stale Issues
on:
  schedule:
    - cron: '0 1 * * *'
jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v9
        with:
          stale-issue-message: |
            このIssueは90日間更新がありませんでした。
            7日以内に反応がない場合、自動的にクローズします。
          close-issue-message: |
            長期間更新がなかったため、自動クローズしました。
            再度必要な場合は新しいIssueを作成してください。
          days-before-stale: 90
          days-before-close: 7
          stale-issue-label: 'stale'
          exempt-issue-labels: 'pinned,security'
```

---

## レシピ⑤：テスト結果をSlackに通知

PRのテスト結果を自動でSlack通知。失敗時はメンションも付ける。

```yaml
# .github/workflows/test-notify.yml
name: Test and Notify
on:
  pull_request:
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install pytest
      - name: Run tests
        id: test
        run: pytest --tb=short 2>&1 | tee test-output.txt
        continue-on-error: true
      - name: Notify Slack
        if: always()
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK }}
          TEST_RESULT: ${{ steps.test.outcome }}
          PR_URL: ${{ github.event.pull_request.html_url }}
          PR_TITLE: ${{ github.event.pull_request.title }}
        run: |
          python -c "
          import requests, os
          result = os.environ['TEST_RESULT']
          emoji = '✅' if result == 'success' else '❌'
          requests.post(os.environ['SLACK_WEBHOOK'], json={
            'text': f\"{emoji} テスト{result}\n*PR*: <{os.environ['PR_URL']}|{os.environ['PR_TITLE']}>\"
          })
          "
```

---

## レシピ⑥：週次レポートをMarkdownで自動生成

週の活動サマリーをMarkdownファイルとして自動生成してコミット。

```yaml
# .github/workflows/weekly-report.yml
name: Weekly Report Generator
on:
  schedule:
    - cron: '0 1 * * 5'  # 毎週金曜10時JST
permissions:
  contents: write
jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install requests
      - name: Generate report
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          REPO: ${{ github.repository }}
        run: python scripts/weekly_report.py
      - name: Commit report
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add reports/
          git diff --staged --quiet || git commit -m "report: 週次レポート自動生成"
          git push
```

```python
# scripts/weekly_report.py
import requests
import os
from datetime import datetime, timedelta

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
REPO = os.environ["REPO"]
headers = {"Authorization": f"token {GITHUB_TOKEN}"}

week_ago = (datetime.utcnow() - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%SZ")

commits = requests.get(
    f"https://api.github.com/repos/{REPO}/commits?since={week_ago}",
    headers=headers
).json()

prs = requests.get(
    f"https://api.github.com/repos/{REPO}/pulls?state=closed&sort=updated",
    headers=headers
).json()
merged = [p for p in prs if p.get("merged_at") and p["merged_at"] > week_ago]

os.makedirs("reports", exist_ok=True)
week_str = datetime.now().strftime("%Y-W%V")
filepath = f"reports/{week_str}.md"

with open(filepath, "w") as f:
    f.write(f"""# 週次レポート {week_str}

## サマリー
- コミット数: {len(commits)}
- マージPR数: {len(merged)}

## マージされたPR
""")
    for pr in merged:
        f.write(f"- [{pr['title']}]({pr['html_url']})\n")
    
    f.write(f"\n## 最近のコミット\n")
    for commit in commits[:10]:
        msg = commit["commit"]["message"].split("\n")[0]
        f.write(f"- {msg}\n")

print(f"レポート生成: {filepath}")
```

---

## レシピ⑦：画像ファイルの自動最適化

PRに含まれる画像を自動でWebP変換・圧縮してコミット。

```yaml
# .github/workflows/optimize-images.yml
name: Optimize Images
on:
  pull_request:
    paths:
      - '**.png'
      - '**.jpg'
      - '**.jpeg'
permissions:
  contents: write
jobs:
  optimize:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.head_ref }}
      - run: sudo apt-get install -y webp imagemagick
      - name: Convert to WebP
        run: |
          find . -name "*.png" -o -name "*.jpg" | while read f; do
            cwebp -q 80 "$f" -o "${f%.*}.webp" && rm "$f"
          done
      - name: Commit optimized images
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          git diff --staged --quiet || git commit -m "chore: 画像をWebPに自動変換"
          git push
```

---

## レシピ⑧：環境変数・シークレットの有効期限チェック

APIキーなどの期限切れをSlackで事前通知。

```python
# scripts/check_secrets.py
import requests
import os
from datetime import datetime

SLACK_WEBHOOK = os.environ["SLACK_WEBHOOK"]

# チェックする期限リスト（環境変数から読み込む）
secrets_expiry = {
    "AWS_ACCESS_KEY": os.environ.get("AWS_KEY_EXPIRY", "2026-12-31"),
    "STRIPE_API_KEY": os.environ.get("STRIPE_KEY_EXPIRY", "2026-09-30"),
}

warnings = []
today = datetime.today()

for name, expiry_str in secrets_expiry.items():
    expiry = datetime.strptime(expiry_str, "%Y-%m-%d")
    days_left = (expiry - today).days
    if days_left <= 30:
        warnings.append(f"⚠️ {name} の期限まであと {days_left} 日 ({expiry_str})")

if warnings:
    requests.post(SLACK_WEBHOOK, json={
        "text": "🔑 *シークレット期限アラート*\n" + "\n".join(warnings)
    })
```

---

## レシピ⑨：README のバッジ自動更新

テスト通過率・カバレッジをREADMEのバッジに自動反映。

```yaml
# .github/workflows/update-badge.yml
name: Update Coverage Badge
on:
  push:
    branches: [main]
permissions:
  contents: write
jobs:
  coverage:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install pytest pytest-cov
      - name: Run tests with coverage
        run: pytest --cov=src --cov-report=json
      - name: Update README badge
        run: python scripts/update_badge.py
      - name: Commit badge update
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add README.md
          git diff --staged --quiet || git commit -m "docs: カバレッジバッジを更新"
          git push
```

---

## レシピ⑩：マルチ環境での自動テスト（matrix）

Python 3.11/3.12/3.13 × ubuntu/windows での互換性を一括確認。

```yaml
# .github/workflows/multi-env-test.yml
name: Multi-Environment Tests
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        python-version: ['3.11', '3.12', '3.13']
        os: [ubuntu-latest, windows-latest, macos-latest]
      fail-fast: false  # 1つ失敗しても全部実行
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
      - run: pip install pytest
      - run: pytest
```

これだけで9環境（3×3）を並列テストできます。

---

## シークレットの管理方法

GitHub ActionsでAPIキーを安全に使う手順：

1. リポジトリの **Settings → Secrets and variables → Actions**
2. **New repository secret** をクリック
3. `SLACK_WEBHOOK` などの名前で登録
4. YAMLで `${{ secrets.SLACK_WEBHOOK }}` として参照

:::message alert
シークレットは絶対にYAMLや`run:`に直書きしないこと。ログに残ります。
:::

---

## まとめ：自動化の優先順位

| 優先度 | 自動化対象 | 効果 |
|--------|----------|------|
| 高 | 毎日の定型チェック | 時間削減が大きい |
| 高 | テスト・デプロイ | ヒューマンエラー防止 |
| 中 | 依存パッケージ更新 | セキュリティリスク低減 |
| 中 | レポート生成 | 情報共有コスト削減 |
| 低 | 画像最適化 | パフォーマンス改善 |

「毎週手動でやっているな」と思うことをリストアップして、上から順に自動化していくのが効率的です。
