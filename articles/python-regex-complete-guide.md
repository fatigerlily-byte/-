---
title: "正規表現完全ガイド：Pythonで文字列処理を自動化する実践パターン30選"
emoji: "🔍"
type: "tech"
topics: ["python", "正規表現", "regex", "文字列処理", "自動化"]
published: true
---

# 正規表現完全ガイド：Pythonで文字列処理を自動化する実践パターン30選

「メールアドレスの抽出」「電話番号のフォーマット統一」「ログファイルの解析」。文字列処理の自動化に正規表現は欠かせません。「覚えられない」という人向けに、コピペで使えるパターン集として整理しました。

---

## 基本の使い方

```python
import re

text = "連絡先: user@example.com / 03-1234-5678"

# 検索（最初の1件）
match = re.search(r'\d{2,4}-\d{4}-\d{4}', text)
if match:
    print(match.group())  # 03-1234-5678

# 全件取得
emails = re.findall(r'[\w.+-]+@[\w-]+\.[a-z]{2,}', text)

# 置換
clean = re.sub(r'\s+', ' ', "余分な  スペース   を   削除")
# → "余分な スペースを 削除"

# 分割
parts = re.split(r'[,、。・]', "Python,JavaScript、Ruby。Go")
# → ['Python', 'JavaScript', 'Ruby', 'Go']
```

---

## フラグの使い方

```python
# 大文字小文字を区別しない
re.findall(r'python', text, re.IGNORECASE)

# 複数行モード（^$が各行の先頭末尾にマッチ）
re.findall(r'^ERROR.*', log_text, re.MULTILINE)

# 複数フラグの組み合わせ
re.findall(r'pattern', text, re.IGNORECASE | re.MULTILINE)
```

---

## パターン集30選

### 【連絡先・個人情報】

```python
# 1. メールアドレス
re.findall(r'[\w.+-]+@[\w-]+\.[a-z]{2,}', text)

# 2. 日本の電話番号（携帯・固定）
re.findall(r'0\d{1,4}-\d{2,4}-\d{4}', text)

# 3. 郵便番号
re.findall(r'\d{3}-\d{4}', text)

# 4. URLの抽出
re.findall(r'https?://[^\s"\'<>]+', text)

# 5. IPアドレス
re.findall(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b', text)

# 6. クレジットカード番号（マスキング用）
re.sub(r'\b(\d{4})[\s-]?\d{4}[\s-]?\d{4}[\s-]?(\d{4})\b',
       r'\1-****-****-\2', text)
```

---

### 【日付・時刻】

```python
# 7. YYYY-MM-DD形式
re.findall(r'\d{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12]\d|3[01])', text)

# 8. 日本語日付（2024年6月17日）
re.findall(r'\d{4}年\d{1,2}月\d{1,2}日', text)

# 9. 時刻（HH:MM または HH:MM:SS）
re.findall(r'\b(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d)?\b', text)

# 10. 日付形式の統一（スラッシュ→ハイフン）
re.sub(r'(\d{4})/(\d{2})/(\d{2})', r'\1-\2-\3', text)
```

---

### 【金額・数値】

```python
# 11. 金額（¥記号付き）
re.findall(r'¥[\d,]+', text)

# 12. カンマ区切り数値
re.findall(r'\d{1,3}(?:,\d{3})+', text)

# 13. パーセント
re.findall(r'\d+(?:\.\d+)?%', text)

# 14. カンマを除去して数値変換
prices = [int(p.replace(',', '')) for p in re.findall(r'[\d,]+', text)]
```

---

### 【HTML・コード処理】

```python
# 15. HTMLタグを除去
clean_text = re.sub(r'<[^>]+>', '', html_text)

# 16. href属性のURLを抽出
urls = re.findall(r'href=["\']([^"\']+)["\']', html_text)

# 17. コメントの除去（Python/JS）
no_comments = re.sub(r'#.*$', '', code, flags=re.MULTILINE)  # Python
no_comments = re.sub(r'//.*$', '', code, flags=re.MULTILINE)  # JS

# 18. 複数行コメントの除去
no_block_comments = re.sub(r'/\*.*?\*/', '', code, flags=re.DOTALL)
```

---

### 【テキスト整形】

```python
# 19. 連続空白を1つに
clean = re.sub(r'[ \t]+', ' ', text)

# 20. 空行を除去
no_blank = re.sub(r'\n\s*\n', '\n', text)

# 21. 行頭・行末の空白除去
clean = re.sub(r'^[ \t]+|[ \t]+$', '', text, flags=re.MULTILINE)

# 22. 全角スペースも含めた空白除去
clean = re.sub(r'[\s　]+', ' ', text).strip()

# 23. 句読点の統一（、。→ , . ）
normalized = re.sub(r'、', ', ', re.sub(r'。', '. ', text))

# 24. 記号のエスケープ
escaped = re.sub(r'([.*+?^${}()|[\]\\])', r'\\\1', user_input)
```

---

### 【ファイル・パス処理】

