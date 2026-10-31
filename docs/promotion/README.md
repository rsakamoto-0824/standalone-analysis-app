# Process Insight Tool 紹介素材

2026-10-31作成。配布時の説明資料や紹介ページに使用するPNG画像です。

| 素材 | 用途 | サイズ |
|---|---|---|
| [インフォグラフ](process-insight-tool-infographic.png) | モデリング、Swing Curve、炉内補間、SHAP解析、実験計画、評価・出力の全体像 | 1672 × 941 px |
| [グラレコ風サムネイル](process-insight-tool-sketchnote-thumbnail.png) | 紹介資料の表紙、動画・リンクのサムネイル | 1672 × 941 px |

どちらも横長の約16:9です。PNGをそのままPowerPoint等へ挿入できます。タイトルや文字を切り落とさず、縦横比を保って配置してください。

図は機能を説明する概念図です。実画面、実測データ、モデルの精度を示す画像ではありません。機能の記述は[README](../../README.md)、[更新仕様](../ui-update.md)、[利用手順書](../user-guide/procedure-guide.html)に合わせています。Windows R2025bでのビルド・Runtime確認の状況は、[検証記録](../../verification.md)を参照してください。

制作にはimagegenスキルの組み込み画像生成ツールを使用しました。再制作・編集に使える[生成プロンプトと修正指示](image-prompts.md)を同梱しています。

## 名称と互換性

アプリの画面タイトルは `Process Insight Tool`、Windowsビルド時の実行ファイル名は `ProcessInsightTool.exe` です。既存の設定とログを引き継ぐため、`prefdir/StandaloneAnalysisApp/` の保存先、リポジトリのフォルダ名、`AnalysisApp.mlapp`、MATモデルの変数名は維持しています。既存の参考スクリーンショット・動画には撮影時の旧称が含まれます。
