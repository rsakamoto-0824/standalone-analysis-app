# MATLAB スタンドアローン解析アプリ

露光 APC、スイングカーブ、面内推定、汎用 GPR、SHAP、評価指標、列の要約統計量、D 最適計画、ワードクラウドをローカルで実行する MATLAB R2025b 向けソースです。

**現在はソース作成段階です。R2025b での実行検証、App Designer の `AnalysisApp.mlapp` 作成、Windows exe の生成、Runtime だけの端末での起動確認は未実施です。** 手元の R2022b でモデルを学習・保存することはありません。対象リリース以外ではアプリと学習処理を停止します。

スクリーンショット付きの詳細手順は、[ビルド・利用手順書（HTML）](docs/user-guide/procedure-guide.html)を参照してください。GitHub では HTML のソースが表示されるため、**Code → Download ZIP で取得・展開し、`docs/user-guide/procedure-guide.html` を PC のブラウザで開きます。** 画像やスタイルも必要なので、`docs/user-guide/` のフォルダ一式を保持してください。アプリ画像は R2022b の表示見本、App Designer の説明画像は出典を記した公式資料の掲載例です。

## 必要な環境

- 開発・単体テスト: MATLAB R2025b、Statistics and Machine Learning Toolbox。
- exe 作成: Windows 64bit 上の上記環境と MATLAB Compiler。
- 配布先: Windows 64bit、MATLAB Runtime R2025b。ビルド環境と同じ更新版、または対応する新しい更新版を使用して検証してください。
- Excel 本体、外部 API、認証情報、環境変数の設定は不要です。

## 起動とテスト

MATLAB R2025b でこのフォルダを現在のフォルダにします。

```matlab
setup_paths;
controller = launch_analysis_app; % ソースの画面を確認
results = run_tests;             % 全単体テスト。失敗時はエラー
```

配布用の入口は `app/AnalysisApp.mlapp` です。[Windows ビルド手順](docs/windows-build.md)に従って、R2025b の App Designer で薄い入口を作成します。画面の構築と操作は `AnalysisController.m`、グラフ表示は `app/plot_shap_figures.m` にまとめています。計算処理は `core/` にあり、ファイル選択・保存ダイアログや figure を呼びません。

## 基本操作

1. 左のタブで機能を選び、「Excel / CSV を開く」を押します。
2. Excel ではシートを選び、Excel / CSV ともにヘッダー行を指定します。
3. 「入力プレビュー」で先頭 100 行を確認します。計算には読み込んだ全行を使います。
4. 対応表で「入力列」を選択します。APC / スイングカーブは指定の4列順、面内推定は X→Y、汎用 GPR は対応表の上から順です。目的変数は `y` に割り当てます。
5. 「上表の列対応・順序を確認」を押してから実行します。入力・モデル・対応表・入力数・推定方式の変更時は確認が解除されます。
6. 学習後、MAT の保存先を選択します。保存をキャンセルすると SHAP・面内推定は実行しません。
7. 保存後の自動検証を確認します。失敗すると後続処理を止め、「このモデルを制御に使用しないでください」と表示します。
8. 結果を CSV / Excel に保存できます。SHAP / ワードクラウドは別ウィンドウに表示し、PNG に保存できます。

面内学習では推定用のファイルを追加で読み込み、その X・Y 列も確認します。推定用ファイルがなければ学習・保存・検証だけを行います。「保存モデルで推定」では、汎用推定と面内推定を明示的に選択してください。列名のない3変数モデルからモデルの用途を推測することはしません。

SHAP 解析タブでは「SHAP依存確認」「ノイズ除去用SHAP」を選択します。APC 学習後の SHAP 対象は先頭から最大 1000 行です。背景データは正本コードどおりモデル内の学習データをすべて使います。ノイズ除去用 SHAP の背景データ数は既定値のままです。

汎用 GPR の説明変数の数は画面の数値欄で指定し、順序は対応表で確認します。評価指標の `r_squared` は相関係数の2乗です。KL の単位は nats、相互情報量は bits、RMSPE は % です。要約統計量だけは NaN を除外し、不偏標準偏差を使います。

## 入力ファイル

- `.xlsx` / `.csv` に対応。ヘッダーは空でない一意の文字列にします。同じ列名を自動で変更しません。
- データは数値または数値文字列。単位変換や事前標準化は行いません。
- 学習・推定・SHAP の選択列に空セル / NaN があれば、元ファイルの行番号を表示して停止します。Inf や数値以外の文字列も停止対象です。
- 同じ入力列の複数変数への割当を拒否します。目的変数を説明変数と兼用することもできません。
- 面内モデルは X・Y と、正本どおり `sqrt(X.^2 + Y.^2)` で求めた半径を使います。半径150 mm以上も除外しません。
- ワードクラウドは直接入力 / `.txt` 読込に対応。日本語は空白区切りにしてください。