```python
# 25. 拡張子の抽出
re.findall(r'\.\w+$', filename, re.MULTILINE)

# 26. ファイル名から安全な文字のみ残す
safe_name = re.sub(r'[^\w\-_\. ]', '_', filename)

# 27. パスからファイル名を抽出
re.search(r'[^\\/]+$', filepath).group()

# 28. ログのIPとタイムスタンプを抽出
pattern = r'(\d{1,3}(?:\.\d{1,3}){3}).*\[(\d{2}/\w+/\d{4}:\d{2}:\d{2}:\d{2})'
for match in re.finditer(pattern, log_text):
    ip, timestamp = match.groups()
```

---

### 【日本語テキスト処理】

```python
# 29. ひらがなのみ抽出
re.findall(r'[ぁ-ん]+', text)

# 30. カタカナのみ抽出
re.findall(r'[ァ-ン]+', text)

# 漢字の抽出
re.findall(r'[一-龯]+', text)

# 全角英数字を半角に変換（unicodedataを使う方が確実）
import unicodedata
normalized = unicodedata.normalize('NFKC', text)
```

---

## 実践：ログファイルの解析

```python
import re
from collections import Counter
from datetime import datetime

def analyze_access_log(log_path: str) -> dict:
    """Apacheアクセスログを解析"""
    pattern = re.compile(
        r'(\d{1,3}(?:\.\d{1,3}){3})'   # IPアドレス
        r'.*\[(.+?)\]'                    # タイムスタンプ
        r'.*"(\w+) (.+?) HTTP'            # メソッド + パス
        r'.*" (\d{3})'                    # ステータスコード
        r' (\d+)'                         # レスポンスサイズ
    )

    ips = []
    paths = []
    status_codes = []
    errors = []

    with open(log_path) as f:
        for line in f:
            m = pattern.search(line)
            if not m:
                continue
            ip, timestamp, method, path, status, size = m.groups()
            ips.append(ip)
            paths.append(path)
            status_codes.append(status)
            if status.startswith(("4", "5")):
                errors.append({"path": path, "status": status, "ip": ip})

    return {
        "total_requests": len(ips),
        "unique_ips": len(set(ips)),
        "top_ips": Counter(ips).most_common(5),
        "top_paths": Counter(paths).most_common(5),
        "error_rate": f"{len(errors)/len(ips)*100:.1f}%",
        "recent_errors": errors[-10:]
    }

result = analyze_access_log("access.log")
for key, value in result.items():
    print(f"{key}: {value}")
```

---

## 実践：住所・連絡先の正規化

```python
def normalize_contact(raw: str) -> dict:
    """バラバラな形式の連絡先テキストを構造化"""
    result = {}

    # メールアドレス
    email_match = re.search(r'[\w.+-]+@[\w-]+\.[a-z]{2,}', raw, re.IGNORECASE)
    result["email"] = email_match.group() if email_match else None

    # 電話番号（ハイフン・スペース・括弧を正規化）
    phone_match = re.search(r'0[\d\-\(\)\s]{9,13}\d', raw)
    if phone_match:
        phone = re.sub(r'[\s\(\)\-]', '', phone_match.group())
        result["phone"] = f"{phone[:3]}-{phone[3:7]}-{phone[7:]}"
    else:
        result["phone"] = None

    # 郵便番号
    zip_match = re.search(r'〒?\s*(\d{3})[-−](\d{4})', raw)
    result["zip"] = f"{zip_match.group(1)}-{zip_match.group(2)}" if zip_match else None

    return result

# 使用例
raw_text = """
お問い合わせ先:
メール: info＠example.co.jp
TEL: (03)1234-5678
〒 150-0001
"""
print(normalize_contact(raw_text))
# {'email': 'info@example.co.jp', 'phone': '03-1234-5678', 'zip': '150-0001'}
```

---

## よくある間違いと修正

```python
# NG: .は任意の文字にマッチするため "example.com" が "exampleXcom" にもマッチ
re.match(r'example.com', 'exampleXcom')  # マッチしてしまう

# OK: ドットをエスケープ
re.match(r'example\.com', 'exampleXcom')  # マッチしない

# NG: 貪欲マッチで意図しない範囲にマッチ
re.findall(r'<.+>', '<b>太字</b>と<i>斜体</i>')
# → ['<b>太字</b>と<i>斜体</i>']（全部マッチ）

# OK: 非貪欲マッチ（+? または *?）
re.findall(r'<.+?>', '<b>太字</b>と<i>斜体</i>')
# → ['<b>', '</b>', '<i>', '</i>']
```

---

## 正規表現テストツール

複雑なパターンを作るときは以下で確認してから使うと効率的です：
- **regex101.com** — 日本語対応・マッチ箇所の可視化
- **pythex.org** — Python特化

---

## まとめ

正規表現が特に役立つ場面：

| 用途 | 使用頻度 |
|------|---------|
| ログファイルの解析 | ★★★★★ |
| 入力値のバリデーション | ★★★★★ |
| テキストの一括置換 | ★★★★☆ |
| データ抽出・スクレイピング | ★★★★☆ |
| ファイル名の整形 | ★★★☆☆ |

最初は全部覚えようとせず、このページをブックマークして「必要なときに参照する」使い方で十分です。
