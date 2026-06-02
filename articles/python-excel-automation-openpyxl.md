---
title: "PythonでExcel作業を自動化する実践ガイド【openpyxl完全版】"
emoji: "📊"
type: "tech"
topics: ["python", "excel", "openpyxl", "自動化", "business"]
published: true
---

# PythonでExcel作業を自動化する実践ガイド【openpyxl完全版】

「毎月同じフォーマットのExcelを手作業で更新している」「複数ファイルを集計するのに1時間かかる」。Pythonのopenpyxlを使えばこれらをスクリプト1本で終わらせられます。コピペで使える実装例を中心に解説します。

## セットアップ

```bash
pip install openpyxl
```

---

## 基本操作

### ファイルの読み書き

```python
from openpyxl import load_workbook, Workbook

# 既存ファイルを開く
wb = load_workbook("data.xlsx")
ws = wb.active  # アクティブシートを取得

# セル値の読み取り
value = ws["A1"].value
value = ws.cell(row=1, column=1).value  # 同じ意味

# セル値の書き込み
ws["B2"] = "テスト"
ws.cell(row=2, column=2, value=100)

# 保存
wb.save("output.xlsx")
wb.close()
```

### シートの操作

```python
# シート一覧
print(wb.sheetnames)  # ['Sheet1', '売上', '在庫']

# シートを名前で取得
ws = wb["売上"]

# 新しいシートを作成
ws_new = wb.create_sheet("集計", index=0)  # index=0で先頭に挿入

# シートのコピー
ws_copy = wb.copy_worksheet(ws)
ws_copy.title = "売上_バックアップ"
```

---

## 実践レシピ

### レシピ① 複数Excelファイルの集計

フォルダ内の月次売上ファイルを全部読み込んで1枚に集約。

```python
from pathlib import Path
from openpyxl import load_workbook, Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from datetime import datetime

def aggregate_monthly_sales(folder_path: str, output_path: str):
    """複数の月次売上Excelを1つに集約する"""
    
    wb_out = Workbook()
    ws_out = wb_out.active
    ws_out.title = "集計"
    
    # ヘッダー行
    headers = ["ファイル名", "月", "商品名", "数量", "単価", "売上金額"]
    for col, header in enumerate(headers, 1):
        cell = ws_out.cell(row=1, column=col, value=header)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = PatternFill(fill_type="solid", fgColor="2F5496")
        cell.alignment = Alignment(horizontal="center")
    
    row_num = 2
    total_sales = 0
    
    # フォルダ内のExcelファイルを全て処理
    for filepath in sorted(Path(folder_path).glob("*.xlsx")):
        wb = load_workbook(filepath, data_only=True)  # data_only=Trueで数式の値を取得
        ws = wb.active
        
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not any(row):  # 空行はスキップ
                continue
            
            month, product, qty, price = row[0], row[1], row[2], row[3]
            amount = (qty or 0) * (price or 0)
            total_sales += amount
            
            ws_out.cell(row=row_num, column=1, value=filepath.name)
            ws_out.cell(row=row_num, column=2, value=month)
            ws_out.cell(row=row_num, column=3, value=product)
            ws_out.cell(row=row_num, column=4, value=qty)
            ws_out.cell(row=row_num, column=5, value=price)
            ws_out.cell(row=row_num, column=6, value=amount)
            row_num += 1
        
        wb.close()
    
    # 合計行
    ws_out.cell(row=row_num, column=5, value="合計").font = Font(bold=True)
    ws_out.cell(row=row_num, column=6, value=total_sales).font = Font(bold=True)
    
    # 列幅を自動調整
    for col in ws_out.columns:
        max_len = max(len(str(cell.value or "")) for cell in col)
        ws_out.column_dimensions[col[0].column_letter].width = min(max_len + 4, 40)
    
    wb_out.save(output_path)
    print(f"集計完了: {row_num - 2}行 / 合計 ¥{total_sales:,}")

aggregate_monthly_sales("./monthly_sales/", "集計_2026.xlsx")
```

---

### レシピ② テンプレートに差し込みして複数ファイルを生成

請求書テンプレートに顧客データを差し込んで一括生成。

