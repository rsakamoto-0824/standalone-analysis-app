# Process Insight Tool — Windows R2025b での仕上げ・ビルド

この文書は、作成済みの MATLAB ソースを会社の Windows PC 等へ移し、MATLAB R2025b で検証・配布するための手順です。会社側で Codex / Claude Code を使う必要はありません。GitHub Copilot の利用も不要です。

## 1. 環境を確認する

Windows 64bit の MATLAB R2025b で次を実行してください。

```matlab
version('-release')             % '2025b'
computer('arch')                % 'win64'
ver                            % Statistics and Machine Learning Toolbox と MATLAB Compiler
```

フォルダ一式を作業用の書込み可能な場所に置き、`StandaloneAnalysisApp` を現在のフォルダにします。会社のデータを外部サービスへアップロードしないでください。

## 2. ソースの画面と計算を確認する

```matlab
setup_paths;
controller = launch_analysis_app;
```

左の10個の画面切替で文字がすべて見えること、炉内補間が汎用GPRの直下にあること、Excel / CSV 読込、列の割当・確認、結果書出しを確認します。各学習画面で RMSE・R²・評価表・列要約を確認します。SHAP はアプリ内のグラフ、PNG 保存、「グラフをコピー」からExcelやPowerPointへの画像貼付けを確認します。「9 設定」のKL / MIビン数を変更して全画面の評価に反映すること、Help・画面リサイズも確認します。

## 3. App Designer の入口を作成する

