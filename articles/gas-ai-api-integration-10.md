---
title: "Google Apps ScriptとChatGPT/Claude APIを連携する実践レシピ10選【コピペで使える】"
emoji: "🔗"
type: "tech"
topics: ["googleappsscript", "gas", "claude", "chatgpt", "自動化"]
published: true
---

# Google Apps ScriptとChatGPT/Claude APIを連携する実践レシピ10選【コピペで使える】

GAS（Google Apps Script）とAI APIを組み合わせると、スプレッドシートやGmailが一気に「AI搭載ツール」になります。サーバー不要・ブラウザだけで動く実践レシピを10個紹介します。

---

## 事前準備：APIキーの設定

APIキーはコードに直書きせず、スクリプトプロパティに保存します。

1. Apps Scriptエディタ → 左メニュー「プロジェクトの設定」⚙️
2. 「スクリプト プロパティ」→「プロパティを追加」
3. `ANTHROPIC_API_KEY`（または `OPENAI_API_KEY`）を登録

```javascript
// 共通：Claude APIを呼び出す関数
function callClaude(prompt, maxTokens = 1024) {
  const apiKey = PropertiesService.getScriptProperties()
    .getProperty('ANTHROPIC_API_KEY');

  const response = UrlFetchApp.fetch('https://api.anthropic.com/v1/messages', {
    method: 'post',
    headers: {
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json'
    },
    payload: JSON.stringify({
      model: 'claude-haiku-4-5-20251001',  // 定型処理はHaikuで十分＆安い
      max_tokens: maxTokens,
      messages: [{ role: 'user', content: prompt }]
    })
  });

  const data = JSON.parse(response.getContentText());
  return data.content[0].text;
}
```

---

## レシピ① セルの内容をAIで一括要約

スプレッドシートのA列の長文をB列に要約。

```javascript
function summarizeColumn() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const lastRow = sheet.getLastRow();

  for (let row = 2; row <= lastRow; row++) {
    const original = sheet.getRange(row, 1).getValue();
    if (!original || sheet.getRange(row, 2).getValue()) continue; // 空 or 処理済みはスキップ

    const summary = callClaude(
      `以下の文章を50字以内で要約してください。要約のみ出力：\n\n${original}`
    );
    sheet.getRange(row, 2).setValue(summary);
    Utilities.sleep(500); // レート制限対策
  }
}
```

---

## レシピ② カスタム関数として使う（=AI()関数）

スプレッドシートのセルに `=AI("プロンプト")` と書くだけでAIが答える。

```javascript
/**
 * セルでAIを呼び出すカスタム関数
 * 使い方: =AI("東京の人口は？")
 * @customfunction
 */
function AI(prompt) {
  if (!prompt) return '';
  return callClaude(String(prompt), 500);
}

/**
 * セルの内容を翻訳
 * 使い方: =AI_TRANSLATE(A1, "英語")
 * @customfunction
 */
function AI_TRANSLATE(text, targetLang) {
  return callClaude(
    `以下を${targetLang}に翻訳してください。翻訳文のみ出力：\n${text}`, 500);
}

/**
 * 感情分析
 * 使い方: =AI_SENTIMENT(A1)
 * @customfunction
 */
function AI_SENTIMENT(text) {
  return callClaude(
    `以下の文章の感情を「ポジティブ」「ネガティブ」「中立」のどれか1語で答えてください：\n${text}`, 10);
}
```

:::message
カスタム関数は再計算のたびにAPIが呼ばれてコストがかかります。結果が確定したら「値のみ貼り付け」で固定するのがおすすめです。
:::

---

## レシピ③ 問い合わせメールをAIが自動分類してラベル付け

Gmailの未読メールを「緊急/通常/営業/スパム」に自動分類。

```javascript
function classifyEmails() {
  const threads = GmailApp.search('is:unread in:inbox', 0, 20);

  const labels = {
    '緊急': GmailApp.getUserLabelByName('緊急') || GmailApp.createLabel('緊急'),
    '営業': GmailApp.getUserLabelByName('営業') || GmailApp.createLabel('営業'),
    '通常': GmailApp.getUserLabelByName('通常') || GmailApp.createLabel('通常'),
  };

  threads.forEach(thread => {
    const msg = thread.getMessages()[0];
    const category = callClaude(
      `以下のメールを「緊急」「営業」「通常」のどれか1語で分類してください。
判断基準：
- 緊急: 障害・クレーム・即対応が必要
- 営業: 売り込み・広告
- 通常: それ以外

