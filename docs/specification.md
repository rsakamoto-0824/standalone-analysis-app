# 指示プロンプト: MATLABスタンドアローン解析アプリの開発

 

このプロンプトは、解析機能を、スタンドアローンアプリとして作るための指示である。

 

---

 

## 1. 役割と目的

 

- あなたは MATLAB アプリ開発者として、このプロンプトの仕様どおりにアプリを実装する。

- 最重要要件は、学習済みモデルのMATファイルを現行と完全に同じ構造で保存することである。制御（APC）システムがこのファイルをそのまま読み込むため、変数名・説明変数の名前・並び順が1文字でも変わると制御が誤動作する。

 

## 2. 前提と制約

 

| 項目 | 内容 |

|---|---|

| 言語 | MATLAB のみ。Python・C# などは使わない（`RegressionGP` オブジェクトを生成できないため） |

| リリース | MATLAB R2025b（制御側との互換性のため変更しない） |

| 画面 | App Designer（`.mlapp`） |

| 配布形式 | MATLAB Compiler によるスタンドアローン実行ファイル（Windows 64bit、MATLAB Runtime R2025b） |

| 必須ツールボックス | Statistics and Machine Learning Toolbox（`fitrgp`、`shapley`、`cordexch` を使用） |

| 通信 | 外部サービスへデータを送信しない |

| 認証情報 | ソースコード・ログに書かない |

 

### 作業の進め方

 

1. 不明点や仕様の矛盾を見つけたら、実装を止めて質問する。推測で埋めない。

2. 「12. 未確定事項」に暫定方針がある項目は、暫定方針で実装し、コード中に `% TODO(要確認 Q-xx)` を1行で残す。

 

---

 

## 3. 推奨フォルダ構成

 

```

StandaloneAnalysisApp/

├─ app/

│   └─ AnalysisApp.mlapp        % 画面（入力受付・結果表示・ファイル操作だけを担当）

├─ core/                        % 計算関数（画面に依存しない）

│   ├─ model_constants.m        % 列名・閾値・有効値などの定数を1か所で定義

│   ├─ train_apc_model.m

│   ├─ train_swing_curve_model.m

│   ├─ train_in_plane_model.m

│   ├─ train_generic_gpr_model.m

│   ├─ save_train_model.m

│   ├─ verify_saved_model.m

│   ├─ ... （その他の計算関数）

├─ tests/                       % matlab.unittest による単体テスト

└─ README.md                    % 目的・実行方法・注意事項

```

 

- 計算関数（`core/`）の中で `uiputfile`、`uigetfile`、`msgbox`、`figure` を呼ばない。ダイアログ表示とグラフ描画は画面側で行う。

- 警告は戻り値（例: `warnings` の文字列配列）で画面へ返す。

- エラーは `error('識別子:種別', 'メッセージ')` で投げ、画面側で `uialert` に表示する。

 

---

 

## 4. 【最重要】学習済みモデル保存仕様

 

### 4.1 変更禁止のルール

 

| ID | ルール |

|---|---|

| MR-01 | MATファイルに保存する変数は `Train_Model` の1つだけとする。大文字・小文字・アンダースコアを変えない。他の変数を追加しない |

| MR-02 | `Train_Model` は `fitrgp` の戻り値（`RegressionGP`）をそのまま保存する。`compact` で変換しない |

| MR-03 | 説明変数の名前と並び順は「4.2 モデル種別ごとの定義」に固定する |

| MR-04 | `fitrgp` に `ResponseName` を指定しない（現行は未指定で、MATLAB 既定値になっている） |

| MR-05 | `fitrgp` の名前・値引数は「4.3 正本コード」と同じものだけを指定する。追加・削除しない |

| MR-06 | `save` に形式オプション（`-v7.3` など）を付けない |

| MR-07 | 説明変数の単位変換・事前標準化をしない（標準化は `'Standardize', true` でモデル内部が行う） |

| MR-08 | 入力データの列は列名で割り当て、学習直前に 4.2 の順序へ並べ替える。必須列の不足・重複がある場合は学習を中止する |

| MR-09 | 保存後にファイルを再読込し「4.4 保存後の自動検証」を行う。不一致があれば「このモデルを制御に使用しないでください」と表示する |

 

