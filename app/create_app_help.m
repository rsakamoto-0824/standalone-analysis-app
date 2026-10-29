function create_app_help(tab, project_root)
layout = uigridlayout(tab, [6, 1], 'Scrollable', 'on');
layout.RowHeight = {40, 270, 90, 170, 104, 36};
uilabel(layout, 'Text', 'Help — 用語、評価の読み方、公式の関数ヘルプ', 'FontWeight', 'bold');
terms = {
    'GPR', 'ガウス過程回帰。入力から応答を予測するモデル。kernel と fit_method を選択します。';
    'swingperiodic', 'スイング学習専用の周期カーネル。RESIST_THの周期成分、他3変数の滑らかな影響、膜厚の線形トレンドを組み合わせます。周期の入力は不要で、固定周期ごとのGPR周辺尤度を内部で比較します。';
    '周期の内部最適化', '周期はKernelParametersやOptimizeHyperparametersに含めません。周期ごとに他の7カーネル量とノイズ等を学習し、最大の周辺対数尤度を採用します。exact以外は近似尤度。最大48候補で大域最適性は保証しません。';
    '周辺対数尤度', 'GPRがデータを説明する程度を複雑さも含めて評価する基準。今回の周期選択では大きい値を採用します。交差検証による汎化性能ではありません。同じ入力・応答・fit_methodの候補間で比較します。';
    'RMSE', '誤差の二乗平均の平方根。実測値と同じ単位で、小さいほど一致します。';
    '決定係数 R²', '1−Σ(実測−予測)²/Σ(実測−実測平均)²。1が完全一致、負値もあります。実測が一定なら未定義です。';
    '相関係数の2乗', 'Pearson r の2乗。予測の偏りを検出できない場合があり、決定係数 R² とは別の指標です。';
    'RMSPE / MAE', 'RMSPE は相対誤差の二乗平均平方根（%）、実測に0があれば未定義。MAE は絶対誤差の平均。';
    'KL / 相互情報量', 'KL は分布の違い（nats）、相互情報量は依存の強さ（bits）。ヒストグラムと擬似度数1を使用。ビン数で値が変わります。';
    '学習時の評価', '学習に使ったデータで計算した当てはまりです。未知データの性能を示す交差検証ではありません。保存モデルで推定＋未使用の実測列で評価できます。';
    'SHAP', 'モデルの予測に各入力がどれだけ寄与したかを示す値。因果関係を証明するものではありません。';
    'スイング近似', 'RESIST_THのSHAP値を、オフセット＋直線トレンド＋一定振幅の正弦波で近似します。周期・振幅・R²・RMSEはSHAP散布点への近似結果で、GPRの評価とは別です。';
    '極値の膜厚', '傾きを含む近似曲線の微分が0になる位置。プロット範囲内の極大・極小のみを表示します。端点を自動で極値扱いしません。';
    '山間・谷間の傾き', '隣接する同種の極値を結ぶ傾き（SHAP値の差/膜厚の差）。この一定振幅＋直線モデルでは全区間で同じ傾きです。バルク効果の物理的な証明ではありません。';
    '近似残差', 'SHAP値−スイング近似値。ヒストグラムと標本平均・標準偏差の正規密度、正規Q–Q、残差対膜厚をアプリ内で表示します。GPRの実測−予測の残差とは別です。';
    '正規性検定', 'Lilliefors検定、有意水準α=0.05。正規性を棄却できない場合も正規分布の証明ではありません。近似後の残差の依存性を補正していないためp値は参考診断です。0.001以下/0.5以上のp値は境界を明示します。';
    '歪度 / 尖度', '偏り補正付き。歪度は左右の非対称性（正規分布0）、尖度は裾・外れ値の影響を反映する4次モーメント（正規分布3）。超過尖度は尖度−3（正規分布0）。これらの値だけで正規性を判断しません。';
    '正規Q–Q', '横軸は標準正規分布の理論分位点、縦軸は中心化・標準化した残差の分位点。斜めの基準線からの曲がりや裾のずれを確認します。点の整列は独立性を保証しません。';
    '列の要約', '割り当てた入力・実測・予測・残差の件数、平均、四分位数、不偏標準偏差など11項目を計算します。';
    'D最適 / I最適', 'D はモデル係数を推定する情報量、I は領域全体の平均予測分散を重視。モデルを変えると計画も変わります。';
    '直交表', '各2因子の水準組合せが均等に現れる計画。同一水準の2水準L4/L8/L16、3水準L9/L27から必要サイズを自動選択します。';
    '拡張実験計画', '既存点を先頭に固定し、指定した追加数の点を D または I 基準で探索。既存点は−1〜1に符号化して読み込みます。';
    '交絡', '別のモデル項の効果を区別できない状態。図の対角線以外が1なら2項が同一または逆符号。複数項の関係は零空間の係数表で確認します。';
    'ランク不足', 'モデル項に独立でない組合せがあり、すべての係数を個別には推定できません。直交表でも二次モデルはランク不足になり得ます。';
    '符号化 / 外挿', '符号化は因子の下限を−1、上限を1へ変換すること。外挿は学習範囲外への予測で、精度は別途確認が必要です。'};
