# Process Insight Tool

成膜・露光プロセスのモデリング・補間・実験計画をまとめて扱う解析アプリです。画面タイトルは **Process Insight Tool**、Windowsビルド時の実行ファイル名は `ProcessInsightTool.exe` です。

露光 APC、Swing Curve、汎用 GPR、保存モデル推定、SHAP、評価・要約の自動計算、D/I最適・直交表・拡張実験計画、ワードクラウド、炉内補間をローカルで実行する MATLAB R2025b 向けソースです。

紹介用の[インフォグラフ](docs/promotion/process-insight-tool-infographic.png)と[グラレコ風サムネイル](docs/promotion/process-insight-tool-sketchnote-thumbnail.png)を用意しています。[素材の説明・制作指示](docs/promotion/README.md)も参照できます。

左側の1〜10の画面切替メニューは幅を確保し、炉内補間を汎用GPRの直下へ配置しています。KL/MIビン数は「9 設定」で保存・適用する全画面共通設定です。各画面の「グラフをコピー」から図をクリップボードへ画像としてコピーできます。

「4 炉内補間」はLP-CVDのBoatSlotから膜厚・屈折率などを予測します。入力はWaferId・BoatSlot・1列以上の計測値、任意のバッチ列です。同時処理する複数Lotは同じRunのプロファイルとして扱い、バッチ列がある場合はRunごとに分離して学習します。バッチの値は成膜Runを一意に識別するようにしてください。バッチ列なしではファイル全体を1Runとして扱います。

計測列の空欄は項目別の未計測として扱い、各バッチ・各項目で5点以上の計測Slotが必要です。スプライン、3次多項式近似、Gaussian RBF＋直線、GPR（squaredexponential / matern52 / rationalquadratic）を比較します。内部Slotを1点ずつ外した検証の8指標と、全計測Slotの学習指標を表示し、順位はバッチ・項目ごとに付けます。両端は検証から除くため、端部・外挿の精度を表す評価ではありません。3次多項式近似（poly3）は、各Run・各項目の計測値全体を1本の3次式へ最小二乗法で当てはめる方式で、計測点を必ず通るものではありません。