### 4.2 モデル種別ごとの定義

 

| モデル種別 | 学習時の入力型 | 説明変数の列順（PredictorNames） | 前処理 |

|---|---|---|---|

| 露光APCウェーハモデル | table | 1: `SIN_TH` / 2: `SIN_RN` / 3: `NSG_TH` / 4: `RESIST_TH` | なし |

| Swing Curveモデル | table | 1: `SIN_TH` / 2: `SIN_RN` / 3: `NSG_TH` / 4: `RESIST_TH` | なし |

| 面内推定モデル | 数値行列（列名なし） | 1: X座標 / 2: Y座標 / 3: 半径 | 半径列を追加 |

| 汎用GPRモデル | 数値行列（列名なし） | 入力列の順（1〜P列） | なし |

 

- 面内推定モデルと汎用GPRモデルには列名を付けない。名前を付けると `PredictorNames` が変わり、現行モデルと互換性がなくなる。

- 列名を持たないモデルは、列位置だけで対応が決まる。画面の列割当で順序を必ず利用者に確認させる。

 

### 4.3 正本コード

 

以下のコードは、現行の学習・保存処理である。変数名・記述順・引数の順序をこのとおりに実装する。

関数を分割する場合も、学習処理の本体はこのコードの行をそのまま使う。

 

#### 露光APCウェーハモデル

 

```matlab

X_table = array2table(X);

X_table.Properties.VariableNames = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'};

y_col = double(y(:));

 

Train_Model = fitrgp(X_table,y_col,"FitMethod",fit_method, ...

    "KernelFunction",kernel,"Standardize",true,"BasisFunction",'constant');

```

 

- `X` は N×4 の数値行列で、列順は SIN_TH, SIN_RN, NSG_TH, RESIST_TH。

- `y` は N×1 の数値ベクトル。

 

#### Swing Curveモデル

 

```matlab

X_table = array2table(X);

RESIST_TH_col = array2table(RESIST_TH);

y_col = double(y(:));

 

X_all = [X_table, RESIST_TH_col];

X_all.Properties.VariableNames = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'};

 

Train_Model = fitrgp(X_all, y_col(:), ...

    'KernelFunction', kernel, ...

    'FitMethod',      fit_method, ...

    'Standardize',    true);

```

 

- `X` は N×3 の数値行列（SIN_TH, SIN_RN, NSG_TH）。`RESIST_TH` は N×1 の数値ベクトルで、必ず4列目になる。

- APCモデルと異なり `BasisFunction` を指定しない。既定値は `'constant'` で結果は同じになる想定だが、記述は現行どおり残す。

 

#### 面内推定モデル

 

```matlab

radius = sqrt(X(:,1).^2 + X(:,2).^2);

X_aug  = [X, radius];

 

Train_Model = fitrgp(X_aug, y(:), ...

    'KernelFunction', kernel, ...

    'FitMethod',      fit_method, ...

    'Standardize',    true);

```

 

- `X` は N×2 の数値行列（列1: X座標、列2: Y座標）。

 

#### 汎用GPRモデル

 

```matlab

Train_Model = fitrgp(X, y(:), ...

    'KernelFunction', kernel, ...

    'FitMethod',      fit_method, ...

    'Standardize',    true);

```

 

- `X` は N×P の数値行列。

 

#### 保存処理（全モデル共通）

 

```matlab

function save_train_model(Train_Model, fullName)

    % 制御側が変数名 Train_Model で読み込むため、ローカル変数名を変えないこと

    save(fullName, "Train_Model");

end

```

 

- `save` は呼び出し元ワークスペースの変数名で保存する。保存関数の中で変数名が `Train_Model` であることを必ず守る。

 

#### 学習パラメータ

 

| パラメータ | 既定値 | 有効値 |

|---|---|---|

| `kernel` | `'squaredexponential'` | `'squaredexponential'`, `'matern32'`, `'matern52'`, `'exponential'`, `'rationalquadratic'`, `'ardmatern52'`, `'ardsquaredexponential'` |

| `fit_method` | `'exact'` | `'exact'`, `'sd'`, `'sr'`, `'fic'` |

 

