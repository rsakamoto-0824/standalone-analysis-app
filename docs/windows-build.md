# Process Insight Tool — Windows R2025b での確認・ビルド

この文書は、作成済みの MATLAB ソースを会社の Windows PC 等へ移し、MATLAB R2025b で確認・配布するための手順です。会社側で Codex / Claude Code を使う必要はありません。GitHub Copilot の利用も不要です。同じ内容を読みやすくまとめた [ビルド手順書（HTML）](user-guide/build-guide.html) と、利用者へ渡す [利用手順書（配布版・Windows）](user-guide/user-manual.html) もあります。Pro版だけの機能の使い方は [ビルド・利用手順書（詳細）](user-guide/procedure-guide.html) を参照してください。

## 1. 環境を確認する

Windows 64bit の MATLAB R2025b で次を実行してください。

```matlab
version('-release')             % '2025b'
computer('arch')                % 'win64'
ver                            % Statistics and Machine Learning Toolbox と MATLAB Compiler
```

フォルダ一式を作業用の書込み可能な場所に置き、`StandaloneAnalysisApp` を現在のフォルダにします。会社のデータを外部サービスへアップロードしないでください。

## 2. ソースから起動する

```matlab
setup_paths;
controller = launch_analysis_app;          % 通常版
% controller = launch_analysis_app('pro'); % Pro版の画面を確認する場合
```

ホーム画面と、左のメニュー（ホーム、1 APC 学習 〜 10 Help）が表示されます。R2025b 以外ではリリースエラーで止まります。

## 3. 全機能の通し確認を実行する

```matlab
setup_paths;
addpath('tests');
results = run_app_flow_check;
```

アプリを実際に起動し、同梱サンプル（`samples/ProcessInsight_Samples.xlsx`）で次の22項目を、画面のボタンと同じ入口から順に実行します。数分かかります。設定とログは一時フォルダへ保存するため、利用者の設定は変わりません。

| 項目 | 確認する内容 |
|---|---|
| 起動とホーム画面 | 起動できる |
| APC | 2カーネルを交差検証あり・なしで比較、SHAP、保存、`Train_Model` だけの MAT、保存後検証、後からの SHAP 計算 |
| Swing Curve（下地あり） | 下地の選択、膜厚が最後の説明変数、選択変更の反映 |
| Swing Curve（下地なし・周期カーネル、Pro版の画面） | 周期の探索、探索範囲内の周期、保存後検証 |
| データの傾向 | 単変量の傾向（文字の列・数値の列での色分け）と、Pro版の8種類のグラフ（ヒストグラム・相関・ANOVA・Parallel Coordinates・Parallel Sets・Sankey・PCA・クラスタリング）、PNG保存 |
| 汎用回帰 | GPR・重回帰・PLS・ランダムフォレスト・バギング木の比較、`Regression_Model` と `Train_Model` の保存 |
| Pro版の回帰 | EBM・XGBoost・LightGBM・CatBoost、XGBoost のグリッドサーチ（探索の表・推移のグラフ）、目的変数ごとの順位の並び、EBM の保存 |
| Pro版の GPR | 加法カーネル、質的変数（APC サンプルの Lot）、質的変数とほかの方式の同時選択を止める、保存と水準の保持、Permutation Importance と VIP（PLS） |
| 炉内補間 | 2 Run・6方式、目的変数ごとの RMSE の棒グラフ、`Furnace_Model` の保存 |
| 保存モデルで推定・SHAP | MAT の読込、列の自動割当、評価指標、SHAP の列と依存図、SHAP を外したとき推定だけ |
| 保存モデルで推定・SHAP（起動中のモデル） | 保存していない重回帰のモデルでの SHAP 依存図、質的変数を持つ GPR での推定と SHAP |
| Sobol感度解析（Pro版の画面） | 質的変数の範囲、S1・ST の表とグラフ、範囲の誤りを止める |
| 因果探索（Pro版の画面） | PC アルゴリズムと DirectLiNGAM の辺の表・グラフ・順序 |
| 階層ベイズ（Pro版の画面） | Lot ごとの切片と傾き、R-hat、列の重なりを止める |
| 実験計画 | D最適・I最適・直交表・拡張（Pro版の画面）、評価指標（D効率など）と予測分散の分布、乱数seedの説明がない |
| ワードクラウド（Pro版の画面） | 単語の集計と図、形と色の反映 |
| 設定 | テーマ・Fit method・文字の大きさの変更で学習結果が消えない、文字の大きさがすぐ全画面に反映される |
| Help | 表示できる |
| 通常版の画面 | swingperiodic・周期の探索範囲・拡張計画・Pro版のグラフ・Pro版の回帰方式・加法カーネル・質的変数・Sobol・因果探索・階層ベイズ・ワードクラウドが出ない、設定が「7 設定」、Help に Pro 版だけの説明がない（Pro版では出る） |
| 細かい操作 | 説明変数の並べ替え、表・図の書出し、ヘッダー行を指定した CSV |
| 結果の表示と出力 | 横並びの散布図、SHAP依存図の色の変数、予測・SHAPの1ファイル出力（CSV は BOM 付き）、基準周期の表示 |
| 入力の誤り（実行時の自動確認） | 目的変数の重なり・未選択・下地なし・列の重複・WaferId の未選択を、実行時に説明つきで止める（学習しない） |

