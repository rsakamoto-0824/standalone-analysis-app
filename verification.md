# 検証記録

作成日: 2026-10-27（JST）。ユーザー承認済みの範囲は、R2025b 向けソース・テスト・Windows ビルド手順の作成まで。R2025b 実行検証と exe 作成は後工程。

## 現在の状況

- MATLAB R2025b: この端末で確認できず。R2025b での全単体テストは未実施。
- App Designer `.mlapp`: R2025b で作成する入口は未生成。画面を構築する MATLAB クラスは作成済み。
- Windows exe: 未生成。Runtime のみの端末での起動・動作は未確認。
- 現行アドイン・現行モデル: 未実行。互換比較スクリプトを用意済み。
- R2022b: 静的解析・モデルを生成しない補助テストのみを実施対象とする。対象リリースの実行検証に数えない。

## この端末での確認結果

2026-10-27、MATLAB R2022b の `-batch` で以下を確認しました。学習関数の正常系、保存済みの RegressionGP の読込、SHAP、DOE、画面の起動は実行していません。

| 確認 | 成功 | 失敗 | 未完了 |
|---|---:|---:|---:|
| `TestPureFunctions` の補助テスト | 20 | 0 | 0 |
| 原仕様から抽出した正本と学習・保存本体の照合 | 5 | 0 | 0 |
| R2025b 固有・モデル互換テスト（9件） | 未実施 | 未実施 | 未実施 |

初回の補助テストでは KL の既知値テスト1件が失敗しました。擬似カウント加算後の分布は `[3/4, 1/4]` であるため、テストの手計算期待値を訂正し、再実行で20件成功を確認しています。KL の計算本体は原仕様どおり維持しています。

静的解析に構文エラーはなく、改善提案が5件あります。

- `create_wordCloud.m`: `char(10)` を `newline` に置き換える提案1件。原仕様の区切り文字表記を維持しています。
- `load_train_model.m` / `verify_saved_model.m`: `class` 比較を `isa` に変える提案3件。仕様のクラス名完全一致を確認するため維持しています。
- `verify_saved_model.m`: 検証表をループ内で1行追加する提案1件。検証は最大9行であり、可読性のため維持しています。

計算関数内にファイル選択ダイアログ・`figure` がないこと、ソースにネットワーク送信処理がないこと、成果物フォルダに測定ファイル・学習済み MAT・exe が混入していないことも確認しています。ソースはローカルに新規作成し、GitHub への書込みは行っていません。

## テスト対応

| 原仕様 | テスト |
|---|---|
| T-01 / T-02 / T-05 | `TestModelCompatibility.allModelTypes_savedVariableAndPredictionsMatch` |
| T-03 | `TestPureFunctions.reorderedColumns_mappingRestoresCanonicalOrder` と `TestModelCompatibility.shuffledFileColumns_canonicalModelsPredictExactlyEqual` |
| T-04 | `missingOrRepeatedColumn_mappingStops`, `repeatedCsvHeaders_importStops` |
| T-06 | `apcBoundaryRows_warningsOnlyFrom25Through149`, `swingBelow25Rows_noApcRowLimit` |
| T-07 | `knownBounds_extrapolationFlagsOnlyOutsideRows`, `radiusOutsideEvenWithXYInside_extrapolationIsDetected` |
| T-08 | `knownVectors_metricsMatchHandCalculation`, `knownVectorWithNaN_summaryMatchesHandCalculation`, KL / MI 既知値テスト |
| T-09 | `explicitSeed_doeRepeatsExactly` |
| T-10 | `invalidParameters_errorListsValidValues` |

## 4章との関係

正本の4つの `fitrgp` 呼出しと保存関数の本体は維持しています。`ResponseName` 指定、追加の名前・値引数、`compact`、保存形式オプション、単位変換、事前標準化は追加していません。保存後検証は画面の設定・実際の行数とも比較できるよう、任意の第4引数 `expected` を追加しています。MAT 内の構造に影響する追加情報は保存しません。

ソースの一致とモデル実体の互換性は別の確認です。モデル実体については R2025b の全テストと旧・新モデル比較が残っています。

## 暫定方針

Q-01 読込時はモデルに応じてアプリ内入力だけを整形。Q-02 ResponseName 未指定・保存前後比較・ログ記録。Q-03 R2025b 固定。Q-04 モデル別付帯情報なし、集約ログのみ。Q-05 学習 seed 固定なし。Q-06 保存キャンセルで推定終了。Q-07 汎用 GPR 維持。Q-08 ノイズ除去 SHAP のサンプル数未指定。Q-09 欠損行で停止。Q-10 実際の処理時間をログ。Q-11 半径150 mm以上を除外しない。

該当実装に `% TODO(要確認 Q-xx)` を残しています。

## 2026-10-28：HTML手順書の追加

`docs/user-guide/procedure-guide.html` に、ビルド・配布・10機能の利用手順を15章で追加しました。アプリの表示専用コピーの参考画像14枚と、出典付きのMathWorks公式資料の画像2枚を含みます。作成した資料と画像の確認結果は `docs/user-guide/guide-verification.md` に記録しています。

製品の画面・計算ソースはこの手順書作成では変更していません。R2025bでの実行確認とWindows exe生成は引き続き未実施です。参考画像の生成時にR2022bでワードクラウドのtitle引数制限を確認したため、R2025bでの確認事項を `issues.md` に追加しました。