- 有効値は `model_constants.m` に1か所で定義し、全モデルで共通に使う。

- 有効値の判定は大文字・小文字を区別しない（現行は `strcmpi`）。`fitrgp` には利用者が選んだ文字列をそのまま渡す。

 

### 4.4 保存後の自動検証

 

`verify_saved_model(fullName, Train_Model_before, model_type)` を作り、保存直後に実行する。

 

| No. | 検証項目 | 期待値 |

|---|---|---|

| 1 | `whos('-file', fullName)` の変数名一覧 | `{'Train_Model'}` の1件のみ |

| 2 | `class(S.Train_Model)` | `'RegressionGP'` |

| 3 | `S.Train_Model.PredictorNames` | table 型モデルは `{'SIN_TH','SIN_RN','NSG_TH','RESIST_TH'}`。行列型モデルは保存前のモデルと一致 |

| 4 | `S.Train_Model.ResponseName` | 保存前のモデルと一致。値はログに記録する |

| 5 | `KernelFunction`、`FitMethod`、`BasisFunction` | 画面で選んだ値と一致 |

| 6 | `NumObservations` | 学習に使った行数と一致 |

| 7 | 学習データに対する `predict` の結果 | 保存前のモデルの結果と完全一致（`isequal`） |

 

`S` は `S = load(fullName, "Train_Model");` で読み込んだ構造体である。

 

---

 

## 5. 機能仕様

 

各機能の計算は現行と同じ結果を返すこと。エラーメッセージの日本語文は、指定がある場合はそのまま使う。

 

### 5.1 露光APCウェーハモデル学習

 

**入力**

 

| 名前 | 型 | 既定値 |

|---|---|---|

| X | N×4 数値（SIN_TH, SIN_RN, NSG_TH, RESIST_TH） | 必須 |

| y | N×1 数値 | 必須 |

| IsPlot | 0 または 1 | 0 |

| kernel | 文字列 | `'squaredexponential'` |

| fit_method | 文字列 | `'exact'` |

 

**処理手順**

 

1. 入力チェック

   - X が数値でない → エラー「X は数値行列で渡してください。」

   - X の列数が4でない → エラー「X の列数は 4 である必要があります（現在: %d）。」

   - X の行数が0 → エラー「X にデータが含まれていません。」

   - y が数値でない、または空 → エラー「y は空でない数値ベクトルで渡してください。」

   - y の要素数と X の行数が異なる → エラー「y の要素数 (%d) が X の行数 (%d) と一致しません。」

   - kernel・fit_method が有効値でない → エラー（有効値を一覧表示）

   - 行数が25未満 → エラー「データが少ないため処理を中止します」

2. 4.3 の正本コードで学習する。

3. 行数が150未満なら警告「データが少ないためモデルの扱いに注意してください」を返す。

4. 画面側で保存先を選ばせ、`save_train_model` で保存し、`verify_saved_model` で検証する。保存をキャンセルした場合は、保存せず処理を終える（SHAP算出も行わない）。

5. SHAP値を算出する（5.6 の `compute_shap_values` を使用）。

   - 対象は先頭から最大1000行（`MAX_SHAP_POINTS = 1000`）。ランダム抽出しない。

   - 1000行を超える場合は「SHAP 計算データを先頭 1000 件に制限します（全 %d 件）。」を表示する。

6. 出力 `shap_all`（N'×4、N' = min(N, 1000)）を表に表示し、CSV／Excel に出力できるようにする。

7. IsPlot = 1 のとき、5.6 のグラフを描画する。

 

**定数**: 25、150、1000 は `model_constants.m` に名前付きで定義する（例: `MIN_TRAIN_ROWS`、`CAUTION_TRAIN_ROWS`、`MAX_SHAP_POINTS`）。

 

### 5.2 Swing Curveモデル学習

 

**入力**: X（N×3 数値: SIN_TH, SIN_RN, NSG_TH）、RESIST_TH（N×1 数値）、y（N×1 数値）、kernel、fit_method

 

**処理手順**

 

