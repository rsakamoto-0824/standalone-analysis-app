# アプリ解説動画

`app-overview-ja.mp4`を開いて再生します。日本語ナレーションと画面内の字幕付きです。MATLABや開発用のAIツールは、動画の再生には必要ありません。

`index.html`は章を選んで再生できる閲覧ページです。MP4、ポスター、閲覧ページを同じフォルダに置いてください。リポジトリ内の画像付き手順書にもリンクしています。

GitHubからはMP4ファイルを開いてダウンロードし、PCで再生できます。閲覧ページを使う場合は、動画を含むブランチの「Code → Download ZIP」で一式を取得・展開し、`docs/video/app-overview/index.html`を開きます。GitHub上でHTMLファイルを開いた場合はソースが表示されます。

## 内容と確認範囲

基本操作、入力列、GPRカーネル比較、8評価指標、保存モデル、SHAP、Swing Curve近似・残差・周期カーネル、バッチ別の炉内補間と6方式、実験計画・交絡、ワードクラウド、結果保存、設定とHelpを紹介します。

画面は`docs/user-guide/images/`にあるR2022bの表示専用コピーと合成データの参考画像です。画面の拡大と説明を編集した動画であり、実操作の録画ではありません。画像にあるGPR評価・SHAP・周期探索の値は説明用の表示例です。炉内のスプライン・RBF・3次多項式は合成データによる補助計算です。

MATLAB R2025b、Windows exe、Runtimeでの実GPR・モデル保存・互換性の最終検証は未実施です。動画でもこの範囲を表示しています。今回の動画作成でアプリ本体のソースは変更していません。

- 映像：1920×1080、30fps、H.264、MP4
- 音声：日本語合成音声（macOS Kyoko）、AAC
- 字幕：映像に表示。編集用に`subtitles-ja.srt`と`subtitles-ja.vtt`も同梱
- 解説文：`transcript.md`
- 章の時刻・出典・対象コミット：`video-info.json`
- サムネイル：`poster.png`

## 再生成

音声生成にはmacOSの`say`とKyoko音声を使います。Node.js、FFmpeg、FFprobe、ChromeまたはPlaywrightのChromiumが必要です。動画の再生環境と再生成環境は別です。

1. `_src/storyboard.json`で章・表示文字・読み上げ文を編集します。
2. `_src`で`npm install`を実行します。
3. リポジトリのルートで`node docs/video/app-overview/_src/render.mjs preview`を実行します。
4. `output/video/app-overview/storyboard-sheet.png`と各章の画像を確認します。
5. 同じコマンドの末尾を`video`にしてMP4を書き出します。

ブラウザの場所を明示する場合は、環境変数`VIDEO_BROWSER_PATH`へ実行ファイルのパスを設定します。macOSではインストール済みChromeも自動検出します。画像・字幕・音声の処理は端末内で行い、計測データの外部送信はありません。依存パッケージの初回取得にはネット接続を使います。

作業用の音声・フレーム・中間動画はGit対象外の`output/video/app-overview/`へ保存します。最終成果物はこのフォルダへ出力します。出力先は生成スクリプトの位置から決定します。
