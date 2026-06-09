---
title: "Google Apps Scriptで業務を自動化する実践レシピ10選【コピペで使える】"
emoji: "📝"
type: "tech"
topics: ["googleappsscript", "gas", "自動化", "google", "business"]
published: true
---

# Google Apps Scriptで業務を自動化する実践レシピ10選【コピペで使える】

Google Apps Script（GAS）は、GoogleスプレッドシートやGmailをJavaScriptで自動化できる無料ツールです。インストール不要・サーバー不要で、ブラウザだけで動きます。この記事では「明日から使える」実践レシピを10個、コピペできるコードとともに紹介します。

---

## GASの基本：スクリプトエディタの開き方

1. Googleスプレッドシートを開く
2. 「拡張機能」→「Apps Script」
3. コードエディタが開く
4. コードを貼り付けて「実行」ボタンを押す

---

## レシピ① スプレッドシートのデータをGmailで定期送信

毎週月曜朝に売上シートをメールで自動送信。

```javascript
function sendWeeklySalesReport() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('売上');
  const data = sheet.getDataRange().getValues();
  
  // 最終行の合計を取得
  const lastRow = data.length - 1;
  const totalSales = data[lastRow][2]; // C列が売上合計と仮定
  
  const subject = `【自動送信】週次売上レポート ${new Date().toLocaleDateString('ja-JP')}`;
  const body = `
先週の売上サマリーをお送りします。

■ 売上合計: ¥${totalSales.toLocaleString()}

詳細はスプレッドシートをご確認ください。
${SpreadsheetApp.getActiveSpreadsheet().getUrl()}
  `.trim();
  
  GmailApp.sendEmail('manager@example.com', subject, body);
  console.log('メール送信完了');
}
```

**トリガー設定（自動実行）:**
1. エディタ左の「トリガー」アイコン→「トリガーを追加」
2. 関数: `sendWeeklySalesReport`
3. イベントのソース: 時間主導型
4. 種類: 週ベースのタイマー → 毎週月曜 午前9時

---

## レシピ② Gmailの特定メールをスプレッドシートに自動記録

「件名に『注文』が含まれるメール」を自動でシートに記録。

```javascript
function recordOrderEmails() {
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
    .getSheetByName('注文記録') || 
    SpreadsheetApp.getActiveSpreadsheet().insertSheet('注文記録');
  
  // ヘッダーがなければ追加
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(['受信日時', '送信者', '件名', '本文（先頭100文字）']);
  }
  
  // 過去1日以内の未読メールを検索
  const threads = GmailApp.search('subject:注文 newer_than:1d is:unread');
  
  threads.forEach(thread => {
    const messages = thread.getMessages();
    messages.forEach(msg => {
      sheet.appendRow([
        msg.getDate(),
        msg.getFrom(),
        msg.getSubject(),
        msg.getPlainBody().substring(0, 100)
      ]);
      msg.markRead();
    });
  });
  
  console.log(`${threads.length}件のメールを記録しました`);
}
```

---

## レシピ③ フォームの回答を自動でSlackに通知

Googleフォームに回答が来たら即Slackに通知。

```javascript
const SLACK_WEBHOOK_URL = 'https://hooks.slack.com/services/xxx/yyy/zzz';

function onFormSubmit(e) {
  const responses = e.values; // [タイムスタンプ, 回答1, 回答2, ...]
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  
  let message = '📋 *新しいフォーム回答が届きました*\n';
  headers.forEach((header, i) => {
    if (responses[i]) {
      message += `*${header}:* ${responses[i]}\n`;
    }
  });
  
  const payload = JSON.stringify({ text: message });
  UrlFetchApp.fetch(SLACK_WEBHOOK_URL, {
    method: 'post',
    contentType: 'application/json',
    payload: payload
  });
}
```

**設定方法:** スプレッドシートのトリガー → `onFormSubmit` → フォーム送信時

---

## レシピ④ スプレッドシートの変更を検知してSlack通知

特定のセルが変更されたらSlackで通知（承認フローに使える）。