1. 入力チェック

   - RESIST_TH が数値でない、または空 → エラー「RESIST_TH は空でない数値ベクトルで渡してください。」

   - RESIST_TH が1列でない → エラー「RESIST_TH は列ベクトル [N x 1] で渡してください。現在のサイズ: [%d x %d]」

   - y が数値でない、または空 → エラー「y は空でない数値ベクトルで渡してください。」

   - y と RESIST_TH の要素数が異なる → エラー「y の要素数 (%d) が RESIST_TH の行数 (%d) と一致しません。」

   - X が空 → エラー「第一引数は空でない数値を渡してください。」

   - X と RESIST_TH の行数が異なる → エラー「X の行数 (%d) が RESIST_TH の行数 (%d) と一致しません。」

   - X が3列でない → エラー「X は3列（SIN_TH, SIN_RN, NSG_TH）で渡してください。」（新規追加）

   - kernel・fit_method が有効値でない → エラー

2. 4.3 の正本コードで学習する。

3. 保存・検証する。出力値はない。

 

- このモデルには行数の下限チェック（25行）と150行警告がない。現行どおり追加しない。

 

### 5.3 面内推定（学習＋推定）

 

**入力**: X_train（N×2: X座標, Y座標）、y_train（N×1）、X_test（M×2、省略可）、kernel、fit_method

 

**処理手順**

 

1. 入力チェック

   - X_train が2列でない → エラー「第一引数（学習データの座標情報） は2列（X座標, Y座標）としてください。」

   - X_train の行数と y_train の要素数が異なる → エラー「第一引数（学習データの座標情報）の行数 と 第二引数（目的変数） の行数が一致しません。」

   - X_test が指定され、2列でない → エラー「第三引数（推定対象座標） は2列（X座標, Y座標）としてください。」

   - kernel・fit_method が有効値でない → エラー

2. 4.3 の正本コード（半径列の追加を含む）で学習する。

3. 保存・検証する。保存をキャンセルした場合は、推定を行わず処理を終える（現行どおり）。

4. X_test がある場合

   1. X_test にも半径列を追加する（`X_test_aug`）。

   2. 外挿判定（下記）で範囲外があれば、警告「警告：推定対象座標に学習データの範囲外が含まれます」を返す。

   3. `y_pred = predict(Train_Model, X_test_aug);` で推定する。

5. 出力 `y_pred`（M×1）を表示・出力する。X_test がない場合は空。

 

**外挿判定**（列ごとの最小・最大の範囲チェック）

 

```matlab

function isExtrapolation = isExtrapolationDetected(Xtrain, Xtest)

    minTrain = min(Xtrain, [], 1);

    maxTrain = max(Xtrain, [], 1);

    isBelow = Xtest < minTrain;

    isAbove = Xtest > maxTrain;

    isExtrapolation = any(isBelow(:) | isAbove(:));

end

```

 

- 判定には半径列を追加した後の行列（`X_train_aug`、`X_test_aug`）を使う。

- 画面では、範囲外を含む行を識別できるように表示する（行ごとの判定 `any(isBelow | isAbove, 2)` を追加で返してよい）。

 

### 5.4 汎用GPRモデル学習

 

- 入力: X（N×P 数値）、y（N×1 数値）、kernel、fit_method。

- 4.3 の正本コードで学習し、保存・検証する。出力値はない。

 

### 5.5 推定（保存済みモデルの読込）

 

#### 汎用推定（APC・Swing Curve・汎用GPRモデル用）

 

1. 利用者がMATファイルを選ぶ。キャンセルした場合は「学習済モデルの選択がキャンセルされました」を表示して終える。

2. `S = load(fullName, "Train_Model");` で読み込む。`Train_Model` がない場合はエラー「学習済みモデル（Train_Model）が見つかりません」。

3. 画面に `Train_Model.PredictorNames` を表示し、入力列との対応を利用者に確認させる。

4. 入力列数と `numel(Train_Model.PredictorNames)` が異なる場合はエラーとする。

5. `istable(Train_Model.X)` が真（table で学習したモデル）の場合は、入力を `array2table` し、`VariableNames` に `Train_Model.PredictorNames` を設定してから `predict` に渡す。偽の場合は数値行列のまま渡す。

6. `y_pred = predict(Train_Model, Xnew);`

 

