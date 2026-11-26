# Process Insight Tool

多目的最適化と因果探索の評価には、[公開ベンチマークデータ20件](benchmarks/public-data/README.md)を利用できます。CSV本体、選択する列、目的の向き、正解グラフ・候補内パレート解、出典とライセンスを収録しています。

成膜・露光プロセスのモデリング・補間・実験計画をまとめて扱う解析アプリです。通常版は **Process Insight Tool**（`ProcessInsightTool.exe`）、プロ版は **Process Insight Tool Pro**（`ProcessInsightToolPro.exe`）です。MATLAB R2025b 向けのソースで、すべての処理をローカルで実行します。

紹介用の[インフォグラフ](docs/promotion/process-insight-tool-infographic.png)と[グラレコ風サムネイル](docs/promotion/process-insight-tool-sketchnote-thumbnail.png)を用意しています。[素材の説明・制作指示](docs/promotion/README.md)も参照できます。

## できること

| メニュー | 内容 |
|---|---|
| 1 APC 学習 | 露光APC用のGPRモデル（SIN_TH・SIN_RN・NSG_TH・RESIST_TH）を学習し、制御用のMATを保存。学習画面（1〜3）の①では、読み込んだデータの傾向をグラフで確認できる（単変量の傾向。Pro 版はヒストグラム・相関マトリックス・ANOVA・Parallel Coordinates・Parallel Sets・Sankey Diagram・主成分分析・クラスタリングも） |
| 2 Swing Curve学習 | レジスト膜厚に対する線幅の周期変動を学習。下地なし（膜厚のみ）／下地あり。周期カーネル `swingperiodic` と周期の探索範囲は Pro 版のみ |
| 3 汎用回帰学習 | 任意の列で GPR・重回帰・PLS・ランダムフォレスト・バギング木を学習して比較。Pro 版は EBM（GA2M）・XGBoost・LightGBM・CatBoost も選べ、ハイパーパラメータの調整とグリッド／ランダムサーチ（推移と傾向のグラフ）ができる。結果の一覧は目的変数ごとに精度の順位で並ぶ。Permutation Importance と VIP（PLS）で変数重要度を表示。Pro 版の GPR は加法カーネルと質的変数にも対応 |
| 4 炉内補間 | LP-CVD の BoatSlot ごとの膜厚・屈折率を、成膜Run（バッチ）ごとに補間。検証RMSEは目的変数ごとの棒グラフで並べる |
| 5 保存モデルで推定・SHAP | 保存したMAT、または学習直後のモデルで推定・評価し、どのモデルでも SHAP の分布と依存図を表示（以前の「保存モデルで推定」と「SHAP 解析」を統合） |
| 6 Sobol感度解析（Pro 版） | Excel / CSV のデータ（代替モデル GPR・ランダムフォレスト）または保存モデルで、各入力が出力のばらつきに効く割合（1次・全効果の指数）。予測値の分布の平均・最頻値・95%区間・±nσ も表示 |
| 7 因果探索（Pro 版） | PC アルゴリズムまたは DirectLiNGAM で、列（最大50列）どうしの因果の向きの候補をグラフ表示 |
| 8 階層ベイズ（Pro 版） | グループ（ロット・装置など）ごとの回帰係数を、全体の傾向へ引き寄せて推定（ギブスサンプリング） |
| 9 コピュラ乱数生成（Pro 版） | データの列どうしの関係（またはご自分で指定した分布と順位相関）を保った乱数を、コピュラ（ガウス・t・Clayton・Frank・Gumbel）で生成 |
| 10 実験計画作成（通常版は6） | D最適・I最適・直交表（2〜5水準）、D効率・A効率・I基準・G効率・VIF などの評価指標と予測分散の分布、交絡の確認。既存計画への追加（拡張計画）は Pro 版だけ |
| 11 ワードクラウド（Pro 版） | 文章中の単語の出現数を図示。形と色を変えられ、英語のよく使う語（I・we・it・be 動詞など）や指定した語を除ける |
| 12 設定 / 13 Help（通常版は 7・8） | 保存先・テーマ・文字の大きさ・学習条件の初期値、版ごとの用語と操作の説明 |

## 現在の状態（2026-11-17）