件名: ${msg.getSubject()}
本文: ${msg.getPlainBody().substring(0, 500)}`, 10
    ).trim();

    if (labels[category]) {
      thread.addLabel(labels[category]);
      console.log(`分類: ${msg.getSubject()} → ${category}`);
    }
  });
}
```

トリガーで10分おきに実行すれば、受信箱が自動で整理され続けます。

---

## レシピ④ 議事録メモから議事録を自動生成してDocsに保存

```javascript
function generateMinutes() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const rawMemo = sheet.getRange('A1').getValue(); // 雑なメモ

  const minutes = callClaude(`
以下の雑多な会議メモから、正式な議事録を作成してください。

メモ:
${rawMemo}

形式:
# 議事録
## 日時・参加者（メモから推定、不明なら「要確認」）
## 決定事項（箇条書き）
## アクションアイテム（表形式: タスク/担当/期限）
## 次回までの宿題
`, 2000);

  // Googleドキュメントとして保存
  const doc = DocumentApp.create(
    `議事録_${new Date().toLocaleDateString('ja-JP')}`
  );
  doc.getBody().setText(minutes);

  console.log(`議事録を作成しました: ${doc.getUrl()}`);
  return doc.getUrl();
}
```

---

## レシピ⑤ フォーム回答へのAI自動返信

Googleフォームの問い合わせにAIが一次回答をメール送信。

```javascript
function onFormSubmit(e) {
  const responses = e.values;
  const email = responses[1];    // 2列目がメールアドレスと仮定
  const question = responses[2]; // 3列目が問い合わせ内容と仮定

  const answer = callClaude(`
あなたはカスタマーサポートです。以下の問い合わせに丁寧に回答してください。
わからないことは「担当者から改めてご連絡します」と答えてください。

よくある質問と回答:
- 営業時間: 平日9-18時
- 返品: 購入後14日以内、未開封のみ
- 送料: 5,000円以上で無料

問い合わせ: ${question}
`, 1000);

  GmailApp.sendEmail(
    email,
    '【自動返信】お問い合わせを受け付けました',
    `${answer}\n\n---\nこの回答はAIによる一次回答です。\n担当者からも改めてご連絡いたします。`
  );
}
```

---

## レシピ⑥ スプレッドシートのデータをAIが分析してレポート化

```javascript
function analyzeDataWithAI() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const data = sheet.getDataRange().getValues();

  // データをCSV文字列に変換
  const csv = data.map(row => row.join(',')).join('\n');

  const report = callClaude(`
以下の売上データを分析して、経営者向けレポートを作成してください。

${csv}

含める内容:
1. 全体サマリー（3行）
2. 注目すべき傾向・異常値
3. 具体的なアクション提案を2つ
`, 1500);

  // レポートシートに出力
  const reportSheet = SpreadsheetApp.getActiveSpreadsheet()
    .getSheetByName('AIレポート') ||
    SpreadsheetApp.getActiveSpreadsheet().insertSheet('AIレポート');

  reportSheet.getRange('A1').setValue(
    `生成日時: ${new Date().toLocaleString('ja-JP')}\n\n${report}`
  );
}
```

---

## レシピ⑦ 毎朝のニュース要約をメールで受け取る

RSSフィードをAIが要約して毎朝メール。

```javascript
function morningNewsDigest() {
  // RSSフィードを取得（例: はてなブックマーク テクノロジー）
  const rss = UrlFetchApp.fetch('https://b.hatena.ne.jp/hotentry/it.rss')
    .getContentText();
  const doc = XmlService.parse(rss);
  const items = doc.getRootElement()
    .getChildren('item', XmlService.getNamespace('http://purl.org/rss/1.0/'));

  const titles = items.slice(0, 10).map((item, i) => {
    const ns = XmlService.getNamespace('http://purl.org/rss/1.0/');
    return `${i+1}. ${item.getChildText('title', ns)}`;
  }).join('\n');

  const digest = callClaude(`
以下は今朝の技術系ニュースのタイトル一覧です。
エンジニア向けに「今日押さえるべきトピック」を3つ選んで、
それぞれ1行で「なぜ重要か」を添えてください。

${titles}
`, 800);

  GmailApp.sendEmail(
    Session.getActiveUser().getEmail(),
    `☀️ 朝のテックニュース ${new Date().toLocaleDateString('ja-JP')}`,
    digest + '\n\n---\n元記事一覧:\n' + titles
  );
}
```

トリガー設定: 時間主導型 → 日付ベース → 午前7〜8時

---

## レシピ⑧ 長文ドキュメントのQ&Aボット

Googleドキュメントの内容についてAIに質問できる仕組み。