#### 面内推定モデルでの推定

 

1. 入力 X が2列でない → エラー「推定対象データは2列（X座標, Y座標）としてください。」

2. 半径列を追加する（4.3 と同じ計算）。

3. 汎用推定の手順1〜2でモデルを読み込み、`predict` する。

 

### 5.6 SHAP解析

 

#### SHAP値の算出（共通関数）

 

```matlab

function [shap_obj, shap_all] = compute_shap_values(Train_Model, X_for_shap)

    if ~license('test', 'Statistics_Toolbox')

        error('compute_shap_values:noToolbox', ...

            'SHAP 算出には Statistics and Machine Learning Toolbox が必要です。');

    end

    try

        shap_obj = shapley(Train_Model,"NumObservationsToSample","all","QueryPoints",X_for_shap);

        shap_tmpValue = shap_obj.Shapley;

        shap_all = shap_tmpValue.Value';

    catch err

        error('compute_shap_values:shapleyFailed', ...

            'SHAP 値の算出に失敗しました。\n詳細: %s', err.message);

    end

end

```

 

- `shap_all` は「行 = 対象データ、列 = 説明変数」の行列である。

 

#### グラフ（IsPlot = 1 のとき）

 

1. 重要度 `importance = mean(abs(shap_all), 1)` を求め、降順に並べた変数名 `sorted_names` を作る。変数名は `Train_Model.PredictorNames` を使う。

2. `swarmchart(shap_obj)` を1枚描く。

3. 重要度の高い順に、各変数 i について依存散布図を1枚ずつ描く。

   - 色に使う変数: 自身を除いた中で最も重要な変数（i = 1 のときは2位、それ以外は1位）。

 

```matlab

for i = 1:N_FACTORS

    feat_name   = sorted_names{i};

    other_ranks = setdiff(1:N_FACTORS, i);

    color_name  = sorted_names{other_ranks(1)};

    plotDependence(shap_obj, feat_name, "ColorPredictor", color_name);

end

```

 

- アプリでは各グラフを `uiaxes` またはタブ内に表示し、PNG で保存できるようにする。`swarmchart`・`plotDependence` が `uiaxes` に描画できない場合は、別ウィンドウ（`figure`）で表示してよい。

 

#### Swing Curveのノイズ除去用 SHAP（現行 `denoise_for_swing_curve`）

 

1. 保存済みモデルを選び、`Train_Model` を読み込む（5.5 の手順1〜2）。

2. 入力 X_for_shap（N×3）と RESIST_for_shap（N×1）を結合し、列名を `{'SIN_TH','SIN_RN','NSG_TH','RESIST_TH'}` にした table を作る。

3. `shap_obj = shapley(Train_Model,"QueryPoints", all_X_for_shap);` で算出する。

   - 現行は `NumObservationsToSample` を指定していない。暫定でこのまま実装する（Q-08）。

4. `shap_all = shap_obj.Shapley.Value';` の最終列（RESIST_TH）を `shap_resist`（N×1）として出力する。

 

#### 別データでのSHAP依存確認（現行 `calc_shap_dependence`）

 

現行コードは不具合で動作しないため、次の仕様で新たに実装する。

 

1. 保存済みモデルを選び、`Train_Model` を読み込む（5.5 の手順1〜2）。

2. 入力 X を、5.5 の手順5と同じ方法でモデルに合わせた形式にする。

3. `compute_shap_values` で `shap_all` を求めて出力する。

4. IsPlot = 1 のとき、上記のグラフを描画する（`N_FACTORS` は説明変数の数）。

 

### 5.7 評価指標

 

全関数で、入力は列ベクトルに変換（`x(:)`）してから計算する。

 

| 関数 | 入力 | チェック | 計算式 |

|---|---|---|---|

| `calc_rmse` | y_true, y_pred | 要素数一致、1点以上 | `sqrt(mean((y_true - y_pred).^2))` |

| `calc_rmspe` | y_true, y_pred | 要素数一致、1点以上、y_true に0なし | `sqrt(mean(((y_true - y_pred) ./ y_true).^2)) * 100` |

| `calc_mae` | y_true, y_pred | 要素数一致、1点以上 | `mean(abs(y_true - y_pred))` |