```python
import copy
from openpyxl import load_workbook

CUSTOMERS = [
    {"name": "株式会社A", "address": "東京都渋谷区", "amount": 150000, "due": "2026-06-30"},
    {"name": "有限会社B", "address": "大阪府梅田", "amount": 85000, "due": "2026-06-30"},
    {"name": "合同会社C", "address": "愛知県名古屋", "amount": 220000, "due": "2026-06-30"},
]

def generate_invoices(template_path: str, output_dir: str):
    for customer in CUSTOMERS:
        # テンプレートを毎回新しく開く（上書きしないため）
        wb = load_workbook(template_path)
        ws = wb.active
        
        # セルに値を差し込む（テンプレート上の座標に合わせて調整）
        ws["B3"] = customer["name"]
        ws["B4"] = customer["address"]
        ws["E10"] = customer["amount"]
        ws["E11"] = customer["amount"] * 0.1  # 消費税
        ws["E12"] = customer["amount"] * 1.1  # 税込合計
        ws["B15"] = customer["due"]
        
        # ファイル名を顧客名で保存
        safe_name = customer["name"].replace("株式会社", "").replace("有限会社", "").strip()
        output_path = f"{output_dir}/請求書_{safe_name}.xlsx"
        wb.save(output_path)
        wb.close()
        print(f"生成: {output_path}")

from pathlib import Path
Path("./invoices").mkdir(exist_ok=True)
generate_invoices("invoice_template.xlsx", "./invoices")
```

---

### レシピ③ セルの書式設定を自動化

数値フォーマット・条件付き書式をPythonで設定。

```python
from openpyxl import Workbook
from openpyxl.styles import (
    Font, PatternFill, Alignment, Border, Side, numbers
)
from openpyxl.formatting.rule import ColorScaleRule, DataBarRule

def create_styled_report(data: list[dict], output_path: str):
    wb = Workbook()
    ws = wb.active
    ws.title = "売上レポート"
    
    # ヘッダー
    headers = ["担当者", "売上", "目標", "達成率"]
    header_fill = PatternFill(fill_type="solid", fgColor="1F3864")
    
    for col, h in enumerate(headers, 1):
        cell = ws.cell(row=1, column=col, value=h)
        cell.font = Font(bold=True, color="FFFFFF", size=11)
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center")
    
    ws.row_dimensions[1].height = 25
    
    # データ行
    thin = Side(style="thin", color="CCCCCC")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    
    for row_idx, record in enumerate(data, 2):
        achievement = record["sales"] / record["target"]
        
        ws.cell(row=row_idx, column=1, value=record["name"])
        
        # 売上: 通貨フォーマット
        sales_cell = ws.cell(row=row_idx, column=2, value=record["sales"])
        sales_cell.number_format = '¥#,##0'
        
        # 目標: 通貨フォーマット
        target_cell = ws.cell(row=row_idx, column=3, value=record["target"])
        target_cell.number_format = '¥#,##0'
        
        # 達成率: パーセントフォーマット
        rate_cell = ws.cell(row=row_idx, column=4, value=achievement)
        rate_cell.number_format = '0.0%'
        
        # 達成率で行の色を変える
        if achievement >= 1.0:
            row_fill = PatternFill(fill_type="solid", fgColor="E8F5E9")  # 緑
        elif achievement >= 0.8:
            row_fill = PatternFill(fill_type="solid", fgColor="FFF9C4")  # 黄
        else:
            row_fill = PatternFill(fill_type="solid", fgColor="FFEBEE")  # 赤
        
        for col in range(1, 5):
            cell = ws.cell(row=row_idx, column=col)
            cell.fill = row_fill
            cell.border = border
            cell.alignment = Alignment(horizontal="center")
    
    # 列幅設定
    ws.column_dimensions["A"].width = 15
    ws.column_dimensions["B"].width = 15
    ws.column_dimensions["C"].width = 15
    ws.column_dimensions["D"].width = 12
    
    wb.save(output_path)
    print(f"レポート生成: {output_path}")

# 使用例
data = [
    {"name": "田中", "sales": 1250000, "target": 1000000},
    {"name": "佐藤", "sales": 780000,  "target": 1000000},
    {"name": "鈴木", "sales": 1050000, "target": 1000000},
    {"name": "高橋", "sales": 920000,  "target": 1000000},
]
create_styled_report(data, "売上レポート.xlsx")
```

---

### レシピ④ グラフを自動生成

売上データからグラフを自動でExcelに埋め込む。