- **2026-11-17**：Swing Curve の基準周期を「波長÷屈折率÷2」（約70nm）に修正し、SHAP 依存図の色の変数の選択、モデリングの進捗バー、実測値と予測値・残差の横並び表示、予測・残差・SHAP の1ファイル出力、[利用者向け手順書](docs/user-guide/user-manual.html)を追加しました。同梱サンプルの合成データも新しい周期で計算し直しています。
- **画面を作り直しました（2026-11-16）。** 学習画面は上のタブを左から「① データを開く → ② 変数を選ぶ → ③ 条件を決めて実行 → ④ 結果を比べて保存」の順に進みます。変更の内容と理由は[更新仕様](docs/ui-update.md)の「2026-11-16：画面の作り直し」を参照してください。
- **2026-11-20**：学習画面の①にデータのグラフ（Pro 版は9種類）、Pro 版の汎用回帰に EBM・XGBoost・LightGBM・CatBoost とハイパーパラメータの探索、実験計画の評価指標を追加し、結果の一覧を目的変数ごとに精度の順位で並べるようにしました。ワードクラウドは Pro 版だけにし、形と色を変えられるようにしました。XGBoost などは各ライブラリそのものではなく、考え方を MATLAB で実装したものです（[更新仕様](docs/ui-update.md)）。
- **2026-11-26**：通常版の「グラフで傾向を見る」からグラフの種類・列・群の分け方・群の数の欄を外しました（単変量の傾向だけ）。通常版のインストーラーにはサンプルと手順書を入れず、別に配るようにしました（サンプルは `samples/separate/standard`。「サンプルデータを開く」で配られたブックを選びます）。ビルドのテストは通常版では Pro 版だけの機能のテストを除き、`build_windows(版, 'Tests', false)` でテストを省いてすぐビルドできます。Sobol感度解析の「データから／保存モデルで」を2つのボタンで選ぶようにしました。
- **2026-11-25（2）**：Sobol感度解析を「データを解析する」へ移し、Excel / CSV のデータから解析できるようにしました（予測値の分布の統計も追加）。「グラフで傾向を見る」は種類を複数選んで一括で描け、描いた結果を残して追加するようにしました。Parallel Sets・Sankey は任意の列で色を付けられます。ワードクラウドに除く語、因果探索の列の上限を50に、Pro 版にコピュラ乱数生成を追加しました（メニューの番号が変わりました）。
- **2026-11-25**：通常版を MATLAB のない PC で使うと Excel の読込みが「Implementation Error: cannot call this method before validating "Filename"」で止まる問題に対策しました（Excel・CSV を MATLAB の readcell・readtable を使わずに直接読む）。インストーラーに入れるサンプルを `samples/installer/standard`・`samples/installer/pro` に分け、通常版にはワードクラウド・拡張計画のサンプルと手順書（docs）を入れないようにしました。サンプルの置き換え方は [Windows での確認・ビルド手順](docs/windows-build.md) と[ビルド手順書](docs/user-guide/build-guide.html)にあります。
- **2026-11-20（2）**：「保存モデルで推定」と「SHAP 解析」を1つの画面にし、どのモデルでも SHAP 依存図を表示するようにしました。炉内補間の検証RMSEを目的変数ごとの棒グラフに分け、汎用回帰に Permutation Importance と VIP を追加しました。Pro 版に GPR の加法カーネル・質的変数、Sobol感度解析・因果探索・階層ベイズの画面を追加しました（メニューの番号が変わりました。通常版は 5 推定・SHAP、6 実験計画、7 設定、8 Help）。
- 手元の MATLAB R2022b（macOS）では、開発用の例外で起動して、同梱サンプルで全機能を通す確認（23項目）と単体テストに成功しています（件数は [検証記録](verification.md)）。
- **MATLAB R2025b / Windows での確認、SHAP の実計算、インストーラーの作成、MATLAB のない PC へのインストールと起動の確認は未実施です。** [Windows での確認・ビルド手順](docs/windows-build.md)に従って確認してください。
- 製品アプリと学習処理は R2025b 以外では停止します。

手順書（HTML）は3つあります。配布版（通常版）を Windows で使う方は[利用手順書](docs/user-guide/user-manual.html)、通常版と Pro 版の exe を作る担当者は[ビルド手順書](docs/user-guide/build-guide.html)、Pro 版だけの機能や計算の詳しい説明は[ビルド・利用手順書（詳細）](docs/user-guide/procedure-guide.html)を参照してください。GitHub では HTML のソースが表示されるため、**Code → Download ZIP で取得・展開し、`docs/user-guide/user-manual.html`（または `build-guide.html`・`procedure-guide.html`）を PC のブラウザで開きます。** 画像やスタイルも必要なので、`docs/user-guide/` のフォルダ一式を保持してください。