| `calc_pearson` | x, y | 要素数一致、2点以上 | `C = corrcoef(x, y); r = C(1,2);` |

| `calc_r_squared` | y_true, y_pred | 要素数一致、2点以上 | `C = corrcoef(y_true, y_pred); r2 = C(1,2)^2;` |

 

- `calc_r_squared` は `1 - SS_res/SS_tot` ではなく、相関係数の2乗を返す（現行の意図的な仕様）。画面の表示名は「r²（相関係数の2乗）」とする。

 

#### 一括算出 `calc_all_metrics(col1, col2)`

 

- チェック: 要素数一致（エラー「col1 と col2 の要素数が一致しません。(%d vs %d)」）、2点以上（エラー「データは2点以上必要です。」）。

- 出力: 次の順の4行×2列（名前, 値）。

 

| 行 | 名前 | 値 |

|---|---|---|

| 1 | `rmse` | `calc_rmse(col1, col2)` |

| 2 | `mae` | `calc_mae(col1, col2)` |

| 3 | `r` | `calc_pearson(col1, col2)` |

| 4 | `r_squared` | `calc_r_squared(col1, col2)` |

 

- RMSPE、KLダイバージェンス、相互情報量は一括算出に含めない（個別機能としては提供する）。

 

#### KLダイバージェンス `calc_kl_divergence(p_data, q_data, n_bins)`

 

```matlab

if nargin < 3 || isempty(n_bins)

    n_bins = max(ceil(log2(numel(p_data)) + 1), 10);

end

% チェック: p_data・q_data は各2点以上、n_bins は2以上、

%           両データがすべて同じ値ならエラー「全データが同一値のためビン分割できません。」

p_data = p_data(:);

q_data = q_data(:);

all_data = [p_data; q_data];

edges = linspace(min(all_data), max(all_data), n_bins + 1);

p_counts = histcounts(p_data, edges)' + 1;

q_counts = histcounts(q_data, edges)' + 1;

p_dist = p_counts / sum(p_counts);

q_dist = q_counts / sum(q_counts);

kl = sum(p_dist .* log(p_dist ./ q_dist));   % 単位: nats

```

 

#### 相互情報量 `calc_mutual_information(x, y, n_bins)`

 

```matlab

if nargin < 3 || isempty(n_bins)

    n_bins = max(ceil(log2(numel(x)) + 1), 10);

end

% チェック: 要素数一致、2点以上、n_bins は2以上

x = x(:);

y = y(:);

edges_x = linspace(min(x), max(x), n_bins + 1);

edges_y = linspace(min(y), max(y), n_bins + 1);

joint_counts = histcounts2(x, y, edges_x, edges_y) + 1;

joint_prob = joint_counts / sum(joint_counts(:));

p_x = sum(joint_prob, 2);

p_y = sum(joint_prob, 1);

eps_val = 1e-12;

h_x  = -sum(p_x(p_x > eps_val) .* log2(p_x(p_x > eps_val)));

h_y  = -sum(p_y(p_y > eps_val) .* log2(p_y(p_y > eps_val)));

joint_flat = joint_prob(joint_prob > eps_val);

h_xy = -sum(joint_flat .* log2(joint_flat));

mi = max(h_x + h_y - h_xy, 0);   % 単位: bits

```

 

### 5.8 列の要約統計量 `calc_column_summary(data)`

 

1. チェック: 数値でない → エラー「data は数値配列で渡してください。」、空 → エラー「data が空です。」

2. `data = data(:);` `n_missing = sum(isnan(data));`

3. 欠損値は除外する（`data_clean = data(~isnan(data));`）。

4. 有効データが2件未満 → エラー「有効なデータが %d 件しかありません。算出には2件以上必要です。」

5. `q = quantile(data_clean, [0.25, 0.75]);`

6. 出力: 次の順の11行×2列（名前, 値）。

 

| 行 | 名前 | 値 |

|---|---|---|

| 1 | `n` | `numel(data_clean)` |

| 2 | `n_missing` | `n_missing` |

| 3 | `mean` | `mean(data_clean)` |

| 4 | `median` | `median(data_clean)` |