**22項目すべて成功（Passed が true）であること**を確認し、結果を `verification.md` に記録してください。R2025b では SHAP も実際の `shapley` で計算します。失敗した項目は Note の内容を記録します。

## 4. 単体テストを実行する

```matlab
results = run_tests;
```

失敗・未完了が0件であることを確認し、結果を記録します。`check_sources` による静的解析も併用できます。実データではなく、テスト内で生成する人工データを使用します。

テストは原仕様の T-01〜T-10 を含みますが、現行モデルとの互換性を自動的に保証するものではありません。次の比較も実施します。

```matlab
comparison = compare_models('old.mat', 'new.mat', Xcheck);
```

`Xcheck` は README の最終入力順で用意してください。差分がある場合は、旧・新の学習条件やデータの一致を確認します。乱数を使う学習方式は仕様どおり seed を固定していません。

## 5. インストーラーを作成する（MATLAB Runtime 同梱）

配布先のクライアント PC には MATLAB がない前提です。`build_windows` は exe を作ったあと、**MATLAB Runtime を同梱したインストーラー**を作ります（`compiler.package.installer` の `RuntimeDelivery` を `"installer"`）。利用者はインストーラーを1つ実行するだけで、アプリと MATLAB Runtime が入ります。MATLAB 本体とインストール時のインターネット接続は不要です。

最初に1回、ビルドする PC に、使っている MATLAB と同じ更新版の MATLAB Runtime インストーラーを用意します。

```matlab
compiler.runtime.download   % インターネットに接続できる場合
```

接続できない場合は、このコマンドが表示する URL から別の PC でダウンロードして持ち込み、MATLAB の［設定］→［MATLAB Compiler］で場所を指定します。

```matlab
standard = build_windows('standard'); % 通常版（配布版）
pro = build_windows('pro');           % Pro版
```

| 出力 | 内容 |
|---|---|
| `build/windows/<版>/installer/ProcessInsightTool_Installer.exe`（Pro版は `ProcessInsightToolPro_Installer.exe`） | **配布するもの**。MATLAB Runtime を同梱。サンプルと手順書もアプリと一緒にインストールされる |
| `build/windows/<版>/application/` | exe 本体と付随ファイル、`samples`、`docs/user-guide`（Runtime を別に入れて ZIP で配る場合に使う） |
| `build/windows/<版>/edition-manifest.json` | 版（Edition）、Pro 専用ファイル（ProFiles）、バージョン、インストーラーの有無 |

**入口は `app/launch_analysis_app.m` で、App Designer での手作業は不要です。** 画面タイトルは通常版が「Process Insight Tool」、Pro版が「Process Insight Tool Pro」です。exe に同梱するのは `core/`、`app/`、サンプル、利用者向けの手順書（`docs/user-guide`、生成用の `_src` を除く）だけで、動画などの大きなファイルは含めません。インストーラーを作らず exe だけを作るときは `build_windows('standard', false)` とします。

通常版は Pro 専用の SHAP カーブ近似・残差診断の7ファイルを隔離ソースから除外してコンパイルし、Swing Curve の周期カーネル（swingperiodic）と周期の探索範囲、実験計画の拡張（既存の計画への追加）の画面も表示しません。Help も版ごとの内容で、通常版には Pro 版だけの説明を出しません。通常版の exe とインストーラーに入れる手順書は、利用者向けの `user-manual.html` とその画像だけです。Pro版にはそれらを含めます。実行時の設定や引数で版を変更する機能はありません。

画像なしの詳しい手順は [ビルド手順書（HTML）](user-guide/build-guide.html) を参照してください。

### App Designer の入口を使いたい場合（任意）