```javascript
function onEdit(e) {
  const range = e.range;
  const sheet = range.getSheet();
  
  // 「承認」シートのD列（ステータス列）の変更のみ監視
  if (sheet.getName() !== '承認' || range.getColumn() !== 4) return;
  
  const newValue = range.getValue();
  if (newValue !== '承認' && newValue !== '却下') return;
  
  const row = range.getRow();
  const itemName = sheet.getRange(row, 2).getValue(); // B列: 申請内容
  const applicant = sheet.getRange(row, 3).getValue(); // C列: 申請者
  
  const emoji = newValue === '承認' ? '✅' : '❌';
  const message = `${emoji} *${itemName}* が *${newValue}* されました\n申請者: ${applicant}`;
  
  UrlFetchApp.fetch(SLACK_WEBHOOK_URL, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({ text: message })
  });
}
```

---

## レシピ⑤ PDFを自動生成してメール送信

スプレッドシートの特定シートをPDFに変換して添付メール送信。

```javascript
function sendSheetAsPdf() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName('請求書');
  const ssId = ss.getId();
  const sheetId = sheet.getSheetId();
  
  // PDF変換URL
  const url = `https://docs.google.com/spreadsheets/d/${ssId}/export` +
    `?format=pdf&gid=${sheetId}&size=A4&portrait=true&fitw=true`;
  
  const token = ScriptApp.getOAuthToken();
  const response = UrlFetchApp.fetch(url, {
    headers: { Authorization: `Bearer ${token}` }
  });
  
  const pdfBlob = response.getBlob().setName('請求書.pdf');
  
  const today = new Date().toLocaleDateString('ja-JP');
  GmailApp.sendEmail(
    'client@example.com',
    `【請求書】${today}`,
    '請求書を添付します。',
    { attachments: [pdfBlob] }
  );
  
  console.log('PDF送信完了');
}
```

---

## レシピ⑥ 別スプレッドシートからデータを自動集約

複数のスプレッドシートのデータを1つに集める（部署別→全社集計など）。

```javascript
function aggregateFromMultipleSheets() {
  const SPREADSHEET_IDS = [
    '1ABC...', // 部署Aのシート
    '1DEF...', // 部署BのシートID
    '1GHI...', // 部署CのシートID
  ];
  
  const masterSheet = SpreadsheetApp.getActiveSpreadsheet()
    .getSheetByName('全社集計');
  masterSheet.clearContents();
  masterSheet.appendRow(['部署', '担当者', '売上', '件数']);
  
  SPREADSHEET_IDS.forEach((id, index) => {
    const ss = SpreadsheetApp.openById(id);
    const ws = ss.getActiveSheet();
    const data = ws.getDataRange().getValues();
    
    // ヘッダー行をスキップして追記
    data.slice(1).forEach(row => {
      if (row[0]) masterSheet.appendRow(row);
    });
    
    console.log(`部署${index + 1}: ${data.length - 1}行取込`);
  });
}
```

---

## レシピ⑦ カレンダーイベントをスプレッドシートに書き出し

来週の全予定を一覧シートに自動出力。

```javascript
function exportCalendarToSheet() {
  const calendar = CalendarApp.getDefaultCalendar();
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('予定一覧')
    || SpreadsheetApp.getActiveSpreadsheet().insertSheet('予定一覧');
  
  sheet.clearContents();
  sheet.appendRow(['日付', '曜日', '開始時刻', '終了時刻', '件名', '場所']);
  
  // 来週の予定を取得
  const now = new Date();
  const nextMonday = new Date(now);
  nextMonday.setDate(now.getDate() + (8 - now.getDay()) % 7);
  nextMonday.setHours(0, 0, 0, 0);
  const nextFriday = new Date(nextMonday);
  nextFriday.setDate(nextMonday.getDate() + 4);
  nextFriday.setHours(23, 59, 59);
  
  const events = calendar.getEvents(nextMonday, nextFriday);
  const weekdays = ['日', '月', '火', '水', '木', '金', '土'];
  
  events.forEach(event => {
    const start = event.getStartTime();
    sheet.appendRow([
      start.toLocaleDateString('ja-JP'),
      weekdays[start.getDay()],
      start.toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' }),
      event.getEndTime().toLocaleTimeString('ja-JP', { hour: '2-digit', minute: '2-digit' }),
      event.getTitle(),
      event.getLocation() || ''
    ]);
  });
  
  console.log(`${events.length}件の予定を書き出しました`);
}
```

---

## レシピ⑧ スプレッドシートの入力を自動バリデーション

無効なデータが入力されたら自動で色付け＆コメント追加。

```javascript
function onEdit(e) {
  const range = e.range;
  const sheet = range.getSheet();
  if (sheet.getName() !== 'データ入力') return;
  
  const col = range.getColumn();
  const value = range.getValue();
  
  // C列（金額）のバリデーション
  if (col === 3) {
    if (isNaN(value) || value < 0) {
      range.setBackground('#FFEBEE'); // 赤背景
      range.setNote('⚠️ 金額は0以上の数値を入力してください');
    } else {
      range.setBackground('#E8F5E9'); // 緑背景
      range.clearNote();
    }
  }
  
  // E列（メールアドレス）のバリデーション
  if (col === 5) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (value && !emailRegex.test(value)) {
      range.setBackground('#FFEBEE');
      range.setNote('⚠️ 正しいメールアドレス形式で入力してください');
    } else {
      range.setBackground(null);
      range.clearNote();
    }
  }
}
```

---

## レシピ⑨ Webサイトのデータを定期取得（スクレイピング）

為替レートや株価をスプレッドシートに自動記録。

```javascript
function fetchExchangeRate() {
  // 無料の為替APIを使用
  const response = UrlFetchApp.fetch(
    'https://api.exchangerate-api.com/v4/latest/USD'
  );
  const data = JSON.parse(response.getContentText());
  const jpyRate = data.rates.JPY;
  
  const sheet = SpreadsheetApp.getActiveSpreadsheet()
    .getSheetByName('為替記録');
  
  sheet.appendRow([
    new Date(),
    jpyRate,
    `1USD = ${jpyRate}円`
  ]);
  
  // 閾値を超えたらSlack通知
  if (jpyRate > 155) {
    UrlFetchApp.fetch(SLACK_WEBHOOK_URL, {
      method: 'post',
      contentType: 'application/json',
      payload: JSON.stringify({
        text: `⚠️ ドル円が${jpyRate}円を超えました！`
      })
    });
  }
}
```

---

## レシピ⑩ スプレッドシートを定期的にバックアップ

毎日自動でコピーを作ってGoogle Driveに保存。

```javascript
function backupSpreadsheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const today = new Date().toLocaleDateString('ja-JP').replace(/\//g, '-');
  const backupName = `${ss.getName()}_バックアップ_${today}`;
  
  // バックアップフォルダを取得または作成
  const folderName = 'スプレッドシートバックアップ';
  let folders = DriveApp.getFoldersByName(folderName);
  const folder = folders.hasNext() 
    ? folders.next() 
    : DriveApp.createFolder(folderName);
  
  // コピーを作成して移動
  const copy = DriveApp.getFileById(ss.getId()).makeCopy(backupName);
  folder.addFile(copy);
  DriveApp.getRootFolder().removeFile(copy);
  
  console.log(`バックアップ完了: ${backupName}`);
  
  // 30日以上前のバックアップを削除
  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  
  const files = folder.getFiles();
  while (files.hasNext()) {
    const file = files.next();
    if (file.getDateCreated() < thirtyDaysAgo) {
      file.setTrashed(true);
      console.log(`古いバックアップを削除: ${file.getName()}`);
    }
  }
}
```

---

## まとめ：GASで自動化できる作業の優先順位

| 作業 | 難易度 | 時間削減効果 |
|------|--------|-----------|
| 定期メール送信 | ★☆☆ | 週30分削減 |
| フォーム→Slack通知 | ★☆☆ | 見落とし防止 |
| 複数シート集計 | ★★☆ | 月2〜3時間削減 |
| PDF自動生成・送付 | ★★☆ | 請求業務の完全自動化 |
| メール自動記録 | ★☆☆ | 情報整理の自動化 |

GASの最大のメリットは**Googleアカウントさえあれば今すぐ無料で使える**点です。まず「毎週手動でやっていること」を1つ選んで自動化してみてください。