| 5 | `max` | `max(data_clean)` |

| 6 | `min` | `min(data_clean)` |

| 7 | `range` | `max(data_clean) - min(data_clean)` |

| 8 | `iqr` | `q(2) - q(1)` |

| 9 | `q1` | `q(1)` |

| 10 | `q3` | `q(2)` |

| 11 | `std` | `std(data_clean)`（不偏標準偏差、N−1） |

 

- 画面で複数列を選んだ場合は、列ごとに算出して横並びの表にする。

 

### 5.9 D最適計画 `create_D_DOE(nfactors, nruns, seed)`

 

```matlab

if nargin < 3 || isempty(seed)

    rng('shuffle');

else

    rng(seed);

end

design = cordexch(nfactors, nruns, "quadratic");

```

 

- nfactors・nruns が正の整数でない場合はエラーとする（新規追加）。

- 出力 `design` は nruns×nfactors の計画行列。表示と CSV／Excel 出力に対応する。

 

### 5.10 ワードクラウド `create_wordCloud(text)`

 

1. `text = char(text);`

2. 次の区切り文字で分割する: 半角空白、全角空白、`,`、`、`、`。`、`.`、`!`、`?`、`！`、`？`、改行（`char(10)`、`char(13)`）、タブ（`char(9)`）。

3. 空の要素を除き、`lower` で小文字化する。

4. `[words, ~, ic] = unique(tokens); counts = accumarray(ic, 1);`

5. 1文字以下の単語を除く。単語が残らない場合はエラー「有効な単語が見つかりませんでした。テキストを確認してください。」

6. `wordcloud(words, counts)` で描画し、タイトルを「Word Cloud」（FontSize 14、太字）とする。

- 日本語の自動分かち書きはしない。利用者に空白区切りで入力してもらう旨を画面に表示する。

- 入力はテキストボックスへの直接入力とテキストファイル読込の両方に対応する。

 

---

 

## 6. 画面要件

 

| ID | 要件 |

|---|---|

| UI-01 | 機能（5.1〜5.10）をタブで並べる |

| UI-02 | 入力データは Excel（`.xlsx`）と CSV から読み込む。シートとヘッダー行を指定できる |

| UI-03 | 読み込んだ列を、機能ごとの必須変数へ割り当てる。列名が必須変数名（例: `SIN_TH`）と一致する場合は自動で割り当てる |

| UI-04 | 学習の実行前に「列名 → 説明変数（順番）」の対応表を表示し、利用者が確認ボタンを押すまで学習しない |

| UI-05 | kernel・fit_method はドロップダウンで選ぶ。選択肢は 4.3 の有効値だけにする |

| UI-06 | 結果は表で表示し、CSV／Excel に出力できる。グラフは PNG で保存できる |

| UI-07 | 警告（150行未満、外挿あり、SHAP件数制限）は、ダイアログに加えて結果画面にも残す |

| UI-08 | SHAP算出中は処理中表示（`uiprogressdlg`）を出す |

| UI-09 | 保存後の自動検証結果（4.4）を画面に表示する |

 

---

 

## 7. ログ

 

- 学習ごとに、日時、機能名、入力ファイル名、行数、kernel、fit_method、保存先、4.4 の検証結果、`PredictorNames`、`ResponseName` をログファイルに追記する。

- 計測値そのもの（X・y の値）はログに書かない。

 

---

 

## 8. テスト要件

 

`tests/` に `matlab.unittest` のテストを作る。テスト名は「条件_期待結果」が分かる名前にする。

 

| ID | 内容 |

|---|---|

| T-01 | 各モデル種別で保存したMATファイルの変数が `Train_Model` の1件だけである |

| T-02 | APC・Swing Curveモデルの `PredictorNames` が `{'SIN_TH','SIN_RN','NSG_TH','RESIST_TH'}` と完全一致する |

| T-03 | 入力ファイルの列順を入れ替えても、列名割当後のモデルの `PredictorNames` と予測値が変わらない |

| T-04 | 必須列の不足・重複で学習が中止される |

| T-05 | 保存→再読込したモデルの予測値が保存前と完全一致する（fit_method = `'exact'`） |

