# Windows R2025b での仕上げ・ビルド

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

10個の機能タブ、Excel / CSV 読込、列の割当・確認、結果書出しを確認します。各学習画面で RMSE・R²・評価表・列要約を確認します。SHAP はアプリ内のグラフと PNG 保存を確認します。設定・Help・画面リサイズも確認します。

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
result = build_windows;
```

実行環境・必要製品・`.mlapp` の存在を確認し、全テスト成功後に `build/windows/` へ生成します。`core/`、`app/` とHTML手順書のフォルダを同梱します。このスクリプトは exe と付随ファイルを作成します。MATLAB Runtime やインストーラーは含みません。

配布用の Runtime は [MathWorks の MATLAB Runtime 配布ページ](https://www.mathworks.com/products/compiler/matlab-runtime.html)から R2025b / Windows 64bit を取得します。会社の許可済み手順で、ビルド環境と対応する更新版をオフライン配布してください。アプリ自身がネットから Runtime を取得する処理はありません。

`build/windows/` 内の exe だけを抜き出さず、生成された付随ファイルもまとめて配布します。出力の readme に追加の配布指示があれば従ってください。

## 6. MATLAB 本体のない端末で確認する

MATLAB Runtime R2025b だけを入れた Windows 64bit 端末で、以下を実施します。

- [ ] 起動して10タブが表示される。
- [ ] 「8 炉内補間」のWaferId・BoatSlot・計測列・任意のバッチ列、CSV先頭ゼロ保持、Run分離、項目別未計測、重複/空欄/非数値チェックを確認する。スプライン/RBF/3 GPR、内部Slotの8指標・学習指標・バッチ別の順位、生成SlotのWaferId空欄、GPRの95%応答予測区間、外挿と破線、CSV/Excel/PNG、条件変更時の消去、中止・ロック復元、リサイズを確認する。
- [ ] 画面・Help・手順書の表記がSwing Curveであり、設定は9、Helpは10である。
- [ ] Excel / CSV のシート・ヘッダー指定と列割当が動く。
- [ ] 列対応の確認前は学習できず、変更後は再確認が必要。
- [ ] APC の24行で停止、25〜149行で警告、150行以上で警告なし。
- [ ] 3種類の学習で `Train_Model` だけが保存され、画面の全検証が成功する。
- [ ] APC・Swing Curve・汎用GPRで複数カーネルの一括比較を行う。同一分割の検証8指標・分割別RMSE・検証予測・要約・アプリ内グラフ、採用候補切替、CSV / Excel / PNG、選択した全データモデルのMAT保存・検証・後続SHAPを確認する。一部失敗・全失敗・中止・保存キャンセル・設定変更時の消去・処理中の入力ロックも確認する。周期カーネルは各分割内で周期を再探索し、各分割のPeriodも確認する。
- [ ] 保存キャンセル後も評価結果が残り、後続 SHAP が実行されない。
- [ ] SHAP とノイズ除去用 SHAP が Runtime でも動き、グラフを PNG に保存できる。
- [ ] Swing Curve学習の任意SHAP、RESIST_THの正弦波＋直線近似、膜厚・周期範囲の更新、極値・隣接傾きの表、CSV / Excel / PNG出力を確認する。
- [ ] 近似残差の分布・正規Q–Q・残差対膜厚、Lilliefors検定とp値境界、歪度・尖度・超過尖度、判定対象外の表示、範囲変更時の診断消去と再計算、CSV / Excel / PNG出力を確認する。
- [ ] swingperiodicで周期自動探索、exact / sd / sr / fic、進捗・中止、周期と尤度の表示・履歴保存を確認する。MATの変数はTrain_Modelのみ、周期・7カーネル量・予測の保存前後一致、SHAP、制御側の新規MATLABセッションでアプリのソースをパスへ追加せずにpredict、RuntimeでのMAT読込みと予測も確認する。
- [ ] 推定対象の外挿行が表で分かり、警告が画面にも残る。
- [ ] D/I最適、2/3水準の直交表、固定点を保つ拡張計画、交絡図と係数表、ワードクラウドが動く。
- [ ] 設定の保存・再起動後の反映、ライト/ダーク、Helpの用語・公式リンク・同梱HTMLが使える。
- [ ] 幅900/1320/1600pxで入力・結果を操作でき、図が外部ウィンドウへ出ない。
- [ ] 8指標の一括評価、未定義指標の理由、入力・実測・予測・残差の要約と CSV / Excel 出力を確認する。
- [ ] ログを追記でき、測定値そのものを含まない。
- [ ] 保存先やログ先が書込み不可の場合、エラーを画面で確認できる。
- [ ] 旧・新モデルの `compare_models` を開発用 R2025b 上で実行し、結果を確認済み。

実行した OS、MATLAB / Runtime の更新版、成功・失敗件数、結果を `verification.md` に追記してください。ここまで確認するまでは配布検証完了として扱いません。
