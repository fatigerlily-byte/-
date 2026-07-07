---
title: "Google Apps Scriptのスプレッドシート操作 頻出パターン15選【コピペで使える】"
emoji: "📊"
type: "tech"
topics: ["googleappsscript", "gas", "spreadsheet", "自動化", "google"]
published: true
---

# Google Apps Scriptのスプレッドシート操作 頻出パターン15選【コピペで使える】

GASでスプレッドシートを操作するとき、「あれ、どう書くんだっけ」と毎回検索していませんか？実務で使用頻度の高いパターンを15個、コピペできる形でまとめました。ブックマーク推奨です。

---

## 基本の取得系

### ① シートの取得（3パターン）

```javascript
// アクティブなシート
const sheet = SpreadsheetApp.getActiveSheet();

// 名前で取得
const sheet2 = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('売上');

// 別のスプレッドシートをIDで開く
const otherSheet = SpreadsheetApp.openById('スプレッドシートID').getSheetByName('データ');
```

### ② データ範囲を二次元配列で一括取得

```javascript
const sheet = SpreadsheetApp.getActiveSheet();

// 全データ
const allData = sheet.getDataRange().getValues();
// → [['ヘッダー1', 'ヘッダー2'], ['値1', '値2'], ...]

// 特定範囲（A2:C10）
const rangeData = sheet.getRange('A2:C10').getValues();

// 行・列番号で指定（2行目のA列から、10行×3列）
const data = sheet.getRange(2, 1, 10, 3).getValues();
```

:::message
**重要:** セルを1つずつ`getValue()`するのは激遅です。必ず`getValues()`で一括取得してJS側で処理してください。100行の処理で体感100倍違います。
:::

### ③ 最終行・最終列の取得

```javascript
const lastRow = sheet.getLastRow();     // データのある最終行
const lastCol = sheet.getLastColumn();  // データのある最終列

// 特定の列の最終行（A列にだけデータが多い場合など）
const colAValues = sheet.getRange('A:A').getValues();
const lastRowInA = colAValues.filter(String).length;
```

---

## 書き込み系

### ④ 一括書き込み（高速）

```javascript
// NG: 1セルずつ書くと遅い
for (let i = 0; i < 100; i++) {
  sheet.getRange(i + 1, 1).setValue(data[i]); // 激遅
}

// OK: 二次元配列で一括書き込み
const output = data.map(item => [item.name, item.price, item.date]);
sheet.getRange(2, 1, output.length, output[0].length).setValues(output);
```

### ⑤ 最終行の下に追記

```javascript
// 1行だけ追記
sheet.appendRow(['田中', 150000, new Date()]);

// 複数行を最終行の下に一括追記
const newRows = [['A', 1], ['B', 2], ['C', 3]];
sheet.getRange(sheet.getLastRow() + 1, 1, newRows.length, newRows[0].length)
  .setValues(newRows);
```

---

## 検索・フィルタ系

### ⑥ 条件に合う行だけ抽出

```javascript
const data = sheet.getDataRange().getValues();
const headers = data[0];

// 「ステータス列（3列目）が"完了"の行」を抽出
const completed = data.slice(1).filter(row => row[2] === '完了');

// 「売上が100万以上」の行
const bigSales = data.slice(1).filter(row => row[1] >= 1000000);

// 複数条件（AND）
const filtered = data.slice(1).filter(row =>
  row[2] === '完了' && row[1] >= 1000000
);
```

### ⑦ 特定の値がある行番号を探す

```javascript
function findRowByValue(sheet, columnIndex, searchValue) {
  const data = sheet.getDataRange().getValues();
  for (let i = 0; i < data.length; i++) {
    if (data[i][columnIndex - 1] === searchValue) {
      return i + 1; // 行番号（1始まり）
    }
  }
  return -1; // 見つからない
}

const row = findRowByValue(sheet, 1, '田中'); // A列から「田中」を探す
```

### ⑧ 重複行の削除

```javascript
function removeDuplicates() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const data = sheet.getDataRange().getValues();
  const seen = new Set();
  const unique = data.filter(row => {
    const key = row.join('|');
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  sheet.clearContents();
  sheet.getRange(1, 1, unique.length, unique[0].length).setValues(unique);
  console.log(`${data.length - unique.length}件の重複を削除`);
}
```

---

## 集計系

### ⑨ 列の合計・平均・カウント

```javascript
const data = sheet.getDataRange().getValues().slice(1); // ヘッダー除く

// B列（インデックス1）の合計
const total = data.reduce((sum, row) => sum + (Number(row[1]) || 0), 0);

// 平均
const avg = total / data.filter(row => row[1] !== '').length;

// 条件付きカウント（"完了"の数）
const doneCount = data.filter(row => row[2] === '完了').length;
```

### ⑩ グループ別集計（部署別売上合計など）