```javascript
function askAboutDocument(question) {
  const DOC_ID = 'あなたのドキュメントID';
  const doc = DocumentApp.openById(DOC_ID);
  const content = doc.getBody().getText();

  return callClaude(`
以下のドキュメントの内容に基づいて質問に答えてください。
ドキュメントに書かれていないことは「記載がありません」と答えてください。

<document>
${content.substring(0, 50000)}
</document>

質問: ${question}
`, 1000);
}

// 使用例：スプレッドシートと組み合わせ
function answerQuestionsInSheet() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const lastRow = sheet.getLastRow();

  for (let row = 2; row <= lastRow; row++) {
    const q = sheet.getRange(row, 1).getValue();
    if (!q || sheet.getRange(row, 2).getValue()) continue;

    sheet.getRange(row, 2).setValue(askAboutDocument(q));
    Utilities.sleep(1000);
  }
}
```

---

## レシピ⑨ 商品レビューの一括感情分析＋集計

```javascript
function analyzeReviews() {
  const sheet = SpreadsheetApp.getActiveSheet();
  const lastRow = sheet.getLastRow();
  let positive = 0, negative = 0, neutral = 0;

  for (let row = 2; row <= lastRow; row++) {
    const review = sheet.getRange(row, 1).getValue();
    if (!review) continue;

    let sentiment = sheet.getRange(row, 2).getValue();
    if (!sentiment) {
      sentiment = callClaude(
        `以下のレビューを「ポジティブ」「ネガティブ」「中立」で分類。1語のみ出力：\n${review}`,
        10
      ).trim();
      sheet.getRange(row, 2).setValue(sentiment);
      Utilities.sleep(500);
    }

    if (sentiment.includes('ポジティブ')) positive++;
    else if (sentiment.includes('ネガティブ')) negative++;
    else neutral++;
  }

  // 集計結果
  const total = positive + negative + neutral;
  sheet.getRange('D1').setValue('集計結果');
  sheet.getRange('D2').setValue(`ポジティブ: ${positive} (${(positive/total*100).toFixed(0)}%)`);
  sheet.getRange('D3').setValue(`ネガティブ: ${negative} (${(negative/total*100).toFixed(0)}%)`);
  sheet.getRange('D4').setValue(`中立: ${neutral} (${(neutral/total*100).toFixed(0)}%)`);
}
```

---

## レシピ⑩ SlackへのAI日報要約通知

チームの日報スプレッドシートをAIが要約してSlackに投稿。

```javascript
function dailySummaryToSlack() {
  const SLACK_WEBHOOK = PropertiesService.getScriptProperties()
    .getProperty('SLACK_WEBHOOK');

  const sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName('日報');
  const today = new Date().toLocaleDateString('ja-JP');
  const data = sheet.getDataRange().getValues();

  // 今日の日報だけ抽出
  const todayReports = data.filter(row =>
    row[0] && new Date(row[0]).toLocaleDateString('ja-JP') === today
  );

  if (todayReports.length === 0) return;

  const reportsText = todayReports
    .map(row => `${row[1]}: ${row[2]}`)  // B列=名前, C列=内容
    .join('\n');

  const summary = callClaude(`
以下はチームメンバーの今日の日報です。
マネージャー向けに「チーム全体の状況」を5行以内でまとめてください。
問題・ブロッカーがあれば必ず先頭に書いてください。

${reportsText}
`, 500);

  UrlFetchApp.fetch(SLACK_WEBHOOK, {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify({
      text: `📋 *本日のチーム日報サマリー*（${todayReports.length}名分）\n\n${summary}`
    })
  });
}
```

---

## コストの目安

Haiku（claude-haiku-4-5）を使った場合の概算：

| 用途 | 1回あたり | 月間コスト目安 |
|------|----------|--------------|
| メール分類（500字） | 約0.1円 | 月1000通で約100円 |
| セル要約（1000字） | 約0.2円 | 月500回で約100円 |
| レポート生成（5000字） | 約1円 | 月30回で約30円 |

軽い自動化なら**月数百円以内**で運用できます。

---

## まとめ

| レシピ | 効果 |
|--------|------|
| メール自動分類 | 受信箱の整理が不要に |
| =AI()カスタム関数 | スプレッドシートがAI搭載に |
| 議事録自動生成 | 30分の作業が1分に |
| フォームAI自動返信 | 一次対応の完全自動化 |
| ニュース要約メール | 情報収集の時短 |

GASは無料、AI APIも軽い用途なら月数百円。「AIを業務に組み込む」最も手軽な方法です。まずレシピ①から試してみてください。