`app/AnalysisApp.mlapp` がある場合は、そちらを入口としてビルドします。作る場合は、App Designer で空のアプリを作り、private プロパティ `Controller` と、次の `startupFcn` を追加して `app/AnalysisApp.mlapp` として保存します。

```matlab
app.Controller = AnalysisController(app.UIFigure);
```

## 6. MATLAB のない PC で確認する

MATLAB も MATLAB Runtime も入っていない Windows 64bit の PC に、5章のインストーラーでインストールして、以下を実施します（インターネットに接続しない状態で行うと、利用者の環境に近くなります）。配布版では3章の通し確認を実行できないため、手で確認します。

- [ ] 起動してホーム画面と左のメニューが表示される。ウィンドウを閉じるとアプリが終了する。
- [ ] 学習画面の「サンプルデータを開く」で同梱サンプルが開く（開けない場合は、同梱ファイルの配置を確認する）。
- [ ] 「10 Help」から HTML 手順書が開く。
- [ ] インストーラーだけで、アプリと MATLAB Runtime が入る（MATLAB 本体なし）。
- [ ] Excel / CSV のシート・ヘッダー行の指定と、列の割当が動く。確認のボタンはなく、実行時に列の中身が自動で確認され、問題があれば理由を表示して止まる。
- [ ] APC の24行で停止、25〜149行で注意、150行以上で注意なし。
- [ ] 学習3画面の GPR で `Train_Model` だけが保存され、保存後検証がすべて成功する。重回帰・PLS は `Regression_Model`、炉内補間は `Furnace_Model` で保存される。
- [ ] 複数カーネルを交差検証なし（初期状態）と交差検証ありで比べ、条件の比較グラフ、以前の結果を残した再実行、処理の中止、保存のキャンセルを確認する。
- [ ] SHAP とノイズ除去用 SHAP が Runtime でも動き、分布・依存図を表示・PNG 保存・コピーできる。
- [ ] swingperiodic で周期の自動探索、exact / sd / sr / fic、周期と尤度の表示を確認する。制御側の新しい MATLAB セッションで、アプリのソースをパスへ追加せずに `predict` できることも確認する。
- [ ] 炉内補間で Run 分離、項目別の未計測、6方式、GPR の95%予測区間、外挿の破線、MAT 保存を確認する。
- [ ] 面内推定で学習範囲外の行が表で分かり、警告が画面にも残る。
- [ ] D/I最適、2〜5水準の直交表、計画の評価指標、交絡の図と表が動く。Pro版では既存点を保つ拡張計画とワードクラウド（形・色）も動く。
- [ ] 汎用回帰でランダムフォレスト・バギング木を学習・比較・保存（`Regression_Model`）でき、「5 保存モデルで推定」で読み込める。
- [ ] 設定の文字の大きさを変えると、保存してすぐ全画面の文字が変わり、再起動後も保たれる。
- [ ] 設定の保存・再起動後の反映、ライト/ダーク、設定変更で結果が消えないことを確認する。
- [ ] ウィンドウの大きさを変えても操作でき、図が外部ウィンドウへ出ない。
- [ ] ログを追記でき、測定値そのものを含まない。保存先やログ先が書込み不可の場合、エラーを画面で確認できる。
- [ ] 旧・新モデルの `compare_models` を開発用 R2025b 上で実行し、結果を確認済み。

### 版ごとの確認

- [ ] 通常版で SHAP 分布・依存図を使え、レジスト膜厚のカーブ評価・拡張計画は表示されない。Help に Pro 版だけの用語・操作・関数のリンクがなく、手順書のボタンは利用者向けの1つだけ。インストール先の `docs/user-guide` には `user-manual.html` とその画像だけがある。
- [ ] Pro版で三角関数・スプラインを切り替え、極値・区間ごとの山間／谷間の傾き・残差診断を表示できる。「グラフを大きく表示」で広く表示できる。APC 学習には Swing Curve 評価が付かない。

実行した OS、MATLAB / Runtime の更新版、成功・失敗件数、結果を `verification.md` に追記してください。ここまで確認するまでは配布検証完了として扱いません。

## 開発用：R2025b 以外で画面を確認する

製品は R2025b 以外で起動しません。開発時に限り、MATLAB を起動する前に環境変数 `PROCESS_INSIGHT_DEV_RELEASE=allow` を設定すると、別のリリースでも起動・テストできます（配布版では無効）。このときウィンドウの題名に「検証用」と表示します。**この状態で保存したモデルは制御に使用しないでください。** SHAP の複数行計算は R2025b 専用のため、通し確認は SHAP だけ代替計算へ差し替えます。