音声・字幕付きの[アプリ解説動画（MP4、約3分27秒）](docs/video/app-overview/app-overview-ja.mp4)は、**作り直す前の画面**で作成したものです。機能の概要の参考にしてください。[動画の閲覧方法](docs/video/app-overview/README.md)を参照してください。

## 必要な環境

- 開発・単体テスト: MATLAB R2025b、Statistics and Machine Learning Toolbox。
- exe 作成: Windows 64bit 上の上記環境と MATLAB Compiler。
- 配布先: Windows 64bit。**MATLAB は不要**です。ビルドで作るインストーラーに MATLAB Runtime を同梱するため、利用者はインストーラーを1つ実行するだけで使えます（インストール時のインターネット接続も不要）。
- Excel 本体、外部 API、認証情報、環境変数の設定は不要です。

## 起動と確認

MATLAB R2025b でこのフォルダを現在のフォルダにします。

```matlab
setup_paths;
controller = launch_analysis_app;      % アプリを起動（Pro版の画面は launch_analysis_app('pro')）

addpath('tests');
results = run_app_flow_check;          % 同梱サンプルで全機能を通す確認（23項目、数分）
results = run_tests;                   % 全単体テスト。失敗時はエラー
results = run_tests('standard');       % 通常版で使う機能のテストだけ（Pro 版だけの機能のテストを除く）
```

配布用のインストーラー（MATLAB Runtime を同梱）は `build_windows('standard')` / `build_windows('pro')` で作成します。入口は `app/launch_analysis_app.m` で、App Designer での手作業は不要です。Pro 版は exe と同じフォルダとインストーラーに、サンプル（`samples`）と手順書（`docs\user-guide`）も入れます。通常版はアプリだけで、サンプルと手順書は別に配ります。テストを省いてすぐビルドするときは `build_windows('standard', 'Tests', false)` とします。手順は[ビルド手順書](docs/user-guide/build-guide.html)を参照してください。

## 基本操作（学習：1〜3）

1. **① データを開く**：Excel / CSV を開きます。シートとヘッダー行は同じ画面で変更でき、先頭100行を確認できます。「サンプルデータを開く」で同梱の合成データを試せます。
2. **② 変数を選ぶ**：左で目的変数（1〜20列。列ごとに別モデル）、右で説明変数を選びます。APC は4変数へ列を割り当て、Swing Curve は「下地なし／下地あり」と膜厚の列・下地の列を選び、汎用回帰は入力に使う列を選んで順序を確認します。確認のボタンはなく、実行したときに列の中身（数値でない値・空欄・重複・目的変数との重なり）を自動で確認し、問題があれば理由を表示して②へ戻ります。目的変数を自動では決めません（列名が CD・y・膜厚・屈折率のときだけ初期選択）。
3. **③ 条件を決めて実行**：GPR のカーネル（汎用回帰では回帰方式と、PLS の成分数・ランダムフォレストとバギング木の木の本数も）を選びます。初期状態では交差検証を使わず、学習データでの当てはまりで評価します（条件をいくつ選んでも比べられます）。「交差検証で評価する」を選ぶと、同じ分割の交差検証（既定5分割・seed 0）で評価します。SHAP の計算は省略でき、後から計算できます。GPR の Fit method は「9 設定」の共通値を使います。
4. **④ 結果を比べて保存**：一覧の行をクリックすると、評価指標・実測値と予測値と残差（1つのタブに横並び）・条件の比較・SHAP を表示します。SHAP 依存図は「色の変数」で点の色に使う説明変数を選べます。「予測・SHAPを1ファイルに保存」で、元データの説明変数・目的変数と予測値・残差・SHAP値を並べた表を CSV / Excel の1ファイルに保存できます。条件を変えて再実行しても以前の結果は残ります。最後に「選択モデルをMAT保存」で、選んだ1モデルだけを再学習せずに保存・検証します。

一覧はアプリの終了で消えるため、使うモデルは終了前に保存してください。SHAP が失敗したモデルも理由とともに残り、「選択モデルのSHAPを計算」で再計算できます。学習に失敗した条件は保存できません。

交差検証では各分割の学習行だけで周期を探索し、全行の検証予測をまとめて8指標を求めます。ランダムな行分割はロット・時系列の依存を分離しないため、採用後は独立したデータでも評価してください。

