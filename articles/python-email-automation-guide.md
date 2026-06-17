---
title: "Pythonでメール自動送信・自動受信を完全攻略【Gmail・SMTP実践ガイド】"
emoji: "📧"
type: "tech"
topics: ["python", "gmail", "smtp", "自動化", "business"]
published: true
---

# Pythonでメール自動送信・自動受信を完全攻略【Gmail・SMTP実践ガイド】

「毎月末に同じ内容のメールを20人に送っている」「特定のメールが届いたら自動でデータを処理したい」。Pythonを使えば送受信を完全自動化できます。Gmail・SMTPの設定から実践レシピまでコード付きで解説します。

---

## 事前準備：Gmailアプリパスワードの取得

Googleアカウントの通常パスワードはSMTPでは使えません。アプリパスワードを使います。

1. Googleアカウント → セキュリティ
2. 「2段階認証プロセス」をONにする（必須）
3. 「アプリパスワード」を選択
4. アプリ: メール、デバイス: その他（Python）→ 生成
5. 表示された16文字のパスワードをコピー

```bash
pip install yagmail python-dotenv
```

```
# .env
GMAIL_ADDRESS=your@gmail.com
GMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx
```

---

## 基本：メール送信（yagmail）

yagmailはsmtplibのラッパーで、Gmailに特化したシンプルなライブラリです。

```python
import yagmail
import os
from dotenv import load_dotenv

load_dotenv()

yag = yagmail.SMTP(
    user=os.environ["GMAIL_ADDRESS"],
    password=os.environ["GMAIL_APP_PASSWORD"]
)

# シンプルなテキストメール
yag.send(
    to="recipient@example.com",
    subject="テスト送信",
    contents="本文です。"
)

# HTML形式＋添付ファイル
yag.send(
    to=["a@example.com", "b@example.com"],
    subject="月次レポート",
    contents=[
        "<h2>今月のレポートをお送りします</h2><p>詳細は添付をご確認ください。</p>",
        "/path/to/report.xlsx"  # 添付ファイルのパスを渡すだけ
    ]
)
```

---

## 基本：メール送信（smtplib）

標準ライブラリだけで送る場合はsmtplib。外部ライブラリ不要。

```python
import smtplib
import os
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication
from pathlib import Path

def send_email(
    to: str | list[str],
    subject: str,
    body: str,
    attachments: list[str] = None,
    html: bool = False
):
    GMAIL = os.environ["GMAIL_ADDRESS"]
    PASSWORD = os.environ["GMAIL_APP_PASSWORD"]

    msg = MIMEMultipart()
    msg["From"] = GMAIL
    msg["To"] = to if isinstance(to, str) else ", ".join(to)
    msg["Subject"] = subject

    mime_type = "html" if html else "plain"
    msg.attach(MIMEText(body, mime_type, "utf-8"))

    # 添付ファイル
    for filepath in (attachments or []):
        with open(filepath, "rb") as f:
            part = MIMEApplication(f.read(), Name=Path(filepath).name)
            part["Content-Disposition"] = f'attachment; filename="{Path(filepath).name}"'
            msg.attach(part)

    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
        server.login(GMAIL, PASSWORD)
        server.send_message(msg)

    print(f"送信完了: {subject} → {to}")
```

---

## 実践レシピ

### レシピ① 宛先リストへの一括送信（差し込み）

CSVの顧客リストに個別メールを一括送信。

```python
import csv
import time

def send_bulk_personalized(
    csv_path: str,
    subject_template: str,
    body_template: str
):
    """
    CSV形式: name,email,company,amount
    テンプレートの{name}{company}等を自動で置換
    """
    with open(csv_path, encoding="utf-8") as f:
        customers = list(csv.DictReader(f))

    success, failed = 0, 0

    for i, customer in enumerate(customers):
        try:
            subject = subject_template.format(**customer)
            body = body_template.format(**customer)

            yag.send(
                to=customer["email"],
                subject=subject,
                contents=body
            )
            success += 1
            print(f"[{i+1}/{len(customers)}] 送信: {customer['email']}")

        except Exception as e:
            failed += 1
            print(f"[失敗] {customer['email']}: {e}")

        time.sleep(1)  # 連続送信制限対策

    print(f"\n完了: 成功{success}件 / 失敗{failed}件")

# 使用例
send_bulk_personalized(
    csv_path="customers.csv",
    subject_template="【{company}様】6月の請求書をお送りします",
    body_template="""\
{name}様

お世話になっております。
{company}様の6月分の請求書（¥{amount}）をお送りします。

ご確認をお願いいたします。

automate.jp
"""
)
```

---

### レシピ② Gmailの受信メールを自動処理

特定の件名のメールを検索して内容を取得・処理。