glossary = uitable(layout, 'Data', terms, 'ColumnName', {'用語', '説明（選択すると下に全文）'}, 'ColumnWidth', {160, 'auto'}, 'RowName', {});
description = uitextarea(layout, 'Editable', 'off', 'Value', {'用語表の行を選択すると、ここに説明の全文を表示します。'});
glossary.CellSelectionCallback = @(~, event) showTerm(event, terms, description);
uitextarea(layout, 'Editable', 'off', 'Value', {
    '操作：入力を開く → 列対応を確認 → 実行。結果・モデル評価・列の要約・グラフ・保存後検証を右側で切替。';
    '周期カーネル：スイング学習でswingperiodicを選択。周期と尤度は左欄、履歴は「周期の最適化」、図はグラフ内で確認。周期ごとの再学習で時間が増えます。設定でスイング専用の既定kernelを変更できます。';
    '推定 / SHAP：実測列を任意で選ぶと評価指標も計算。実測列なしでは RMSE / R² は計算しません。';
    'スイング近似：RESIST_TH依存図で膜厚・周期範囲を設定し更新。近似指標・極値・隣接傾きの表を選んで保存。膜厚の異なる点が8点以上必要です。';
    '残差診断：近似カーブ横の「残差分布」「正規Q–Q」「残差対膜厚」で確認。「残差の正規性」「残差データ」の表はCSV/Excelへ保存。ばらつきが数値しきい値以下なら検定・形状統計を対象外と表示します。';
    '保存：表示中の表を CSV / Excel へ、アプリ内グラフを PNG へ保存できます。';
    'D/I の探索候補は各因子 −1/0/1。I の積分対象は連続な一様領域 [-1,1]^k。局所探索のため最適性は保証しません。';
    '実験計画は1〜8因子、追加1〜300件、既存＋追加500件以下。直交表では実験数の欄を使用しません。';
    '設定：保存先、テーマ、kernel、fit_method、入力数、ビン数、因子数、実験数、seed、SHAP表示の初期値を変更できます。'});
links = uigridlayout(layout, [3, 4]); links.Padding = [0, 0, 0, 0];
functions = {'fitrgp', 'RegressionGP', 'shapley', 'swarmchart', 'wordcloud', 'cordexch', 'daugment', 'fracfact', ...
    'lillietest', 'skewness', 'kurtosis', 'norminv'};
folders = {'stats', 'stats', 'stats', 'matlab/ref', 'matlab/ref', 'stats', 'stats', 'stats', 'stats', 'stats', 'stats', 'stats'};
for index = 1:numel(functions)
    url = ['https://www.mathworks.com/help/' folders{index} '/' lower(functions{index}) '.html'];
    uibutton(links, 'Text', [functions{index} ' ↗'], 'ButtonPushedFcn', @(~, ~) web(url, '-browser'));
end

uibutton(layout, 'Text', 'スクリーンショット付き ビルド・利用手順書を開く', ...
    'ButtonPushedFcn', @(~, ~) web(fullfile(project_root, 'docs', 'user-guide', 'procedure-guide.html'), '-browser'));
end

function showTerm(event, terms, description)
if isempty(event.Indices), return; end
row = event.Indices(1, 1); description.Value = {terms{row, 1}; terms{row, 2}};
end