## モデルの保存仕様

`save_train_model.m` は次の正本をそのまま使用します。

```matlab
function save_train_model(Train_Model, fullName)
    % 制御側が変数名 Train_Model で読み込むため、ローカル変数名を変えないこと
    save(fullName, "Train_Model");
end
```

- MAT 内の変数は `Train_Model` だけ。`fitrgp` の戻り値 `RegressionGP` を保存し、`compact` にしません。
- APC / スイングカーブの説明変数は `SIN_TH`, `SIN_RN`, `NSG_TH`, `RESIST_TH` の順。
- 面内 / 汎用 GPR は数値行列で学習し、説明変数名や `ResponseName` を指定しません。
- `fitrgp` の名前・値引数、順序、標準化、`save` の形式オプションは添付指示の4章を維持しています。
- `verify_saved_model(path, before, model_type)` で保存前モデルと比較できます。アプリは任意の第4引数に画面の kernel / fit_method、固定の BasisFunction、実際の学習行数を渡し、選択値との一致も確認します。
- 保存後に変数名、クラス、説明変数名と順序、ResponseName、学習設定、行数、予測値の完全一致を検証します。

`RegressionGP` は学習データを含む完全なモデルです。MAT ファイル自体も入力データと同じ管理区分で扱ってください。信頼できる作成元の MAT だけを読み込んでください。

## ログ

`fullfile(prefdir, 'StandaloneAnalysisApp', 'logs', 'training.jsonl')` に、日時（JST）、機能、入力ファイル名、行数、kernel、fit_method、保存先、検証結果、PredictorNames、ResponseName、終了状態、処理時間を追記します。保存キャンセルや学習開始後のエラーも記録します。X・y の値はログに記録しません。ログ保存失敗は画面へ通知します。

モデル別の付帯ファイルは作りません。測定データを外部サービスへ送信するコードはありません。

## 現行モデルとの比較

現行アドインを使える環境で旧・新モデルを用意し、MATLAB R2025b で実行します。

```matlab
setup_paths;
comparison = compare_models('old.mat', 'new.mat', Xcheck);
```

`Xcheck` はモデルへの最終入力順の数値行列です。APC / スイングカーブは4列、面内は X・Y・半径の3列、汎用は元の P 列にしてください。列名、行数などの比較表、予測差の最大値、`isequal` の結果を表示します。旧モデルと新モデルの予測が一致したことを、開発側で推測して扱いません。

## ファイルと確認状況

- `app/`: 画面、ダイアログ、グラフ、書出し。
- `core/`: 学習、保存・検証、推定、SHAP、統計、入力読込、ログ。
- `tests/`: 指定 T-01〜T-10 と入力異常・SHAP形状などの追加テスト。
- `run_tests.m`: R2025b で全テストを実行。
- `check_sources.m`: 静的解析。R2025b での実行確認の代わりにはなりません。
- `check_model_contract.m`: 原仕様のコードブロックと4種類の学習本体・保存本体を比較。空行と字下げ以外の変更を検出します。
- `build_windows.m`: 全テスト成功後に `.mlapp` から Windows アプリを作成。
- [検証記録](verification.md)、[残課題](issues.md)、[原仕様](docs/specification.md)。

## 公式仕様

- [fitrgp](https://www.mathworks.com/help/stats/fitrgp.html)
- [RegressionGP](https://www.mathworks.com/help/stats/regressiongp.html)
- [shapley](https://www.mathworks.com/help/stats/shapley.html) — 指定の `Shapley.Value` と `NumObservationsToSample` は R2024b 以降の API。
- [App Designer](https://www.mathworks.com/help/matlab/ref/appdesigner.html)
- [MATLAB 関数で構築した画面を MLAPP から呼び出す方法](https://www.mathworks.com/matlabcentral/answers/1607210-how-can-i-convert-a-gui-that-i-programmatically-create-using-a-matlab-file-to-a-mlapp-file)
- [Windows アプリのビルド](https://www.mathworks.com/help/compiler/compiler.build.standalonewindowsapplication.html)
- [スタンドアローンアプリの配布と OS の制約](https://www.mathworks.com/help/compiler/standalone-application-target.html)
