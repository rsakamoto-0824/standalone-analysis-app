# MATLAB スタンドアローン解析アプリ

露光 APC、スイングカーブ、汎用 GPR、保存モデル推定、SHAP、評価・要約の自動計算、D/I最適・直交表・拡張実験計画、ワードクラウドをローカルで実行する MATLAB R2025b 向けソースです。

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

1. 左の機能タブを選び、Excel / CSV を開き、シート・ヘッダー行を指定します。
2. 入力プレビューと列対応を確認し、「上表の列対応・順序を確認」を押します。
3. 学習条件を設定して実行すると RMSE・R²、全8指標、入力・実測・予測・残差の要約を表示します。学習時の指標は学習データへの当てはまりです。
4. MATを保存し、「保存後検証」の全項目を確認します。APCは保存・検証後にSHAPも計算します。
5. 右の「グラフ」で実測対予測・残差・SHAP等を表示します。すべてアプリ内の表示です。
6. 表のタブを選んで「表示中の表を保存」、または「グラフを PNG に保存」を押します。

保存モデル推定 / SHAP は、任意の実測列を選ぶと評価も計算します。実測列なしでは評価指標を計算しません。面内学習は削除し、既存の面内モデルでの推定だけ残しています。

評価指標は RMSE、RMSPE、MAE、Pearson r、相関係数の2乗、KL（nats）、相互情報量（bits）と、決定係数 R² = 1−SSE/SST です。未定義の指標は NaN と理由を表示します。従来の `calc_r_squared` は相関係数の2乗のままです。

「実験計画作成」は D最適、I最適、2/3水準の同一水準直交表、既存点を固定した D/I 拡張を選択できます。値は −1〜1 の符号化値です。交絡の図・係数表・ランクを確認してください。D/I は局所探索で大域最適性を保証しません。[更新仕様](docs/ui-update.md)に計算方式と制限を記載しています。

「設定」で保存先・テーマ・既定の学習条件等を保存できます。設定適用時は現在の結果と列対応の確認を解除します。「Help」に用語説明・公式関数ヘルプ・HTML手順書があります。幅1100px未満では入力を上、結果を下に配置します。

APC 学習後の SHAP 対象は先頭から最大1000行、評価指標は全行です。背景データは正本コードどおりモデル内の学習データを使います。ノイズ除去用 SHAP の背景データ数は既定値のままです。

## SHAPスイング近似

スイング学習で「学習後にSHAP・スイング近似を計算」をオンにするか、保存モデルのSHAPを実行し、「グラフ → SHAP 依存: RESIST_TH」を開きます。正弦波＋直線トレンドで周期・片振幅・R²・RMSEを計算し、指定した膜厚範囲内の極大・極小を注記します。山同士・谷同士を結ぶ破線と傾きを表示し、極値膜厚・隣接傾き・近似指標の表をCSV / Excelへ保存できます。

近似はSHAP寄与に対するもので、実測線幅そのもののフィットや物理的なバルク効果の証明ではありません。この一定振幅モデルでは山間・谷間の傾きは同じ一定値です。膜厚範囲と周期探索範囲を画面で変更でき、異なる膜厚8点以上が必要です。追加のCurve Fitting ToolboxやOptimization Toolboxは使いません。[計算仕様](docs/ui-update.md)と[画像付き手順](docs/user-guide/procedure-guide.html#shap)を参照してください。

近似後は「残差分布」「正規Q–Q」「残差対膜厚」をアプリ内で切り替えられます。残差はSHAP値−近似値です。Lilliefors検定（α=0.05）の判定・p値、偏り補正付きの歪度・尖度・超過尖度を表示します。「残差の正規性」「残差データ」の表はCSV / Excel、各図はPNGへ保存できます。尖度の正規分布の基準は3、超過尖度は0です。近似後の残差に対する検定は参考診断であり、棄却できなくても正規分布の証明ではありません。残差のばらつきが数値しきい値以下の場合は、検定や形状統計を対象外と明示します。

## 入力ファイル

- `.xlsx` / `.csv` に対応。ヘッダーは空でない一意の文字列にします。同じ列名を自動で変更しません。
- データは数値または数値文字列。単位変換や事前標準化は行いません。
- 学習・推定・SHAP の選択列に空セル / NaN があれば、元ファイルの行番号を表示して停止します。Inf や数値以外の文字列も停止対象です。
- 同じ入力列の複数変数への割当を拒否します。目的変数を説明変数と兼用することもできません。
- 既存の面内モデルの推定は X・Y と、正本どおり `sqrt(X.^2 + Y.^2)` で求めた半径を使います。半径150 mm以上も除外しません。
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
- 汎用 GPR は数値行列で学習し、説明変数名や `ResponseName` を指定しません。旧面内学習関数は原仕様の互換性照合用に残していますが、アプリから呼び出しません。
- `fitrgp` の名前・値引数、順序、標準化、`save` の形式オプションは添付指示の4章を維持しています。
- `verify_saved_model(path, before, model_type)` で保存前モデルと比較できます。アプリは任意の第4引数に画面の kernel / fit_method、固定の BasisFunction、実際の学習行数を渡し、選択値との一致も確認します。
- 保存後に変数名、クラス、説明変数名と順序、ResponseName、学習設定、行数、予測値の完全一致を検証します。

`RegressionGP` は学習データを含む完全なモデルです。MAT ファイル自体も入力データと同じ管理区分で扱ってください。信頼できる作成元の MAT だけを読み込んでください。

## ログ

`fullfile(prefdir, 'StandaloneAnalysisApp', 'logs', 'training.jsonl')` に、日時（JST）、機能、入力ファイル名、行数、kernel、fit_method、保存先、検証結果、PredictorNames、ResponseName、終了状態、処理時間を追記します。保存キャンセルや学習開始後のエラーも記録します。X・y の値はログに記録しません。ログ保存失敗は画面へ通知します。

ユーザー設定は `fullfile(prefdir, 'StandaloneAnalysisApp', 'settings.json')` に保存し、モデルMATには追加しません。モデル別の付帯ファイルは作りません。測定データを外部サービスへ送信するコードはありません。

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