予測範囲と間隔を指定し、バッチ・項目・候補別の予測表、WaferId・元ファイル行、比較図、検証残差、要約を確認できます。入力にない生成SlotのWaferIdは空欄です。対応付けたい未計測Waferは、計測列だけを空欄にして入力へ含めてください。範囲外は初期状態で計算せず、外挿を有効にした場合は表と破線で区別します。95%応答予測区間はGPRだけに付けます。CSV / Excel / PNGへ書き出し、炉内補間のモデルMAT保存は行いません。[画像付き手順](docs/user-guide/procedure-guide.html#furnace-interpolation)を参照してください。設定・Helpは「9 設定」「10 Help」です。

**現在はソース作成段階です。R2025b での実行検証、App Designer の `AnalysisApp.mlapp` 作成、Windows exe の生成、Runtime だけの端末での起動確認は未実施です。** 手元の R2022b でRegressionGPを学習・保存することはありません。数値の補助確認と表示見本は対象リリースの検証と区別し、製品アプリとGPR学習はR2025b以外で停止します。

スクリーンショット付きの詳細手順は、[ビルド・利用手順書（HTML）](docs/user-guide/procedure-guide.html)を参照してください。GitHub では HTML のソースが表示されるため、**Code → Download ZIP で取得・展開し、`docs/user-guide/procedure-guide.html` を PC のブラウザで開きます。** 画像やスタイルも必要なので、`docs/user-guide/` のフォルダ一式を保持してください。アプリ画像は R2022b の表示見本、App Designer の説明画像は出典を記した公式資料の掲載例です。

音声・字幕付きの[アプリ解説動画（MP4、約3分27秒）](docs/video/app-overview/app-overview-ja.mp4)も用意しています。[動画の閲覧方法](docs/video/app-overview/README.md)を参照してください。章を選んで再生する場合は、ZIPを展開後に`docs/video/app-overview/index.html`を開きます。

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
6. 表のタブを選んで「表示中の表を保存」、または「グラフを PNG に保存」を押します。「グラフをコピー」は画像としてコピーし、ExcelやPowerPoint等へ貼り付けられます。

APC・Swing Curve・汎用GPRの各学習では、「複数カーネルの比較画面を開く」から2個以上を選んで一括検証できます。同じランダム分割を全候補で使い、学習に使わなかった行への予測から8指標を計算します。既定は5分割・seed=0です。検証RMSEの順位、全指標と未定義理由、分割別RMSE、行ごとの検証予測、要約、比較グラフをアプリ内に表示し、CSV / Excel / PNGに保存できます。fit_methodは左欄の共通設定です。通常の「実行」はこれまでどおり1種類を学習します。

採用候補を選んで「選択モデルをMAT保存」を押すと、比較時に全データで学習して保持した完全モデルを再学習せず保存・検証します。保存する変数は従来どおり`Train_Model`だけです。比較結果と他の候補モデルはMATへ入れません。APCのSHAP、Swing Curveの任意SHAPは選択モデルの保存・検証後に行います。候補の失敗理由は比較表に残し、失敗候補は保存対象にしません。

検証値は全行の検証予測を結合して求め、分割ごとの指標の平均ではありません。Swing Curveの`swingperiodic`も候補にでき、各分割の学習データ内で周期を探索し直します。候補ごとに「分割数＋1」回の学習、周期カーネルではさらに各学習内で周期探索を行うため、時間とメモリーが増えます。候補は順に計算し、Parallel Computing Toolboxは不要です。APCは各分割の学習に25行以上必要です。

この比較はランダムな行分割です。ロット・時系列・同じ試料の反復などの依存を分離する機能はありません。カーネル選定にも使った検証値には選定による偏りがあるため、採用後は別の独立データで評価してください。[画像付きの比較手順](docs/user-guide/procedure-guide.html#kernel-comparison)を参照してください。R2025bの実GPR比較・選択モデル保存とWindowsの最終検証は未実施です。

保存モデル推定 / SHAP は、任意の実測列を選ぶと評価も計算します。実測列なしでは評価指標を計算しません。面内学習は削除し、既存の面内モデルでの推定だけ残しています。

評価指標は RMSE、RMSPE、MAE、Pearson r、相関係数の2乗、KL（nats）、相互情報量（bits）と、決定係数 R² = 1−SSE/SST です。未定義の指標は NaN と理由を表示します。従来の `calc_r_squared` は相関係数の2乗のままです。

「実験計画作成」は D最適、I最適、2/3水準の同一水準直交表、既存点を固定した D/I 拡張を選択できます。値は −1〜1 の符号化値です。交絡の図・係数表・ランクを確認してください。D/I は局所探索で大域最適性を保証しません。[更新仕様](docs/ui-update.md)に計算方式と制限を記載しています。

「設定」で保存先・テーマ・既定の学習条件等を保存できます。設定適用時は現在の結果と列対応の確認を解除します。「Help」に用語説明・公式関数ヘルプ・HTML手順書があります。幅1100px未満では入力を上、結果を下に配置します。

APC 学習後の SHAP 対象は先頭から最大1000行、評価指標は全行です。背景データは正本コードどおりモデル内の学習データを使います。ノイズ除去用 SHAP の背景データ数は既定値のままです。

## SHAP Swing Curve近似

Swing CurveのGPR学習では、kernelに `swingperiodic` も選択できます。RESIST_THの周期成分、他3変数の滑らかな影響、膜厚の線形トレンドを組み合わせたカーネルです。周期の入力欄は設けず、`KernelParameters` / `OptimizeHyperparameters` に周期を含めません。固定周期ごとにGPRを再学習して周辺対数尤度を比較し、内部探索で周期を決めます。`sd` / `sr` / `fic` は近似尤度を使います。APC・汎用GPRのカーネル候補は従来どおりです。

選ばれた周期・探索範囲・尤度を左欄に、候補ごとの値を「周期の最適化」とグラフへ表示します。表はCSV / Excel、図はPNGに保存できます。「設定」のSwing Curve専用kernelで既定値を変更できます。最大48候補の再学習で通常の1回の学習より時間がかかり、大域最適性は保証しません。探索履歴は今回の実行画面と書出し表に残し、MATには従来どおり `Train_Model` だけを保存します。周期はモデル内に保持し、読込み時にも表示します。R2025bでの実学習・保存・SHAP・制御側での予測とRuntimeの確認は未実施です。[詳しい利用手順](docs/user-guide/procedure-guide.html#periodic-kernel)を参照してください。

Swing Curve学習で「学習後にSHAP・Swing Curve近似を計算」をオンにするか、保存モデルのSHAPを実行し、「グラフ → SHAP 依存: RESIST_TH」を開きます。正弦波＋直線トレンドで周期・片振幅・R²・RMSEを計算し、指定した膜厚範囲内の極大・極小を注記します。山同士・谷同士を結ぶ破線と傾きを表示し、極値膜厚・隣接傾き・近似指標の表をCSV / Excelへ保存できます。

近似はSHAP寄与に対するもので、実測線幅そのもののフィットや物理的なバルク効果の証明ではありません。この一定振幅モデルでは山間・谷間の傾きは同じ一定値です。膜厚範囲と周期探索範囲を画面で変更でき、異なる膜厚8点以上が必要です。追加のCurve Fitting ToolboxやOptimization Toolboxは使いません。[計算仕様](docs/ui-update.md)と[画像付き手順](docs/user-guide/procedure-guide.html#shap)を参照してください。

近似後は「残差分布」「正規Q–Q」「残差対膜厚」をアプリ内で切り替えられます。残差はSHAP値−近似値です。Lilliefors検定（α=0.05）の判定・p値、偏り補正付きの歪度・尖度・超過尖度を表示します。「残差の正規性」「残差データ」の表はCSV / Excel、各図はPNGへ保存できます。尖度の正規分布の基準は3、超過尖度は0です。近似後の残差に対する検定は参考診断であり、棄却できなくても正規分布の証明ではありません。残差のばらつきが数値しきい値以下の場合は、検定や形状統計を対象外と明示します。

## 入力ファイル

- `.xlsx` / `.csv` に対応。ヘッダーは空でない一意の文字列にします。同じ列名を自動で変更しません。
- データは数値または数値文字列。単位変換や事前標準化は行いません。
- APC・Swing Curve・汎用GPRの学習、保存モデル推定・SHAPでは、選択列に空セル / NaN があれば元ファイルの行番号を表示して停止します。炉内補間の計測列だけは未計測として扱います。Inf や数値以外の文字列は停止対象です。
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
- APC / Swing Curveの説明変数は `SIN_TH`, `SIN_RN`, `NSG_TH`, `RESIST_TH` の順。
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

`Xcheck` はモデルへの最終入力順の数値行列です。APC / Swing Curveは4列、面内は X・Y・半径の3列、汎用は元の P 列にしてください。列名、行数などの比較表、予測差の最大値、`isequal` の結果を表示します。旧モデルと新モデルの予測が一致したことを、開発側で推測して扱いません。

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