## そのほかの機能

- **保存モデルで推定 / SHAP 解析**：左の ① モデル → ② データ → ③ 列の割当 → ④ 実行 の順に進みます。モデルは MAT のほか、起動中に学習したモデルも保存せずに選べます。実測列を選ぶと評価も計算します。面内学習は削除し、既存の面内モデルでの推定だけ残しています。
- **炉内補間**：学習画面と同じ4ステップです。入力は WaferId・BoatSlot・1列以上の計測値と、任意のバッチ列です。同時処理する複数 Lot は同じ Run のプロファイルとして扱い、バッチの値が異なる行は別々に補間します。計測値の空欄は項目別の未計測として扱い、各バッチ・各項目で5点以上の計測 Slot が必要です。スプライン、3次多項式近似、Gaussian RBF＋直線、GPR（squaredexponential / matern52 / rationalquadratic）を、内部 Slot を1点ずつ外した検証で比べます。両端は検証から除くため、端部・外挿の精度を表す評価ではありません。選んだ1モデルを専用の `Furnace_Model` 形式で保存できます（制御用 `Train_Model` とは別）。[画像付き手順](docs/user-guide/procedure-guide.html#furnace-interpolation)を参照してください。
- **実験計画作成**：値は −1〜1 の符号化値です。D/I は局所探索で大域最適性を保証しません。乱数 seed は設定画面だけで指定します。[更新仕様](docs/ui-update.md)に計算方式と制限を記載しています。
- **設定**：Fit method、KL / MI ビン数、実験計画の seed、炉内補間の RBF 幅・正則化は設定画面だけで変更します。設定を変えても表示中の結果や学習済みモデルの一覧は消えず、次の実行から反映します。
- **評価指標**：RMSE、RMSPE、MAE、Pearson r、相関係数の2乗、KLダイバージェンス、相互情報量と、決定係数 R² = 1−SSE/SST です。未定義の指標は NaN と理由を表示します。
- **書出し**：表は CSV / Excel、グラフは PNG へ保存でき、「グラフをコピー」で画像をクリップボードへ入れられます。推定・SHAP 解析の結果も、元データの説明変数・実測列と予測値・残差・SHAP値を並べた1つの表で出力します。CSV は Windows の Excel で日本語が文字化けしないよう、BOM 付きの UTF-8 で保存します。
- **進捗バー**：モデリングと炉内補間では、実行ボタンを押すとすぐに進捗バーを表示し、進んだ割合・経過時間・残り時間の目安・計算中の目的変数と条件を示します。

## 通常版／Pro版

`build_windows('standard')` は `build/windows/standard/ProcessInsightTool.exe`、`build_windows('pro')` は `build/windows/pro/ProcessInsightToolPro.exe` を作成します。通常版の隔離ソースには Pro 専用の35ファイルを入れず、版の設定をコンパイル前に固定します。起動後に版を切り替える機能はありません。

通常版は SHAP 分布（標準の swarmchart）と依存図まで利用できます。レジスト膜厚の SHAP 値へのフィッティング（三角関数・スプライン）、極値、山間／谷間の傾き、近似残差の診断、実験計画の拡張（既存の計画への追加）は Pro 版に限定します。「10 Help」も版ごとの内容で、通常版には Pro 版だけの説明と作成担当者向け手順書のボタンを出しません。通常版の exe とインストーラーにはサンプルも手順書も入れません（別に配ります）。APC 学習画面には、Pro 版でも Swing Curve 評価を表示しません。これらは SHAP 寄与の評価であり、物理的なバルク効果を証明するものではありません。計算方式は[更新仕様](docs/ui-update.md)を参照してください。

## Swing Curve学習の周期カーネル

Pro 版の Swing Curve の GPR 学習では、kernel に `swingperiodic` も選択できます（通常版には、このカーネルと周期の探索範囲の欄はありません）。周期成分と膜厚の線形トレンドを組み合わせます。基準周期は **露光波長 ÷ レジスト屈折率 ÷ 2**（レジスト膜内の定在波の周期 λ/2n）で、既定の248nm・1.77では 248÷1.77÷2≒70.06nm です。既定ではその75〜125%（約52.54〜87.57nm）を周辺尤度で探索します。任意の周期下限・上限も指定できます。周期は `KernelParameters` / `OptimizeHyperparameters` に含めず、固定周期ごとに GPR を再学習して周辺対数尤度を比較します（最大48候補）。`sd` / `sr` / `fic` は近似尤度を使います。大域最適性は保証しません。MAT には従来どおり `Train_Model` だけを保存し、周期はモデル内に保持します。[詳しい利用手順](docs/user-guide/procedure-guide.html#periodic-kernel)を参照してください。

## 入力ファイル

- `.xlsx` / `.csv` に対応。ヘッダーは空でない一意の文字列にします。同じ列名を自動で変更しません。
- データは数値または数値文字列。単位変換や事前標準化は行いません。
- 学習・推定・SHAP では、選択列に空セル / NaN があれば元ファイルの行番号を表示して停止します。炉内補間の計測列だけは未計測として扱います。Inf や数値以外の文字列は停止対象です。
- 同じ入力列の複数変数への割当を拒否します。目的変数を説明変数と兼用することもできません。
- 既存の面内モデルの推定は X・Y と、正本どおり `sqrt(X.^2 + Y.^2)` で求めた半径を使います。半径150 mm以上も除外しません。
- ワードクラウド（Pro 版）は直接入力 / `.txt` 読込に対応。日本語は空白区切りにしてください。

## モデルの保存仕様

`save_train_model.m` は次の正本をそのまま使用します。

```matlab
function save_train_model(Train_Model, fullName)
    % 制御側が変数名 Train_Model で読み込むため、ローカル変数名を変えないこと
    save(fullName, "Train_Model");
end
```

- GPRのMAT内の変数は `Train_Model` だけ。`fitrgp` の戻り値 `RegressionGP` を保存し、`compact` にしません。重回帰・PLSは後述の `Regression_Model` 形式です。
- APCの説明変数は `SIN_TH`, `SIN_RN`, `NSG_TH`, `RESIST_TH` の順。Swing Curveは1〜100列で最後の説明変数が `RESIST_TH`。4列では従来の順序を初期表示します。旧4列学習関数は互換性照合用に保持し、アプリは可変列の学習関数を使用します。
- 汎用回帰のGPRは数値行列で学習し、説明変数名や `ResponseName` を指定しません。旧面内学習関数は原仕様の互換性照合用に残していますが、アプリから呼び出しません。
- APC・旧4列Swing Curve・旧面内・汎用GPRの正本5ブロックとMAT内の変数名は維持しています。可変列Swing Curveは別の学習関数で標準化と完全なRegressionGPの保存に対応します。
- `verify_saved_model(path, before, model_type)` で保存前モデルと比較できます。アプリは任意の第4引数に画面の kernel / fit_method、固定の BasisFunction、実際の学習行数を渡し、選択値との一致も確認します。
- 保存後に変数名、クラス、説明変数名と順序、ResponseName、学習設定、行数、予測値の完全一致を検証します。

`RegressionGP` は学習データを含む完全なモデルです。MAT ファイル自体も入力データと同じ管理区分で扱ってください。信頼できる作成元の MAT だけを読み込んでください。

- 重回帰・PLS・ランダムフォレスト・バギング木は `ProcessRegressionModel` 型の `Regression_Model` だけを保存します（初期名 `GenericRegression_Model_目的変数.mat`）。ランダムフォレスト・バギング木は `fitrensemble`（Bag、葉の最小行数5）の `CompactRegressionEnsemble` を保持し、ランダムフォレストは分岐ごとに説明変数の約1/3（切り上げ）、バギング木は全変数を候補にします。木の本数は10〜1000（既定100）。説明変数名には入力ファイルの列名を保持します。再利用は本アプリ、または `core` をパスへ追加した MATLAB で `load_analysis_model` と `predict` を使用します。GPR の `Train_Model` 専用の制御側へは渡しません。
- 保存名は目的変数を付けた `Train_Model_CD_X.mat`、`SwingCurve_Model_CD_X.mat`、`GenericGPR_Model_Y1.mat` などが初期値です。MAT 内の変数名とモデルの ResponseName は従来の契約を維持します。

## ログと設定

`fullfile(prefdir, 'StandaloneAnalysisApp', 'logs', 'training.jsonl')` に、日時（JST）、機能、入力ファイル名、行数、kernel、fit_method、保存先、検証結果、PredictorNames、ResponseName、終了状態、処理時間を追記します。学習したモデルごとに1行、保存時にも1行を記録します。X・y の値はログに記録しません。ログ保存失敗は画面へ通知します。

ユーザー設定は `fullfile(prefdir, 'StandaloneAnalysisApp', 'settings.json')` に保存し、モデルMATには追加しません。測定データを外部サービスへ送信するコードはありません。

## 現行モデルとの比較

現行アドインを使える環境で旧・新モデルを用意し、MATLAB R2025b で実行します。

```matlab
setup_paths;
comparison = compare_models('old.mat', 'new.mat', Xcheck);
```

`Xcheck` はモデルへの最終入力順の数値行列です。APCは4列、Swing Curveは選択したモデルの説明変数数と順序、面内は X・Y・半径の3列、汎用は元の P 列にしてください。列名、行数などの比較表、予測差の最大値、`isequal` の結果を表示します。旧モデルと新モデルの予測が一致したことを、開発側で推測して扱いません。

## ファイルと確認状況

- `app/`: 画面。`AnalysisController.m`（全体）、`ModelingPage.m`（学習）、`ModelUsePage.m`（推定・SHAP）、`FurnacePage.m`、`DesignPage.m`、`WordCloudPage.m`、`SettingsPage.m`、`HomePage.m`、`HelpPage.m` と、共通部品（`AppPage.m`、`DataSourceControl.m`、`ColumnMapper.m`、`ResultPanel.m`、`ModelStore.m`）。
- `core/`: 学習、保存・検証、推定、SHAP、統計、入力読込、ログ。ファイル選択・保存ダイアログや figure を呼びません。
- `tests/`: 単体テスト（原仕様の T-01〜T-10 を含む）と、全機能の通し確認 `run_app_flow_check.m`。
- `run_tests.m`: R2025b で全テストを実行。
- `check_sources.m`: 静的解析。R2025b での実行確認の代わりにはなりません。
- `check_model_contract.m`: 原仕様のコードブロックと4種類の学習本体・保存本体を比較。空行と字下げ以外の変更を検出します。
- `build_windows.m`: 全テスト成功後に Windows アプリを作成。
- [検証記録](verification.md)、[残課題](issues.md)、[原仕様](docs/specification.md)、[更新仕様](docs/ui-update.md)。

## 公式仕様

- [fitrgp](https://www.mathworks.com/help/stats/fitrgp.html)
- [RegressionGP](https://www.mathworks.com/help/stats/regressiongp.html)
- [shapley](https://www.mathworks.com/help/stats/shapley.html) — 指定の `Shapley.Value` と `NumObservationsToSample` は R2024b 以降の API。
- [App Designer](https://www.mathworks.com/help/matlab/ref/appdesigner.html)
- [MATLAB 関数で構築した画面を MLAPP から呼び出す方法](https://www.mathworks.com/matlabcentral/answers/1607210-how-can-i-convert-a-gui-that-i-programmatically-create-using-a-matlab-file-to-a-mlapp-file)
- [Windows アプリのビルド](https://www.mathworks.com/help/compiler/compiler.build.standalonewindowsapplication.html)
- [スタンドアローンアプリの配布と OS の制約](https://www.mathworks.com/help/compiler/standalone-application-target.html)

## 評価用サンプル

[samples/ProcessInsight_Samples.xlsx](samples/ProcessInsight_Samples.xlsx)に、使い方とAPC、Swing Curveの2モード、汎用回帰、推定・SHAP、複数Runの炉内補間、拡張計画、単語の9シートを用意しています。すべて合成データです。データシートのヘッダー行は1です。学習画面と炉内補間の「サンプルデータを開く」から直接開けます（通常版はサンプルを同梱しないため、別に配った `samples/separate/standard` のブックを選びます）。[サンプルの使い方](samples/README.md)を参照してください。

## 開発・レビュー用の文書

[ウォーターフォール開発文書の一覧](docs/waterfall/index.html)に、要件定義・設計・テスト・運用保守など9点をまとめています。全書に2026-11-23付の新規作成履歴、2026-11-25付の改定履歴と、係長の確認・課長の承認の記録欄があります。改定履歴の行はHTML上で追加・編集できます。記録欄は未記入です。

[文書一式のZIP](docs/ProcessInsightTool_Waterfall_Documents_v1.1.zip)をダウンロードして新しいフォルダに展開し、`index.html`をPCのEdge / Chromeで開いてください。HTML上で記入した記録は「記入済みHTMLを保存」または印刷で保持できます。画像はアプリ内部だけの操作参考で、Windows R2025bの実行証跡ではありません。