```python
from openpyxl import Workbook
from openpyxl.chart import BarChart, LineChart, Reference
from openpyxl.chart.series import DataPoint

def create_chart_report(monthly_data: list[tuple], output_path: str):
    """月次売上データからグラフ付きExcelを生成"""
    wb = Workbook()
    ws = wb.active
    
    # データを入力
    ws.append(["月", "売上", "前月比"])
    for month, sales, prev_ratio in monthly_data:
        ws.append([month, sales, prev_ratio])
    
    # 棒グラフ（売上）
    bar_chart = BarChart()
    bar_chart.type = "col"
    bar_chart.title = "月次売上"
    bar_chart.y_axis.title = "売上（円）"
    bar_chart.x_axis.title = "月"
    bar_chart.style = 10
    bar_chart.width = 20
    bar_chart.height = 12
    
    data_ref = Reference(ws, min_col=2, min_row=1, max_row=len(monthly_data)+1)
    cats_ref = Reference(ws, min_col=1, min_row=2, max_row=len(monthly_data)+1)
    bar_chart.add_data(data_ref, titles_from_data=True)
    bar_chart.set_categories(cats_ref)
    
    ws.add_chart(bar_chart, "E2")
    
    # 折れ線グラフ（前月比）
    line_chart = LineChart()
    line_chart.title = "前月比推移"
    line_chart.y_axis.title = "前月比"
    line_chart.style = 10
    line_chart.width = 20
    line_chart.height = 12
    
    ratio_ref = Reference(ws, min_col=3, min_row=1, max_row=len(monthly_data)+1)
    line_chart.add_data(ratio_ref, titles_from_data=True)
    line_chart.set_categories(cats_ref)
    
    ws.add_chart(line_chart, "E20")
    
    wb.save(output_path)
    print(f"グラフ付きレポート生成: {output_path}")

monthly_data = [
    ("1月", 1250000, 1.00),
    ("2月", 980000,  0.78),
    ("3月", 1580000, 1.61),
    ("4月", 1420000, 0.90),
    ("5月", 2100000, 1.48),
    ("6月", 1890000, 0.90),
]
create_chart_report(monthly_data, "売上グラフ.xlsx")
```

---

### レシピ⑤ GitHub Actionsで毎月自動生成・メール送信

月初に自動でレポートを生成してメール送付。

```yaml
# .github/workflows/monthly-report.yml
name: Monthly Excel Report
on:
  schedule:
    - cron: '0 0 1 * *'  # 毎月1日 朝9時JST
jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - run: pip install openpyxl
      - name: Generate report
        run: python scripts/monthly_report.py
      - name: Send email
        uses: dawidd6/action-send-mail@v3
        with:
          server_address: smtp.gmail.com
          server_port: 465
          username: ${{ secrets.GMAIL_ADDRESS }}
          password: ${{ secrets.GMAIL_APP_PASSWORD }}
          subject: "【自動送信】月次レポート"
          to: recipient@example.com
          from: ${{ secrets.GMAIL_ADDRESS }}
          body: "月次レポートを添付します。"
          attachments: "output/monthly_report.xlsx"
```

---

## よくある落とし穴

### ① 数式の値が取れない

```python
# NG: 数式のテキストが返る
wb = load_workbook("data.xlsx")
ws = wb.active
print(ws["C1"].value)  # "=A1+B1" と表示される

# OK: data_only=True で計算済みの値を取得
wb = load_workbook("data.xlsx", data_only=True)
ws = wb.active
print(ws["C1"].value)  # 計算結果の数値が返る
```

### ② 大きなファイルでメモリ不足

```python
# read_only=True でメモリ使用量を削減（読み取り専用）
wb = load_workbook("large_file.xlsx", read_only=True)
ws = wb.active

for row in ws.iter_rows(values_only=True):
    process(row)

wb.close()  # read_onlyモードはclose()が重要
```

### ③ 日付がシリアル値で返ってくる

```python
from datetime import datetime

cell_value = ws["A1"].value

# openpyxlは日付を自動でdatetimeに変換するが、
# 古いファイルや特定の形式ではfloatで返ることがある
if isinstance(cell_value, float):
    from openpyxl.utils.datetime import from_excel
    cell_value = from_excel(cell_value)

print(cell_value.strftime("%Y/%m/%d"))
```

---

## まとめ

openpyxlで自動化できる作業の優先順位：

| 作業 | 自動化の効果 |
|------|------------|
| 複数ファイルの集計 | ★★★★★ 時間削減が大きい |
| テンプレートへの差し込み | ★★★★★ ヒューマンエラー防止 |
| 書式設定・グラフ作成 | ★★★★☆ 品質の均一化 |
| 定期レポートの自動生成 | ★★★★★ 完全自動化できる |

「毎月同じExcel作業をしているな」と思ったら、まずその作業を小さな関数に切り出すことから始めてみてください。