```python
import imaplib
import email
from email.header import decode_header
import os

def fetch_emails(subject_filter: str, max_count: int = 10) -> list[dict]:
    """件名でフィルタリングしてメール内容を取得"""
    GMAIL = os.environ["GMAIL_ADDRESS"]
    PASSWORD = os.environ["GMAIL_APP_PASSWORD"]

    mail = imaplib.IMAP4_SSL("imap.gmail.com")
    mail.login(GMAIL, PASSWORD)
    mail.select("inbox")

    # 件名で検索
    _, message_ids = mail.search(None, f'SUBJECT "{subject_filter}" UNSEEN')
    ids = message_ids[0].split()[-max_count:]  # 最新N件

    results = []
    for mid in ids:
        _, msg_data = mail.fetch(mid, "(RFC822)")
        msg = email.message_from_bytes(msg_data[0][1])

        # 件名のデコード
        subject, encoding = decode_header(msg["Subject"])[0]
        if isinstance(subject, bytes):
            subject = subject.decode(encoding or "utf-8")

        # 本文取得
        body = ""
        if msg.is_multipart():
            for part in msg.walk():
                if part.get_content_type() == "text/plain":
                    body = part.get_payload(decode=True).decode("utf-8", errors="ignore")
                    break
        else:
            body = msg.get_payload(decode=True).decode("utf-8", errors="ignore")

        results.append({
            "subject": subject,
            "from": msg["From"],
            "date": msg["Date"],
            "body": body.strip()
        })

        mail.store(mid, "+FLAGS", "\\Seen")  # 既読にする

    mail.logout()
    return results

# 使用例：「注文確認」という件名のメールを全部取得
emails = fetch_emails("注文確認")
for e in emails:
    print(f"{e['date']} | {e['from']}")
    print(e['body'][:200])
    print("---")
```

---

### レシピ③ 添付ファイルを自動保存

注文書・請求書などの添付PDFを自動でフォルダに保存。

```python
import imaplib
import email
from pathlib import Path
import os

def save_attachments(subject_filter: str, save_dir: str = "./attachments"):
    Path(save_dir).mkdir(exist_ok=True)
    GMAIL = os.environ["GMAIL_ADDRESS"]
    PASSWORD = os.environ["GMAIL_APP_PASSWORD"]

    mail = imaplib.IMAP4_SSL("imap.gmail.com")
    mail.login(GMAIL, PASSWORD)
    mail.select("inbox")

    _, ids = mail.search(None, f'SUBJECT "{subject_filter}"')
    saved_files = []

    for mid in ids[0].split():
        _, msg_data = mail.fetch(mid, "(RFC822)")
        msg = email.message_from_bytes(msg_data[0][1])

        for part in msg.walk():
            if part.get_content_disposition() == "attachment":
                filename_raw = part.get_filename()
                if not filename_raw:
                    continue

                filename, enc = decode_header(filename_raw)[0]
                if isinstance(filename, bytes):
                    filename = filename.decode(enc or "utf-8")

                filepath = Path(save_dir) / filename
                filepath.write_bytes(part.get_payload(decode=True))
                saved_files.append(str(filepath))
                print(f"保存: {filepath}")

    mail.logout()
    print(f"\n{len(saved_files)}件の添付ファイルを保存しました")
    return saved_files

# 「請求書」という件名のメールの添付PDFを全部保存
save_attachments("請求書", "./invoices")
```

---

### レシピ④ GitHub Actionsで月末に自動送信

月末に自動でレポートメールを送信。

```yaml
# .github/workflows/monthly-email.yml
name: Monthly Report Email
on:
  schedule:
    - cron: '0 0 L * *'  # 毎月末日 朝9時JST
    # 注: GitHub ActionsはLをサポートしないため
    # 代わりに cron: '0 0 28-31 * *' で実行し
    # スクリプト内で月末かチェックする
jobs:
  send:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install yagmail python-dotenv
      - name: Check if last day of month
        run: |
          python -c "
          from datetime import datetime, timedelta
          import sys
          today = datetime.today()
          tomorrow = today + timedelta(days=1)
          if tomorrow.month != today.month:
              print('Last day of month')
          else:
              print('Not last day, skipping')
              sys.exit(1)
          "
      - run: python scripts/send_monthly_report.py
        env:
          GMAIL_ADDRESS: ${{ secrets.GMAIL_ADDRESS }}
          GMAIL_APP_PASSWORD: ${{ secrets.GMAIL_APP_PASSWORD }}
```

```python
# scripts/send_monthly_report.py
import yagmail
import os
from datetime import datetime

yag = yagmail.SMTP(os.environ["GMAIL_ADDRESS"], os.environ["GMAIL_APP_PASSWORD"])
month = datetime.now().strftime("%Y年%m月")

yag.send(
    to="manager@example.com",
    subject=f"【自動送信】{month}の月次レポート",
    contents=f"<h2>{month}のレポートです</h2><p>添付をご確認ください。</p>",
    attachments=["output/monthly_report.xlsx"]
)
print("月次レポートを送信しました")
```

---

## 送信制限と注意点

| サービス | 1日の送信上限 | 注意点 |
|---------|------------|--------|
| Gmail（無料） | 500通 | アプリパスワード必須 |
| Gmail（Workspace） | 2,000通 | ビジネス用途向け |
| SendGrid（無料枠） | 100通/日 | 大量送信なら推奨 |

:::message alert
短時間に大量送信するとスパム判定されます。`time.sleep(1)`を必ず入れて1秒以上間隔を空けてください。
:::

---

## まとめ

メール自動化で削減できる作業：

| 作業 | 削減効果 |
|------|---------|
| 月末の一斉請求メール | 毎月2〜3時間→0分 |
| 注文確認メールの処理 | 見落としゼロ |
| 添付ファイルの保存 | 手動保存不要 |
| 定期レポート送信 | 完全自動化 |

「毎月同じメールを送っている」作業から始めると効果を実感しやすいです。