R2025b の `.mlapp` は App Designer で作成します。バイナリ形式を非公開 API で生成する処理は使いません。画面を外部の MATLAB クラスで構築し、薄い `.mlapp` から呼び出す構成です。[MathWorks の案内](https://www.mathworks.com/matlabcentral/answers/1607210-how-can-i-convert-a-gui-that-i-programmatically-create-using-a-matlab-file-to-a-mlapp-file)に沿っています。

1. `appdesigner` を実行し、空のアプリを作ります。UIFigure には手動で部品を配置しません。
2. Code View の「Property」を追加し、private プロパティに `Controller` を作ります。

   ```matlab
   properties (Access = private)
       Controller
   end
   ```

3. `startupFcn` を追加し、本文を次にします。

   ```matlab
   project_root = fileparts(fileparts(mfilename('fullpath')));
   addpath(fullfile(project_root, 'core'), fullfile(project_root, 'app'));
   require_r2025b();
   app.Controller = AnalysisController(app.UIFigure);
   ```

4. `app/AnalysisApp.mlapp` として保存し、Run で10個のタブが開くことを確認します。
5. App Designer の Design View には空の UIFigure が表示されます。タブや表の配置は `AnalysisController.m` で変更します。R2025b で開き直せることを確認してください。

入口を含む全ソースを同じフォルダ構成で保管します。MATLAB R2022b では学習・保存しません。

## 4. 単体テストを実行する

```matlab
results = run_tests;
```

失敗・未完了が0件であることを確認し、結果を記録します。`check_sources` による静的解析も併用できます。実データではなく、テスト内で生成する人工データを使用します。

テストは T-01〜T-10 を含みますが、現行モデルとの互換性を自動的に保証するものではありません。次の比較も実施します。

```matlab
comparison = compare_models('old.mat', 'new.mat', Xcheck);
```

`Xcheck` は README の最終入力順で用意してください。差分がある場合は、旧・新の学習条件やデータの一致を確認します。乱数を使う学習方式は仕様どおり seed を固定していません。

## 5. Windows 実行ファイルを作成する

```matlab
standard = build_windows('standard'); % 通常版
pro = build_windows('pro');           % Pro版
```

実行環境・必要製品・`.mlapp` の存在を確認し、全テスト成功後に `build/windows/standard/ProcessInsightTool.exe` または `build/windows/pro/ProcessInsightToolPro.exe` と付随ファイルを生成します。画面タイトルは通常版が「Process Insight Tool」、Pro版が「Process Insight Tool Pro」です。`core/`、`app/`、HTML手順書と`samples/`を同梱します。このスクリプトは exe と付随ファイルを作成します。MATLAB Runtime やインストーラーは含みません。

配布用の Runtime は [MathWorks の MATLAB Runtime 配布ページ](https://www.mathworks.com/products/compiler/matlab-runtime.html)から R2025b / Windows 64bit を取得します。会社の許可済み手順で、ビルド環境と対応する更新版をオフライン配布してください。アプリ自身がネットから Runtime を取得する処理はありません。

`build/windows/` 内の exe だけを抜き出さず、生成された付随ファイルもまとめて配布します。出力の readme に追加の配布指示があれば従ってください。

通常版はPro専用のSHAPカーブ近似・残差診断7ファイルを隔離ソースから除外してコンパイルします。Pro版にはそれらを含めます。ビルド後の `edition-manifest.json` でEditionとファイル一覧を確認してください。実行時の設定や引数で版を変更する機能はありません。MATLABソースの開発確認は `launch_analysis_app('standard')` / `launch_analysis_app('pro')` で切り替えます。

## 6. MATLAB 本体のない端末で確認する

MATLAB Runtime R2025b だけを入れた Windows 64bit 端末で、以下を実施します。

- [ ] 起動して10タブが表示される。
- [ ] 「4 炉内補間」のWaferId・BoatSlot・計測列・任意のバッチ列、CSV先頭ゼロ保持、Run分離、項目別未計測、重複/空欄/非数値チェックを確認する。スプライン/3次多項式（poly3）/RBF/3 GPR、内部Slotの8指標・学習指標・バッチ別の順位、生成SlotのWaferId空欄、GPRの95%応答予測区間、外挿と破線、CSV/Excel/PNG、条件変更時の消去、中止・ロック復元、リサイズを確認する。
- [ ] 画面・Help・手順書の表記がSwing Curveであり、設定は9、Helpは10である。
- [ ] Excel / CSV のシート・ヘッダー指定と列割当が動く。
- [ ] 列対応の確認前は学習できず、変更後は再確認が必要。
- [ ] APC の24行で停止、25〜149行で警告、150行以上で警告なし。
- [ ] 3種類の学習で `Train_Model` だけが保存され、画面の全検証が成功する。
- [ ] APC・Swing Curve・汎用GPRで複数カーネルの一括比較を行う。同一分割の検証8指標・分割別RMSE・検証予測・要約・アプリ内グラフ、採用候補切替、CSV / Excel / PNG、SHAP計算後に選択した全データモデルのMAT保存・検証を確認する。一部失敗・全失敗・中止・保存キャンセル・設定変更後の学習履歴保持・処理中の入力ロックも確認する。周期カーネルは各分割内で周期を再探索し、各分割のPeriodも確認する。
- [ ] モデリングとSHAPは保存前に完了し、保存操作だけで再計算しない。保存キャンセル後もモデル・評価・SHAPが残る。
- [ ] SHAP とノイズ除去用 SHAP が Runtime でも動き、グラフを PNG に保存できる。
- [ ] Swing Curve学習のSHAP、RESIST_THの正弦波＋直線近似、膜厚・周期範囲の更新、極値・隣接傾きの表、CSV / Excel / PNG出力を確認する。
- [ ] 近似残差の分布・正規Q–Q・残差対膜厚、Lilliefors検定とp値境界、歪度・尖度・超過尖度、判定対象外の表示、範囲変更時の診断消去と再計算、CSV / Excel / PNG出力を確認する。
- [ ] swingperiodicで周期自動探索、exact / sd / sr / fic、進捗・中止、周期と尤度の表示・履歴保存を確認する。MATの変数はTrain_Modelのみ、周期・説明変数数＋3個のカーネル量・予測の保存前後一致、SHAP、制御側の新規MATLABセッションでアプリのソースをパスへ追加せずにpredict、RuntimeでのMAT読込みと予測も確認する。
- [ ] 推定対象の外挿行が表で分かり、警告が画面にも残る。
- [ ] D/I最適、2〜5水準の直交表、固定点を保つ拡張計画、交絡図と係数表、ワードクラウドが動く。
- [ ] 設定の保存・再起動後の反映、ライト/ダーク、Helpの用語・公式リンク・同梱HTMLが使える。
- [ ] 幅900/1320/1600pxで入力・結果を操作でき、図が外部ウィンドウへ出ない。
- [ ] 8指標の一括評価、未定義指標の理由、入力・実測・予測・残差の要約と CSV / Excel 出力を確認する。
- [ ] ログを追記でき、測定値そのものを含まない。
- [ ] 保存先やログ先が書込み不可の場合、エラーを画面で確認できる。
- [ ] 旧・新モデルの `compare_models` を開発用 R2025b 上で実行し、結果を確認済み。

実行した OS、MATLAB / Runtime の更新版、成功・失敗件数、結果を `verification.md` に追記してください。ここまで確認するまでは配布検証完了として扱いません。

## 版ごとの追加確認

- [ ] 通常版でSHAP分布・依存図を使え、レジスト膜厚のフィッティング／カーブ評価は利用できない。
- [ ] Pro版で三角関数・スプラインを切り替え、極値・区間ごとの山間／谷間の傾き・残差診断を表示できる。APC学習にはSwing Curve評価が付かない。
- [ ] Swing CurveがRESIST_THの1列で学習でき、248nm÷1.77を基準に周期探索する。任意範囲指定とカーネル比較でも同じ指定を使う。
- [ ] MATを保存せずともモデル一覧と読込済みMATから対象を選び、SHAPを再計算できる。
- [ ] SwingCurve_Model_CD_X / GenericGPR_Model_Y1など目的変数付きの保存名と、MAT内のTrain_Model、再読込み時の予測一致を確認する。
- [ ] 数値列・文字列・欠損を含む色指定で、元ファイル行の対応・点数・評価値を変えずに表示できる。

## 2026-11-06の追加確認

評価用の合成Excelは`samples/ProcessInsight_Samples.xlsx`です。列指定は`samples/README.md`とブックの「使い方」を参照します。データシートはすべてヘッダー行1で読み込みます。

- [ ] APC・Swing CurveでCD_X / CD_Yを複数選択し、各目的変数を別モデルで一括学習・SHAP評価する。学習時に保存ダイアログが出ない。
- [ ] Swing Curveの下地なしは膜厚1列、下地ありは選択した複数の追加説明変数＋膜厚となる。目的変数の混入・重複列を拒否する。
- [ ] 「条件比較・モデル保存」で複数kernel×fit_methodを評価する。入力・条件・設定変更後も以前のモデルと元入力を保持し、選択したモデルの予測・SHAP・全指標を表示できる。
- [ ] SHAP失敗時はモデルを保持し、失敗理由と再計算手順を確認する。学習失敗候補は保存対象にならない。
- [ ] 最後に選択した1モデルだけを再学習・SHAP再計算せずMAT保存し、全検証が成功する。
- [ ] 炉内補間でBatchを指定し、膜厚と屈折率を一括比較する。選択したRun・目的変数・方式だけをMAT保存し、Furnace_Model単独・保存前後の予測/区間一致を確認する。スプライン・RBF・poly3・3 GPRすべてを確認する。
- [ ] `load_furnace_model`と`predict_furnace_model`で保存モデルを学習範囲内で再利用する。Train_Model形式の読込画面とは別である。
- [ ] 実験計画の水準数が2〜5、初期実験数が25。実験計画のseed、RBF幅・正則化は設定画面だけで編集でき、保存・再起動後にも反映する。
- [ ] 9シートのサンプルを読み込み、各機能の表・図・選択モデル保存を確認する。

手元では純粋な数値と代替学習器による補助確認を行っています。R2025b限定のTestFlexibleSwingModelには複数目的変数・実SHAP・選択保存、TestFurnaceModelには3 GPRの保存前後の予測と区間一致の検証を追加しています。これらの実モデル試験はR2025bで実行してください。


## 2026-11-10の目的変数選択の確認

- [ ] APC・Swing Curve・汎用GPRでExcelを開くと、左の入力欄で目的変数を選べる。Ctrlによる複数選択と、列対応確認後の実行を確認する。
- [ ] 名前から目的変数を判別できないファイルでは未選択となり、Lotなど最終列を勝手に使用しない。Excel/CSVの再読込み後は新しい列名が候補へ反映する。
- [ ] 保存モデル推定・SHAPの評価用目的変数、炉内補間の複数目的変数も選択でき、処理終了/中止後も選択欄を使える。
- [ ] ソース修正を配布済みexeへ反映するときは、通常版/Pro版を再ビルドし、Runtime端末でも確認する。