```javascript
function groupSum() {
  const data = SpreadsheetApp.getActiveSheet().getDataRange().getValues().slice(1);

  // A列=部署, B列=売上 として部署別に集計
  const sums = {};
  data.forEach(row => {
    const dept = row[0];
    sums[dept] = (sums[dept] || 0) + Number(row[1] || 0);
  });

  // 結果を別シートに出力
  const output = Object.entries(sums).map(([dept, sum]) => [dept, sum]);
  const resultSheet = SpreadsheetApp.getActiveSpreadsheet()
    .getSheetByName('集計') || SpreadsheetApp.getActiveSpreadsheet().insertSheet('集計');
  resultSheet.clearContents();
  resultSheet.getRange(1, 1).setValue('部署');
  resultSheet.getRange(1, 2).setValue('売上合計');
  resultSheet.getRange(2, 1, output.length, 2).setValues(output);
}
```

---

## 書式・見た目系

### ⑪ 条件付きで背景色を変える

```javascript
function highlightRows() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const data = sheet.getDataRange().getValues();

  for (let i = 1; i < data.length; i++) {
    const row = i + 1;
    const status = data[i][2]; // C列

    const color = status === '完了' ? '#E8F5E9'   // 緑
                : status === '遅延' ? '#FFEBEE'   // 赤
                : null;

    if (color) {
      sheet.getRange(row, 1, 1, data[0].length).setBackground(color);
    }
  }
}
```

### ⑫ 数値・日付フォーマットの設定

```javascript
// 通貨形式
sheet.getRange('B2:B100').setNumberFormat('¥#,##0');

// パーセント
sheet.getRange('C2:C100').setNumberFormat('0.0%');

// 日付
sheet.getRange('D2:D100').setNumberFormat('yyyy/mm/dd');

// 列幅の自動調整
sheet.autoResizeColumns(1, sheet.getLastColumn());
```

---

## シート管理系

### ⑬ シートの作成・削除・コピー

```javascript
const ss = SpreadsheetApp.getActiveSpreadsheet();

// 存在チェックしてから作成
let sheet = ss.getSheetByName('7月');
if (!sheet) {
  sheet = ss.insertSheet('7月');
}

// テンプレートシートをコピーして月次シートを作る
const template = ss.getSheetByName('テンプレート');
const newSheet = template.copyTo(ss).setName('2026年7月');

// シートの削除
const oldSheet = ss.getSheetByName('2025年1月');
if (oldSheet) ss.deleteSheet(oldSheet);
```

### ⑭ シートの保護（編集ロック）

```javascript
function protectSheet() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const protection = sheet.protect().setDescription('編集禁止');

  // 自分だけ編集可能にする
  protection.removeEditors(protection.getEditors());
  protection.addEditor(Session.getActiveUser().getEmail());

  // 特定範囲だけ編集を許可（入力欄など）
  const unprotected = sheet.getRange('B2:B10');
  protection.setUnprotectedRanges([unprotected]);
}
```

---

## 実務コンボ

### ⑮ 月次シートの自動作成＋前月データの繰越

毎月1日に新しいシートを作り、前月の未完了タスクを繰り越す。

```javascript
function createMonthlySheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const now = new Date();
  const thisMonth = Utilities.formatDate(now, 'JST', 'yyyy年M月');

  const lastMonthDate = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const lastMonth = Utilities.formatDate(lastMonthDate, 'JST', 'yyyy年M月');

  // 既に存在すればスキップ
  if (ss.getSheetByName(thisMonth)) return;

  // テンプレートから作成
  const template = ss.getSheetByName('テンプレート');
  const newSheet = template.copyTo(ss).setName(thisMonth);
  ss.setActiveSheet(newSheet);
  ss.moveActiveSheet(1); // 先頭に移動

  // 前月の未完了タスクを繰越
  const prevSheet = ss.getSheetByName(lastMonth);
  if (prevSheet) {
    const prevData = prevSheet.getDataRange().getValues().slice(1);
    const carryOver = prevData.filter(row => row[2] !== '完了' && row[0]);

    if (carryOver.length > 0) {
      newSheet.getRange(2, 1, carryOver.length, carryOver[0].length)
        .setValues(carryOver);
      console.log(`${carryOver.length}件のタスクを繰越しました`);
    }
  }
}
```

トリガー設定: 時間主導型 → 月ベースのタイマー → 1日 → 午前0〜1時

---

## パフォーマンスの鉄則

| NG | OK | 速度差 |
|----|----|--------|
| ループ内で`getValue()` | `getValues()`で一括取得 | 〜100倍 |
| ループ内で`setValue()` | `setValues()`で一括書込 | 〜100倍 |
| ループ内で`appendRow()` | 配列に貯めて一括書込 | 〜50倍 |
| 毎回`getSheetByName()` | 変数にキャッシュ | 〜10倍 |

GASには**6分の実行時間制限**があります。上の鉄則を守るだけでタイムアウトはほぼ回避できます。

---

## まとめ

この15パターンで実務のスプレッドシート操作の9割はカバーできます。

1. **取得は一括**（`getValues()`）
2. **書き込みも一括**（`setValues()`）
3. **フィルタ・集計はJS側**で処理
4. **定期実行はトリガー**に任せる

「毎月やっている手作業」があれば、このパターンの組み合わせで自動化できないか考えてみてください。