| T-06 | 25行未満でエラー、25〜149行で警告、150行以上で警告なし（APC） |

| T-07 | 外挿判定が範囲内で false、範囲外を1点含むと true |

| T-08 | 評価指標・要約統計量が手計算の既知値と一致する（許容差 1e-12） |

| T-09 | `create_D_DOE` で同じ seed を与えると同じ計画行列になる |

| T-10 | 不正な kernel・fit_method でエラーになる |

 

### 現行との互換確認（ユーザーが実施）

 

開発環境では現行アドインを実行できないため、次の比較スクリプトを用意する。ユーザーが現行モデルと新モデルの両方を用意して実行する。

 

- `compare_models(oldMatPath, newMatPath, Xcheck)`: 4.4 の項目1〜6を比較し、`Xcheck` に対する `predict` 結果の差の最大値を表示する。

 

---

 

## 9. 現行の不具合で、新アプリでは修正するもの

 

モデルファイルの内容が変わる修正は行わない。

 

| 対象 | 現行の不具合 | 新アプリでの対応 |

|---|---|---|

| 別データでのSHAP依存確認 | `load` の戻り値（構造体）をモデルとして使っていた。変数 `FEATURE_NAMES` が未定義 | 5.6 の仕様で実装する |

| Swing Curve学習 | X の列数チェックがない。エラー識別子が別関数名 | 列数チェックを追加し、識別子を関数名に合わせる |

| APC学習 | kernel・fit_method の有効値チェックがない | 4.3 の有効値でチェックする |

| 全体 | `uiputfile`・`msgbox` が計算関数の中にある | 画面側へ移す |

 

---

 

## 10. 完了条件

 

1. 5章の全機能が画面から実行できる。

2. 8章のテストがすべて成功する。

3. MATLAB Compiler でスタンドアローン実行ファイルを作成し、MATLAB 本体がない端末（MATLAB Runtime R2025b のみ）で起動できる。

4. `README.md` に目的、実行方法、必要な MATLAB Runtime、モデル保存仕様（4章）の要約、注意事項を書く。

 

## 11. 作業報告の形式

 

作業の区切りごとに、次の項目を報告する。

 

- 変更・作成したファイル

- 実施内容

- テスト結果（成功・失敗の件数と失敗内容）

- 4章の仕様から外れた箇所の有無（ある場合は理由）

- 未確定事項（12章）で暫定方針を採用した箇所

- 残課題

 

---

 

## 12. 未確定事項と暫定方針

 

次の事項はユーザーが確認中である。暫定方針で実装し、コードに `% TODO(要確認 Q-xx)` を残す。

 

| ID | 未確定事項 | 暫定方針 |

|---|---|---|

| Q-01 | 制御側がMATファイルをどう読み込むか。推定時に table と数値行列のどちらを渡すか | 4章の仕様どおり保存する。読込方法に依存する処理は作らない |

| Q-02 | 現行モデルの `ResponseName` と `PredictorNames` の実際の値 | `ResponseName` は指定しない（既定値）。検証では保存前後の一致だけを確認し、値はログに記録する |

| Q-03 | 制御側の MATLAB リリース | R2025b を使う |

| Q-04 | 作成日時やカーネルなどの付帯情報ファイルを作るか | 作らない。MATファイルにも追加しない |

| Q-05 | fit_method が `'sd'`／`'sr'`／`'fic'` のとき乱数シードを固定するか | 固定しない（現行どおり） |

| Q-06 | 面内推定で保存をキャンセルしたとき推定を続けるか | 続けない（現行どおり） |

| Q-07 | 汎用GPR学習を機能として残すか | 残す |

| Q-08 | ノイズ除去用SHAPでも `NumObservationsToSample="all"` を指定するか | 指定しない（現行どおり） |

| Q-09 | 欠損値（NaN、空セル）を含む行がある場合の学習 | 学習を中止し、欠損を含む行番号を表示する。`fitrgp` が欠損行を自動で除外すると `NumObservations` が変わり、制御側で気付けないため |

| Q-10 | 処理時間の目標値 | 目標値は設けず、処理時間をログに記録する |

| Q-11 | 面内推定で半径150 mm以上の点を除外するか | 除外しない（現行どおり） |