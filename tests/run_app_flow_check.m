function results = run_app_flow_check(shot_folder)
% アプリを実際に起動し、同梱サンプルで全機能を画面の操作と同じ入口から通す確認。
%   results = run_app_flow_check            確認だけ行う
%   results = run_app_flow_check(folder)    各画面の画像も folder へ保存する
% 学習は実際の fitrgp を使う。R2025b では SHAP も実際の shapley を使う。
% R2025b 以外（開発用の例外で起動した場合）は SHAP だけ代替計算へ差し替える。
% 設定とログは一時フォルダへ保存し、利用者の設定を変更しない。
if nargin < 1, shot_folder = ''; end
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'core'), fullfile(root, 'app'), fullfile(root, 'tests'));
work = tempname; mkdir(work); cleanup_work = onCleanup(@() removeFolder(work));
sample = fullfile(root, 'samples', 'ProcessInsight_Samples.xlsx');
window = uifigure('Position', [40, 40, AnalysisController.WINDOW_SIZE], 'Visible', 'on');
cleanup_window = onCleanup(@() deleteWindow(window));
app = AnalysisController(window, 'pro', work);
alerts = {};
app.AlertFcn = @recordAlert;
real_shap = app.IsTargetRelease;
if ~real_shap
    services = app.Services; services.Shap = @approximate_shap_for_check; services.Denoise = @approximate_denoise_for_check;
    app.Services = services;
end
names = {}; passed = []; notes = {};
apc_path = fullfile(work, 'Train_Model_CD_X.mat'); pro_gpr_path = fullfile(work, 'GenericProGPR_Model_CD_X.mat');

step('起動とホーム画面', @() app.selectPage('home'));
step('APC：2カーネルを交差検証あり・なしで比較・SHAP・保存', @checkApc);
step('Swing Curve：下地あり', @checkSwingWithBase);
step('Swing Curve：下地なし・周期カーネル', @checkSwingPeriodic);
step('データの傾向：単変量（質的・量的な色）と Pro 版の8種類のグラフ', @checkExplorer);
step('汎用回帰：GPR・重回帰・PLS・ランダムフォレスト・バギング木の比較と保存', @checkGeneric);
step('Pro版の回帰：EBM・XGBoost・LightGBM・CatBoost・ハイパーパラメータ探索・目的変数ごとの並べ替え', @checkBoosting);
step('Pro版のGPR：加法カーネル・質的変数（Lot）・変数重要度（Permutation Importance・VIP）', @checkProGpr);
step('炉内補間：2Run・6方式・目的変数ごとの棒グラフ・保存', @checkFurnace);
step('保存モデルで推定・SHAP：評価つき・SHAP依存図', @checkPredict);
step('保存モデルで推定・SHAP：起動中のモデル・質的変数のモデル', @checkShapPage);
step('Sobol感度解析：保存モデルの範囲から1次・全効果', @checkSobol);
step('因果探索：PCアルゴリズムと DirectLiNGAM', @checkCausal);
step('階層ベイズ：Lot ごとの切片と傾き', @checkBayes);
step('実験計画：D最適・I最適・直交表・拡張と評価指標', @checkDesign);
step('ワードクラウド：形と色', @checkWords);
step('設定：テーマ・文字の大きさの変更で結果が消えない', @checkSettings);
step('Help', @() app.selectPage('help'));
step('通常版：Pro版だけの機能（周期カーネル・拡張計画・データのグラフ・回帰方式・加法カーネル・質的変数・Sobol・因果探索・階層ベイズ・ワードクラウド）と説明を出さない', @checkStandardEdition);
step('細かい操作：並べ替え・書出し・CSV・ヘッダー行', @checkDetails);
step('結果の表示と出力：横並びの散布図・SHAPの色・1ファイル出力・進捗', @checkOutputs);
step('入力の誤りを分かる言葉で止める', @checkValidation);

results = table(string(names(:)), logical(passed(:)), string(notes(:)), 'VariableNames', {'Step', 'Passed', 'Note'});
disp(results);
fprintf('SHAP: %s\n', ternary(real_shap, '実際の shapley（R2025b）', '代替計算（R2025b以外のため。実SHAPは未確認）'));
fprintf('確認 %d 件中 %d 件成功\n', height(results), sum(results.Passed));
if ~all(results.Passed), error('run_app_flow_check:failed', '失敗した確認があります。上の表の Note を確認してください。'); end

    function recordAlert(text, title_text, icon)
        alerts{end + 1} = sprintf('[%s] %s: %s', icon, title_text, text);
    end
    function step(name, action)
        alerts = {}; note = ''; ok = true;
        try
            action(); drawnow;
            errors = alerts(startsWith(alerts, '[error]'));
            if ~isempty(errors), ok = false; note = strjoin(errors, ' / '); end
        catch err
            ok = false; note = sprintf('%s（%s 行%d）', err.message, err.stack(1).name, err.stack(1).line);
        end
        names{end + 1} = name; passed(end + 1) = ok; notes{end + 1} = note;
        fprintf('%s %s %s\n', ternary(ok, 'OK  ', 'FAIL'), name, note);
        capture(name);
    end
    function capture(name)
        if isempty(shot_folder), return; end
        if ~isfolder(shot_folder), mkdir(shot_folder); end
        try
            drawnow; pause(1);
            exportapp(window, fullfile(shot_folder, sprintf('%02d_%s.png', numel(names), matlab.lang.makeValidName(name))));
        catch err
            fprintf('画像を保存できませんでした: %s\n', err.message);
        end
    end
    function expectAlert(action, fragment)
        % 誤った操作で、処理が止まり説明が表示されることを確認する。
        alerts = {}; action();
        hit = any(contains(alerts, fragment));
        assert(hit, '想定した説明「%s」が表示されませんでした。表示: %s', fragment, strjoin(alerts, ' / '));
        alerts = {};
    end

    function checkApc()
        app.selectPage('apc'); page = app.page('apc');
        page.openSample(); assert(~isempty(page.Source.Data), 'サンプルを読み込めません。');
        assert(isequal(page.Mapper.selection(), app.Constants.PREDICTOR_NAMES), 'APCの4変数が列名で自動割当されていません。');
        page.selectTargets({'CD_X'});
        assert(~page.UseCrossValidation.Value && strcmp(page.Folds.Enable, 'off'), '初期状態では交差検証を使いません。');
        % 列対応の確認ボタンはなく、実行時に自動で確認する。交差検証は選んだときだけ使う。
        page.UseCrossValidation.Value = true; page.UseCrossValidation.ValueChangedFcn([], []);
        page.Kernels.Value = {'squaredexponential', 'matern52'}; page.runModeling();
        assert(numel(page.Records) == 2, 'モデルが2個できていません。');
        for index = 1:2
            record = page.Records{index};
            assert(strcmp(record.Status, '成功'), 'APC学習の失敗: %s', record.Note);
            assert(strcmp(record.Scope, '5分割交差検証'), '交差検証を選んだときは交差検証で評価します。');
            assert(strcmp(record.ShapStatus, '成功'), 'SHAPの失敗: %s', record.Note);
            assert(isequal(record.Model.PredictorNames, app.Constants.PREDICTOR_NAMES), '説明変数の名前・順序が仕様と違います。');
        end
        assert(page.SelectedRow >= 1 && ~isempty(page.Result.validCharts()), '結果のグラフが表示されていません。');
        report = page.saveSelectedTo(apc_path);
        assert(report.Success, '保存後検証に失敗しました。');
        variables = whos('-file', apc_path); assert(isequal({variables.name}, {'Train_Model'}), 'MATの変数が Train_Model だけではありません。');
        % 交差検証を使わずに、2つの条件を比べる。
        page.UseCrossValidation.Value = false; page.UseCrossValidation.ValueChangedFcn([], []);
        page.ComputeShap.Value = false; page.Kernels.Value = {'squaredexponential', 'matern52'}; page.selectTargets({'CD_X'});
        page.runModeling();
        assert(numel(page.Records) == 4, '以前の結果を残したまま、2モデルを追加します。');
        for index = 3:4
            assert(strcmp(page.Records{index}.Scope, '学習データ') && isempty(page.Records{index}.FoldId), '交差検証なしで比べられません。');
            assert(strcmp(page.Records{index}.ShapStatus, '未計算'), 'SHAPなしの条件が反映されていません。');
        end
        page.selectRow(3); page.computeShapForSelected();
        assert(strcmp(page.Records{3}.ShapStatus, '成功'), '後からのSHAP計算に失敗しました。');
    end
    function checkOutputs()
        app.selectPage('apc'); page = app.page('apc'); page.selectRow(1); record = page.Records{1};
        % 実測値と予測値・残差は1つのタブに横並び（2つの図）。
        tabs = page.Result.ChartTabs.Children; titles = {tabs.Title};
        assert(any(strcmp(titles, EvaluationScatterView.TAB_TITLE)) && ~any(strcmp(titles, '残差')), '散布図が1つのタブにまとまっていません: %s', strjoin(titles, ', '));
        scatter_tab = tabs(strcmp(titles, EvaluationScatterView.TAB_TITLE));
        assert(numel(findobj(scatter_tab, 'Type', 'axes')) == 2, '散布図のタブに2つの図がありません。');
        % 入れ子の関数は外側と変数を共有するため、外側の names（確認項目の名前）と別の名前にする。
        [charts, chart_names] = page.Result.validCharts();
        combined = find(strcmp(chart_names, EvaluationScatterView.COMBINED_NAME), 1);
        assert(~isempty(combined), '2つ並べた図を書き出しの対象にしていません。');
        png = fullfile(work, 'scatter_pair.png'); page.Result.exportFigureTo(charts{combined}, png);
        picture = imread(png); assert(size(picture, 2) > 1.6 * size(picture, 1), '2つ並べた図のPNGが横長になっていません（%d×%d）。', size(picture, 2), size(picture, 1));
        % SHAP依存図の色を、任意の説明変数へ切り替える。
        dependence = tabs(strcmp(titles, 'SHAP 依存: SIN_TH'));
        selector = findobj(dependence, 'Type', 'uidropdown'); assert(numel(selector) == 1, 'SHAP依存図に色の選択欄がありません。');
        assert(isequal(selector.ItemsData, 0:4), '色の候補が「単色」と全説明変数になっていません。');
        selector.Value = find(strcmp(record.InputNames, 'NSG_TH')); selector.ValueChangedFcn(selector, []);
        scale = findobj(dependence, 'Type', 'colorbar'); assert(numel(scale) == 1 && strcmp(scale.Label.String, 'NSG_TH'), '色の変数を切り替えられません。');
        selector.Value = 0; selector.ValueChangedFcn(selector, []);
        assert(isempty(findobj(dependence, 'Type', 'colorbar')), '単色に戻せません。');
        % 元データの説明変数・目的変数と、予測値・残差・SHAPを1つの表・1つのファイルにする。
        output = page.Result.tableData(page.TABLE_OUTPUT);
        expected = [{'SourceRow'}, app.Constants.PREDICTOR_NAMES, {'CD_X', 'CD_X_予測値', 'CD_X_残差', '検証分割', 'CD_X_全データモデルの予測値'}, ...
            strcat('SHAP_', app.Constants.PREDICTOR_NAMES)];
        assert(isequal(output.Properties.VariableNames, expected), '出力の列が想定と違います: %s', strjoin(output.Properties.VariableNames, ', '));
        assert(height(output) == numel(record.Actual) && isequal(output.CD_X, record.Actual), '出力の目的変数が元データと一致しません。');
        assert(max(abs(output.("CD_X_残差") - (record.Actual - record.Prediction))) == 0, '残差が実測−予測になっていません。');
        source = page.Source.Data; column = find(strcmp(source.Headers, 'SIN_RN'));
        assert(isequal(output.SIN_RN, cell2mat(source.Cells(:, column))), '出力の説明変数が元データと一致しません。');
        csv = fullfile(work, 'output.csv'); page.exportOutputTo(csv);
        file = fopen(csv, 'r'); head = fread(file, 3, '*uint8')'; fclose(file);
        assert(isequal(head, uint8([239, 187, 191])), 'CSVの先頭にBOMがありません（Windows版Excelで文字化けします）。');
        back = readtable(csv, 'VariableNamingRule', 'preserve', 'Encoding', 'UTF-8');
        assert(isequal(back.Properties.VariableNames, expected) && height(back) == height(output), '保存したCSVを読み戻せません。');
        xlsx = fullfile(work, 'output.xlsx'); page.exportOutputTo(xlsx);
        back = readtable(xlsx, 'VariableNamingRule', 'preserve'); assert(width(back) == numel(expected), 'Excelへ保存できません。');
        % 基準周期は 波長 ÷ 屈折率 ÷ 2（約70nm）。
        swing = app.page('swing');
        assert(contains(swing.Period.Reference.Text, '÷ 2 = 70.0565'), '基準周期の表示が違います: %s', swing.Period.Reference.Text);
        last = swing.Records{end}; assert(abs(last.PeriodOptions.ReferencePeriod - 248/1.77/2) < 1e-9, '学習に使った基準周期が違います。');
    end
    function checkSwingWithBase()
        app.selectPage('swing'); page = app.page('swing');
        page.openSample(); page.selectTargets({'CD_X'});
        page.setSwingVariables(page.MODE_WITH, 'RESIST_TH', {'SIN_TH', 'SIN_RN', 'NSG_TH'});
        assert(strcmp(page.Underlayers.Enable, 'on'), '下地ありで、下地の一覧を選べません。');
        mapping = page.MappingTable.Data;
        assert(isequal(mapping(:, 2)', {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'}), '下地ありの列順が違います: %s', strjoin(mapping(:, 2)', ','));
        page.runModeling();
        record = page.Records{end}; assert(strcmp(record.Status, '成功'), 'Swing学習の失敗: %s', record.Note);
        assert(strcmp(record.Model.PredictorNames{end}, 'RESIST_TH') && numel(record.Model.PredictorNames) == 4, '膜厚が最後の説明変数になっていません。');
        page.setSwingVariables(page.MODE_WITH, 'RESIST_TH', {'SIN_TH'});
        mapping = page.MappingTable.Data;
        assert(isequal(mapping(:, 2)', {'SIN_TH', 'RESIST_TH'}), '下地の選択変更が対応表へ反映されていません。');
    end
    function checkSwingPeriodic()
        page = app.page('swing');
        page.Source.open(sample, 'Swing_NoBase', 1); page.selectTargets({'CD_X'});
        page.setSwingVariables(page.MODE_WITHOUT, 'RESIST_TH');
        assert(strcmp(page.Underlayers.Enable, 'off'), '下地なしでは下地の一覧を使いません。');
        page.Kernels.Value = {'swingperiodic'}; page.runModeling();
        record = page.Records{end}; assert(strcmp(record.Status, '成功'), '周期カーネルの失敗: %s', record.Note);
        assert(~isempty(record.Details) && isfinite(record.Details.Period), '周期の探索結果がありません。');
        bounds = record.PeriodOptions.PeriodBounds;
        assert(record.Details.Period >= bounds(1) && record.Details.Period <= bounds(2), '周期が探索範囲の外です。');
        path = fullfile(work, 'SwingCurve_Model_CD_X.mat'); report = page.saveSelectedTo(path);
        assert(report.Success, '周期カーネルモデルの保存後検証に失敗しました。');
    end
    function checkGeneric()
        app.selectPage('generic'); page = app.page('generic');
        page.openSample(); page.selectPredictors({'X1', 'X2', 'X3'}); page.selectTargets({'Y1', 'Y2'});
        page.Regressors.linear.Value = true; page.Regressors.pls.Value = true;
        page.Regressors.forest.Value = true; page.Regressors.bagging.Value = true; page.Regressors.bagging.ValueChangedFcn([], []);
        % Pro 版では木の本数を「ハイパーパラメータ」の表で指定する（通常版の「木の本数」欄はない）。
        assert(isempty(page.TreeCount) && ~isempty(page.Hyper), 'Pro版では木の本数をハイパーパラメータの表で指定します。');
        page.Hyper.setValue('forest', 'NumTrees', 50); page.Hyper.setValue('bagging', 'NumTrees', 50);
        page.runModeling();
        assert(numel(page.Records) == 10, '目的変数2 × 条件5 = 10モデルになりません。');
        labels = cellfun(@(record) modeling_condition_label(record.Condition), page.Records, 'UniformOutput', false);
        for index = 1:10, assert(strcmp(page.Records{index}.Status, '成功'), '%s の失敗: %s', labels{index}, page.Records{index}.Note); end
        assert(all(ismember({'ランダムフォレスト（50本）', 'バギング木（50本）'}, labels)), '条件の名前が想定と違います: %s', strjoin(labels, ', '));
        forest = find(strcmp(labels, 'ランダムフォレスト（50本）'), 1); page.selectRow(forest);
        report = page.saveSelectedTo(fullfile(work, 'GenericForest_Model_Y1.mat'));
        assert(report.Success, 'ランダムフォレストの保存後検証に失敗しました。');
        loaded = load_analysis_model(fullfile(work, 'GenericForest_Model_Y1.mat'));
        assert(strcmp(loaded.Method, 'forest') && loaded.Trees == 50, 'ランダムフォレストの保存内容が違います。');
        linear = find(strcmp(labels, '重回帰'), 1); page.selectRow(linear);
        path = fullfile(work, 'GenericRegression_Model_Y1.mat'); report = page.saveSelectedTo(path);
        assert(report.Success, '重回帰モデルの保存後検証に失敗しました。');
        loaded = load_analysis_model(path); assert(isequal(loaded.PredictorNames, {'X1', 'X2', 'X3'}), '重回帰の説明変数名は列名を保持します。');
        gpr = find(~ismember(labels, {'重回帰'}) & ~startsWith(labels, {'PLS', 'ランダムフォレスト', 'バギング木'}), 1); page.selectRow(gpr);
        report = page.saveSelectedTo(fullfile(work, 'GenericGPR_Model_Y1.mat')); assert(report.Success, '汎用GPRの保存後検証に失敗しました。');
    end
    function checkExplorer()
        % 学習画面の①「グラフで傾向を見る」。APC のサンプルには文字の列（Lot）がある。
        page = app.page('apc'); page.openSample(); explorer = page.Explorer;
        assert(numel(explorer.Kind.Items) == 9, 'Pro版では9種類のグラフを選べます。');
        explorer.configure(struct('Kind', 'trend', 'X', explorer.RECORD, 'Y', 'CD_X', 'Color', 'Lot', 'ColorMode', 'auto')); explorer.draw();
        groups = explorer.Result.tableData('縦軸の要約');
        assert(height(groups) == 7 && groups.("グループ")(1) == "全体", '文字の列（Lot）で色分けすると、6グループの要約が出ます。');
        explorer.configure(struct('Color', 'SIN_TH', 'ColorMode', 'numeric')); explorer.draw();
        explorer.configure(struct('X', 'Lot', 'Color', explorer.NO_COLOR)); explorer.draw();
        assert(~isempty(explorer.Result.validCharts()), '単変量の傾向を描けません。');
        settings = {
            struct('Kind', 'histogram', 'Columns', {{'SIN_TH', 'CD_X'}}, 'Color', 'Lot'), 'ヒストグラム: SIN_TH'
            struct('Kind', 'correlation', 'Columns', {{'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH', 'CD_X'}}), '相関マトリックス'
            struct('Kind', 'anova', 'Y', 'CD_X', 'Columns', {{'Lot', 'SIN_TH'}}), '箱ひげ図: Lot'
            struct('Kind', 'parallel', 'Columns', {{'SIN_TH', 'SIN_RN', 'NSG_TH', 'CD_X'}}, 'Color', 'Lot'), 'Parallel Coordinates'
            struct('Kind', 'sets', 'Columns', {{'Lot', 'SIN_TH', 'CD_X'}}), 'Parallel Sets'
            struct('Kind', 'sankey', 'Columns', {{'Lot', 'SIN_TH', 'CD_X'}}), 'Sankey Diagram'
            struct('Kind', 'pca', 'Columns', {{'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'}}, 'Color', 'Lot', 'ColorMode', 'auto'), '主成分得点（PC1 × PC2）'
            struct('Kind', 'cluster', 'Columns', {{'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'}}, 'ClusterMethod', 'ward', 'ClusterCount', 3), '樹形図（Ward 法）'};
        for index = 1:size(settings, 1)
            explorer.configure(settings{index, 1}); explorer.draw();
            assert(any(strcmp(explorer.Result.ChartNames, settings{index, 2})), '「%s」のグラフがありません。', settings{index, 2});
        end
        anova = (struct('Kind', 'anova', 'Y', 'CD_X', 'Columns', {{'Lot'}})); explorer.configure(anova); explorer.draw();
        result = explorer.Result.tableData('ANOVA表');
        assert(any(result.("要因") == "Lot") && all(isfinite(result.("p値")(1))), '分散分析の表が不正です。');
        explorer.configure(struct('Kind', 'parallel', 'Columns', {{'SIN_TH', 'SIN_RN', 'NSG_TH', 'CD_X'}})); explorer.draw();
        png = fullfile(work, 'parallel.png'); explorer.Result.exportFigureTo(1, png);
        info = dir(png); assert(~isempty(info) && info.bytes > 1000, 'Parallel Coordinates をPNG保存できません。');
        page.DataTabs.SelectedTab = page.DataTabs.Children(2); app.selectPage('apc'); drawnow; capture('データの傾向（Parallel Coordinates）');
        page.DataTabs.SelectedTab = page.DataTabs.Children(1);
    end
    function checkBoosting()
        app.selectPage('generic'); page = app.page('generic');
        page.openSample(); page.selectPredictors({'X1', 'X2', 'X3'}); page.selectTargets({'Y1', 'Y2'});
        names = fieldnames(page.Regressors);
        for index = 1:numel(names), page.Regressors.(names{index}).Value = false; end
        for name = {'ebm', 'xgboost', 'lightgbm', 'catboost'}, page.Regressors.(name{1}).Value = true; end
        page.Regressors.catboost.ValueChangedFcn([], []);
        % XGBoost だけ 2×2 のグリッドサーチ、他は既定の値で学習する。
        for method = {'ebm', 'lightgbm', 'catboost'}
            specs = hyperparameter_specs(method{1});
            for row = 1:numel(specs), page.Hyper.setCandidates(method{1}, specs(row).Name, []); end
        end
        page.Hyper.setCandidates('xgboost', 'MaxDepth', [2, 3]); page.Hyper.setCandidates('xgboost', 'LearningRate', [0.1, 0.3]);
        page.Hyper.setValue('xgboost', 'NumRounds', 100); page.Hyper.setMode('grid');
        assert(contains(page.Plan.Text, '合計4通り'), '探索の試行数が実行内容に出ません: %s', page.Plan.Text);
        before = numel(page.Records); page.ComputeShap.Value = false; page.runModeling();
        added = page.Records(before + 1:end);
        assert(numel(added) == 8 && all(cellfun(@(record) strcmp(record.Status, '成功'), added)), 'ブースティング4方式 × 目的変数2の学習に失敗しました。');
        % 一覧は目的変数ごとにまとまり、同じ実行の中は順位の順に並ぶ。
        listed = page.ModelTable.Data; this_run = listed.("実行") == max(listed.("実行"));
        for target = ["Y1", "Y2"]
            ranks = listed.("順位")(this_run & string(listed.("目的変数")) == target);
            assert(isequal(ranks(:)', 1:numel(ranks)), '%s の一覧が順位の順に並んでいません。', target);
        end
        targets = string(listed.("目的変数")); first_y2 = find(targets == "Y2", 1);
        assert(all(targets(1:first_y2 - 1) == "Y1"), '一覧が目的変数ごとにまとまっていません。');
        xgboost = before + find(cellfun(@(record) strcmp(record.Condition.Regressor, 'xgboost'), added), 1);
        page.selectRow(xgboost);
        trace = page.Result.tableData(page.TABLE_SEARCH);
        assert(height(trace) == 4 && sum(trace.("採用")) == 1, '探索の表が4試行・採用1つになっていません。');
        assert(all(ismember({page.CHART_SEARCH_TRACE, page.CHART_SEARCH_EFFECT}, page.Result.ChartNames)), '探索のグラフがありません。');
        chosen = page.Result.tableData(page.TABLE_HYPERPARAMETERS);
        assert(sum(chosen.("決め方") == "探索で採用") == 2, '探索した2項目が「探索で採用」になっていません。');
        page.Result.showCharts(); drawnow; capture('ハイパーパラメータ探索の結果');
        ebm = before + find(cellfun(@(record) strcmp(record.Condition.Regressor, 'ebm'), added), 1);
        page.selectRow(ebm); assert(any(strcmp(page.Result.ChartNames, page.CHART_EBM_SHAPES)), 'EBMの形のグラフがありません。');
        path = fullfile(work, 'GenericEBM_Model_Y1.mat'); report = page.saveSelectedTo(path);
        assert(report.Success, 'EBMの保存後検証に失敗しました。');
        loaded = load_analysis_model(path); assert(strcmp(loaded.Method, 'ebm'), 'EBMの保存内容が違います。');
        page.Hyper.setMode('none');
        % 範囲外の候補は、項目名と範囲を示して止める。
        page.Hyper.selectMethod('xgboost'); message = '';
        try, page.Hyper.setCandidates('xgboost', 'MaxDepth', 20); catch err, message = err.message; end
        assert(contains(message, '木の深さ') && contains(message, '1〜10'), '範囲外の候補を止めません: %s', message);
    end
    function checkFurnace()
        app.selectPage('furnace'); page = app.page('furnace');
        page.openSample();
        assert(strcmp(page.Wafer.Value, 'WaferId') && strcmp(page.Slot.Value, 'BoatSlot') && strcmp(page.Batch.Value, 'Batch'), '列の自動選択が違います。');
        assert(numel(page.Targets.Value) == 2, '膜厚・屈折率の2列を自動選択します。');
        page.run();
        assert(~isempty(page.Report), '炉内補間の結果がありません。');
        failed = page.Report.Comparison(page.Report.Comparison.Status ~= "成功", :);
        assert(isempty(failed), '失敗した方式: %s', strjoin(failed.Method + "=" + failed.Note, ' / '));
        % 内部Slot検証のRMSEは、目的変数（膜厚・屈折率）ごとに棒グラフを分けて並べる。
        assert(all(ismember({'内部Slot検証のRMSE：膜厚_nm', '内部Slot検証のRMSE：屈折率'}, page.Result.ChartNames)), '目的変数ごとの RMSE の棒グラフがありません。');
        report = page.saveSelectedTo(fullfile(work, 'FurnaceInterpolation_Model.mat')); assert(report.Success, '炉内モデルの保存検証に失敗しました。');
    end
    function checkPredict()
        app.selectPage('predict'); page = app.page('predict');
        page.openModel(apc_path); page.Source.open(sample, 'Predict_SHAP', 1);
        assert(isequal(page.Mapper.selection(), app.Constants.PREDICTOR_NAMES), '推定の列が自動で割り当たりません。');
        page.Actual.Value = 'CD_X'; page.run();
        output = page.Result.tableData(page.TABLE_OUTPUT);
        expected = [{'SourceRow'}, app.Constants.PREDICTOR_NAMES, {'CD_X', 'CD_X_予測値', 'CD_X_残差'}, strcat('SHAP_', app.Constants.PREDICTOR_NAMES)];
        assert(isequal(output.Properties.VariableNames, expected), '推定の出力の列が想定と違います: %s', strjoin(output.Properties.VariableNames, ', '));
        assert(height(output) == size(page.Source.Data.Cells, 1) && all(isfinite(output.("CD_X_予測値"))), '推定結果が不正です。');
        assert(~isempty(page.Result.tableData('評価指標')), '実測列を選んだときは評価指標を表示します。');
        assert(any(startsWith(page.Result.ChartNames, 'SHAP 依存')), '推定と同時に SHAP 依存図を表示します。');
        % SHAP を外すと推定だけを行い、SHAP の列とグラフを出さない。
        page.ComputeShap.Value = false; page.run();
        output = page.Result.tableData(page.TABLE_OUTPUT);
        assert(~any(startsWith(output.Properties.VariableNames, 'SHAP_')) && ~any(startsWith(page.Result.ChartNames, 'SHAP')), 'SHAP を外しても SHAP を計算しています。');
        page.ComputeShap.Value = true;
    end
    function checkShapPage()
        % 起動中に学習したモデル（保存していない汎用回帰の重回帰）でも SHAP 依存図を表示する。
        app.selectPage('predict'); page = app.page('predict');
        [labels, ids] = app.Models.list(); chosen = ids(find(contains(labels, '重回帰'), 1));
        page.selectModel(chosen); page.Source.open(sample, 'Generic', 1); page.run();
        output = page.Result.tableData(page.TABLE_OUTPUT);
        assert(all(ismember(strcat('SHAP_', {'X1', 'X2', 'X3'}), output.Properties.VariableNames)), '重回帰のモデルで SHAP の列がありません。');
        assert(any(startsWith(page.Result.ChartNames, 'SHAP 依存')), '重回帰のモデルで SHAP 依存図がありません。');
        % 質的変数を持つ Pro 版の GPR：文字の列（Lot）を学習時の水準で番号に置き換えて推定する。
        page.openModel(pro_gpr_path); page.Source.open(sample, 'APC', 1); page.Mapper.select({'SIN_TH', 'RESIST_TH', 'Lot'});
        page.Actual.Value = 'CD_X'; page.run();
        output = page.Result.tableData(page.TABLE_OUTPUT);
        assert(all(isfinite(output.("CD_X_予測値"))) && any(strcmp(page.Result.ChartNames, 'SHAP 依存: Lot')), '質的変数のモデルで推定・SHAPができません。');
    end
    function checkProGpr()
        app.selectPage('generic'); page = app.page('generic');
        assert(any(strcmp(page.Kernels.Items, 'additive')) && ~isempty(page.Qualitative), 'Pro版の汎用回帰に加法カーネルと質的変数の欄がありません。');
        % 加法カーネルと PLS（VIP）を Generic サンプルで学習する。
        page.openSample(); page.selectPredictors({'X1', 'X2', 'X3'}); page.selectTargets({'Y1'});
        names = fieldnames(page.Regressors);
        for index = 1:numel(names), page.Regressors.(names{index}).Value = false; end
        page.Regressors.gpr.Value = true; page.Regressors.pls.Value = true; page.Regressors.pls.ValueChangedFcn([], []);
        page.Kernels.Value = {'additive'}; page.Kernels.ValueChangedFcn([], []); page.ComputeShap.Value = false;
        before = numel(page.Records); page.runModeling(); added = page.Records(before + 1:end);
        labels = cellfun(@(record) modeling_condition_label(record.Condition), added, 'UniformOutput', false);
        assert(isequal(sort(labels), sort({'GPR（加法カーネル）', 'PLS（2成分）'})) && all(cellfun(@(record) strcmp(record.Status, '成功'), added)), ...
            '加法カーネルと PLS の学習に失敗しました: %s', strjoin(labels, ', '));
        pls = before + find(strcmp(labels, 'PLS（2成分）')); page.selectRow(pls);
        importance = page.Result.tableData(page.TABLE_IMPORTANCE);
        assert(height(importance) == 3 && ismember('VIP', importance.Properties.VariableNames), 'PLS の変数重要度（VIP）がありません。');
        assert(all(ismember({page.CHART_PERMUTATION, page.CHART_VIP}, page.Result.ChartNames)), 'Permutation Importance・VIP のグラフがありません。');
        additive = before + find(strcmp(labels, 'GPR（加法カーネル）')); page.selectRow(additive);
        importance = page.Result.tableData(page.TABLE_IMPORTANCE);
        assert(~ismember('VIP', importance.Properties.VariableNames) && importance.("RMSEの増加")(1) > importance.("RMSEの増加")(2), ...
            'GPR の Permutation Importance が想定と違います（X1 が最も効くはず）。');
        % 質的変数：APC サンプルの文字の列 Lot を質的変数として GPR を学習し、保存する。
        page.Source.open(sample, 'APC', 1); page.selectPredictors({'SIN_TH', 'RESIST_TH', 'Lot'}); page.selectTargets({'CD_X'});
        page.Qualitative.Value = {'Lot'}; page.Qualitative.ValueChangedFcn([], []);
        expectAlert(@() page.runModeling(), '回帰方式は GPR だけ');
        page.Regressors.pls.Value = false; page.Regressors.pls.ValueChangedFcn([], []);
        page.Kernels.Value = {'additive', 'matern52'}; page.Kernels.ValueChangedFcn([], []);
        before = numel(page.Records); page.runModeling(); added = page.Records(before + 1:end);
        labels = cellfun(@(record) modeling_condition_label(record.Condition), added, 'UniformOutput', false);
        assert(isequal(sort(labels), sort({'GPR（加法カーネル・質的変数）', 'GPR（ARD二乗指数×質的変数）'})) && all(cellfun(@(record) strcmp(record.Status, '成功'), added)), ...
            '質的変数の GPR の学習に失敗しました: %s', strjoin(labels, ', '));
        page.selectRow(before + 1); report = page.saveSelectedTo(pro_gpr_path);
        assert(report.Success, '質的変数の GPR の保存後検証に失敗しました。');
        loaded = load_analysis_model(pro_gpr_path);
        assert(isequal(loaded.GPOptions.Levels{3}, "Lot-" + string(1:6)'), '保存したモデルに Lot の水準がありません。');
        page.Qualitative.Value = {}; page.Qualitative.ValueChangedFcn([], []); page.Kernels.Value = {'squaredexponential'}; page.Kernels.ValueChangedFcn([], []);
        % 後の確認は Generic サンプルを使うため、開き直す（学習結果の一覧は残る）。
        page.openSample(); page.selectPredictors({'X1', 'X2', 'X3'}); page.selectTargets({'Y1'});
    end
    function checkSobol()
        app.selectPage('sobol'); page = app.page('sobol');
        [~, ids] = app.Models.list(); page.selectModel(ids(end));
        assert(strcmp(page.Ranges.Data{3, 2}, '質的') && page.Ranges.Data{3, 4} == 6, '質的変数（Lot）の範囲が水準の番号になっていません。');
        page.SampleSize.Value = 256; page.run();
        indices = page.Result.tableData(page.TABLE_INDICES);
        assert(height(indices) == 3 && all(indices.ST >= -0.05) && all(indices.ST <= 1.2), 'Sobol 指数の表が不正です。');
        assert(any(strcmp(page.Result.ChartNames, page.CHART_INDICES)), 'Sobol 指数のグラフがありません。');
        page.setRange(1, 5, 1); expectAlert(@() page.run(), '上限は下限以上');
    end
    function checkCausal()
        app.selectPage('causal'); page = app.page('causal');
        page.Source.open(sample, 'APC', 1); page.selectColumns({'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH', 'CD_X'});
        for method = page.METHOD_CODES
            page.Method.Value = method{1}; page.run();
            edges = page.Result.tableData(page.TABLE_EDGES);
            assert(~isempty(edges) && any(edges.("先") == "CD_X" | edges.("元") == "CD_X"), '%s で CD_X につながる辺がありません。', method{1});
            assert(any(strcmp(page.Result.ChartNames, page.CHART_GRAPH)), '因果グラフがありません。');
        end
        assert(~isempty(page.Result.tableData(page.TABLE_ORDER)), 'DirectLiNGAM の因果の順序がありません。');
    end
    function checkBayes()
        app.selectPage('bayes'); page = app.page('bayes');
        page.Source.open(sample, 'APC', 1); page.selectColumns('CD_X', {'RESIST_TH'}, 'Lot');
        page.Iterations.Value = 800; page.BurnIn.Value = 300; page.run();
        groups = page.Result.tableData(page.TABLE_GROUPS);
        assert(height(groups) == 12 && all(isfinite(groups.("事後平均"))), 'Lot 6個 × 2項のグループごとの係数がありません。');
        assert(page.Report.MaxRhat < 1.2, 'R-hat が大きすぎます（%.3f）。', page.Report.MaxRhat);
        page.selectColumns('CD_X', {'CD_X'}, 'Lot'); expectAlert(@() page.run(), '別の列');
    end
    function checkDesign()
        app.selectPage('doe'); page = app.page('doe');
        for choice = 1:3
            page.Method.Value = page.METHODS{choice}; page.Method.ValueChangedFcn([], []); page.run();
            assert(~isempty(page.Result.tableData(page.TABLE_DESIGN)), '%s の計画がありません。', page.METHODS{choice});
        end
        page.Method.Value = page.METHODS{4}; page.Method.ValueChangedFcn([], []);
        page.Source.open(sample, 'DOE_Existing', 1); page.Runs.Value = 8; page.run();
        design = page.Result.tableData(page.TABLE_DESIGN);
        assert(height(design) == 18 && sum(design.Type == "既存") == 10, '拡張計画は既存10点＋追加8点です。');
        metrics = page.Result.tableData(page.TABLE_METRICS);
        efficiency = metrics.("値")(metrics.("指標") == "D効率（%）");
        assert(efficiency > 0 && efficiency <= 100 && contains(page.Result.Headline.Text, 'D効率'), '計画の評価指標（D効率）がありません。');
        assert(any(strcmp(page.Result.ChartNames, page.CHART_VARIANCE)), '予測分散の分布のグラフがありません。');
        labels = findall(page.Body, 'Type', 'uilabel');
        assert(~any(contains(string({labels.Text}), '乱数seed')), '実験計画の条件に乱数seedの説明が残っています。');
    end
    function checkWords()
        app.selectPage('words'); page = app.page('words');
        page.loadText(fullfile(root, 'samples', 'sample_wordcloud.txt'));
        page.setStyle(struct('Shape', 'rectangle', 'Scheme', 'gradient', 'Palette', 'turbo', 'MaxWords', 50)); page.run();
        assert(height(page.Result.tableData(page.TABLE_WORDS)) > 1, '単語を集計できません。');
        chart = page.Result.validCharts(); chart = chart{1};
        assert(strcmp(chart.Shape, 'rectangle') && size(chart.Color, 1) > 1, 'ワードクラウドの形・色が反映されていません。');
        page.setStyle(struct('Shape', 'oval', 'Scheme', 'single', 'BaseColor', 3)); page.run();
    end
    function checkSettings()
        app.selectPage('settings'); page = app.page('settings');
        page.Fields.Theme.Value = 'ダーク'; page.Fields.FitMethod.Value = 'sd'; page.save();
        assert(strcmp(app.Settings.Theme, 'ダーク') && isfile(app.SettingsPath), '設定を保存できません。');
        modeling = app.page('apc');
        assert(numel(modeling.Records) == 4 && ~isempty(modeling.Result.validCharts()), '設定の変更で学習結果が消えました。');
        assert(contains(modeling.FitInfo.Text, 'sd'), 'Fit method の表示が更新されていません。');
        app.selectPage('apc'); drawnow; capture('ダークテーマの学習結果');
        % 文字の大きさは保存するとすぐ全画面に反映し、見出しは比率を保つ。
        page.Fields.FontSize.Value = 16; page.save();
        assert(app.Settings.FontSize == 16, '文字の大きさを保存できません。');
        assert(modeling.RunButton.FontSize == 16, '学習画面の文字の大きさが変わりません。');
        modeling.UseCrossValidation.Value = true; modeling.UseCrossValidation.ValueChangedFcn([], []);
        assert(modeling.Plan.FontSize == 16, '実行内容の表示を更新すると、文字の大きさが標準に戻ります。');
        modeling.UseCrossValidation.Value = false; modeling.UseCrossValidation.ValueChangedFcn([], []);
        labels = findall(app.Navigation.page('home'), 'Type', 'uilabel');
        home_title = labels(contains(string({labels.Text}), 'へようこそ'));
        assert(~isempty(home_title) && home_title(1).FontSize == 24, 'ホームの見出しが標準の比率で大きくなりません（%g）。', home_title(1).FontSize);
        assert(numel(modeling.Records) == 4, '文字の大きさの変更で学習結果が消えました。');
        page.Fields.Theme.Value = 'ライト'; page.Fields.FitMethod.Value = 'exact'; page.Fields.FontSize.Value = 12; page.save();
        assert(modeling.RunButton.FontSize == 12, '文字の大きさを標準へ戻せません。');
    end
    function checkDetails()
        app.selectPage('generic'); page = app.page('generic');
        page.selectPredictors({'X1', 'X2', 'X3'}); page.movePredictor(3, -1);
        assert(isequal(page.MappingTable.Data(:, 3)', {'X1', 'X3', 'X2'}), '説明変数の順序を入れ替えられません。');
        page.selectPredictors({'X1', 'X2', 'X3'});
        page.selectRow(1); page.Result.showTable('評価指標');
        csv = fullfile(work, 'metrics.csv'); page.Result.exportTableTo(csv);
        exported = readtable(csv, 'VariableNamingRule', 'preserve'); assert(height(exported) >= 8, '評価指標の表を保存できません。');
        png = fullfile(work, 'chart.png'); page.Result.exportFigureTo(1, png);
        info = dir(png); assert(~isempty(info) && info.bytes > 1000, 'グラフをPNG保存できません。');
        page.ExpandButton.Value = true; page.ExpandButton.ValueChangedFcn([], []);
        assert(page.ResultGrid.RowHeight{2} == 0, 'グラフを大きく表示できません。');
        page.ExpandButton.Value = false; page.ExpandButton.ValueChangedFcn([], []);
        % 先頭に説明の行があるCSVを、ヘッダー行を変えて読み直す。
        cells = readcell(sample, 'Sheet', 'Generic', 'UseExcel', false);
        text_path = fullfile(work, 'generic_with_notes.csv');
        writecell([{'メモ', '', '', '', ''}; {'作成', '', '', '', ''}; cells], text_path);
        succeeded = page.Source.open(text_path, '', 3);
        assert(succeeded && isequal(page.Source.Data.Headers, {'X1', 'X2', 'X3', 'Y1', 'Y2'}), 'ヘッダー行を指定したCSVを読み込めません。');
        assert(page.Source.Data.RowNumbers(1) == 4, '元ファイルの行番号がずれています。');
        page.selectPredictors({'X1', 'X2'}); page.selectTargets({'Y1'}); before = numel(page.Records); page.runModeling();
        assert(numel(page.Records) > before && strcmp(page.Records{end}.Status, '成功'), 'ヘッダー行を指定したCSVで学習できません。');
        furnace = app.page('furnace'); furnace.Source.open(sample, 'Generic', 1);
        assert(~isempty(furnace.Result.validCharts()), '別のファイルを開いても、炉内補間の結果表示を保ちます。');
        furnace.ColorColumn.Value = 'Batch'; furnace.ColorColumn.ValueChangedFcn([], []);
    end
    function checkStandardEdition()
        % 通常版（配布版）では、swingperiodic と周期の探索範囲を出さない（Pro 版だけの選択肢）。
        standard_work = tempname; mkdir(standard_work); cleanup_folder = onCleanup(@() removeFolder(standard_work));
        % 実験計画の実行で進捗ダイアログを出すため、表示した状態で作る。
        standard_window = uifigure('Visible', 'on'); cleanup_standard = onCleanup(@() deleteWindow(standard_window));
        standard = AnalysisController(standard_window, 'standard', standard_work);
        standard.AlertFcn = @(text, title_text, ~) error('flow:standardAlert', '通常版の画面で %s: %s', title_text, text);
        swing = standard.page('swing');
        assert(~any(strcmp(swing.Kernels.Items, 'swingperiodic')), '通常版のカーネルに swingperiodic があります。');
        assert(isempty(fieldnames(swing.Period)), '通常版に周期の探索範囲があります。');
        assert(~any(strcmp(standard.page('settings').Fields.SwingKernel.Items, 'swingperiodic')), '通常版の設定に swingperiodic があります。');
        pro_swing = app.page('swing');
        assert(any(strcmp(pro_swing.Kernels.Items, 'swingperiodic')) && isfield(pro_swing.Period, 'Wavelength'), 'Pro版では swingperiodic と周期の探索範囲を使えます。');
        % 拡張計画（既存の計画への追加）は Pro 版だけ。
        design = standard.page('doe');
        assert(~any(contains(design.Method.Items, '拡張')) && isempty(design.ExistingPanel), '通常版に拡張計画があります。');
        design.Method.Value = design.Method.Items{1}; design.run();
        assert(~isempty(design.Result.tableData(design.TABLE_DESIGN)), '通常版で実験計画を作れません。');
        assert(any(contains(app.page('doe').Method.Items, '拡張')), 'Pro版では拡張計画を選べます。');
        % Help は版ごとの内容。通常版には Pro 版だけの用語と、作成担当者向け手順書のボタンを出さない。
        standard_terms = findobj(standard.page('help').Body, 'Type', 'uitable').Data(:, 1);
        pro_terms = findobj(app.page('help').Body, 'Type', 'uitable').Data(:, 1);
        assert(~any(ismember({'swingperiodic', '拡張実験計画', '近似残差'}, standard_terms)), '通常版の Help に Pro 版だけの用語があります。');
        assert(all(ismember({'swingperiodic', '拡張実験計画', '近似残差'}, pro_terms)), 'Pro版の Help に Pro 版の用語がありません。');
        assert(~any(ismember({'EBM（GA2M）', 'ワードクラウド', '主成分分析（PCA）'}, standard_terms)), '通常版の Help に Pro 版の新しい用語があります。');
        assert(all(ismember({'EBM（GA2M）', 'ワードクラウド', '計画の評価指標', 'データの傾向（グラフ）'}, pro_terms)), 'Pro版の Help に新しい用語がありません。');
        % ワードクラウドは Pro 版だけ。通常版では設定・Help の番号を詰める。
        assert(~any(strcmp(standard.Navigation.Keys, 'words')), '通常版のメニューにワードクラウドがあります。');
        settings_button = standard.Navigation.Buttons{strcmp(standard.Navigation.Keys, 'settings')};
        assert(strcmp(settings_button.Text, '7 設定'), '通常版の設定の番号が違います: %s', settings_button.Text);
        assert(~any(ismember({'sobol', 'causal', 'bayes', 'shap'}, standard.Navigation.Keys)), '通常版のメニューに Pro 版の画面か古い SHAP 解析の画面があります。');
        standard_generic = standard.page('generic');
        assert(~any(strcmp(standard_generic.Kernels.Items, 'additive')) && isempty(standard_generic.Qualitative), '通常版に加法カーネルか質的変数の欄があります。');
        % データのグラフは単変量の傾向だけ、汎用回帰は5方式（木の本数欄あり、ハイパーパラメータ欄なし）。
        explorer = standard.page('apc').Explorer;
        assert(isequal(explorer.Kind.ItemsData, {'trend'}), '通常版のグラフに Pro 版の種類があります。');
        generic = standard.page('generic');
        assert(isequal(fieldnames(generic.Regressors)', {'gpr', 'linear', 'pls', 'forest', 'bagging'}) && isempty(generic.Hyper) && ~isempty(generic.TreeCount), ...
            '通常版の汎用回帰に Pro 版の方式があります。');
        standard_buttons = {findobj(standard.page('help').Body, 'Type', 'uibutton').Text};
        assert(~any(contains(standard_buttons, {'ビルド・利用手順書', 'daugment'})), '通常版の Help に Pro 版の案内があります。');
    end
    function checkValidation()
        app.selectPage('generic'); page = app.page('generic');
        page.selectPredictors({'X1', 'Y1'}); page.selectTargets({'Y1'});
        % 確認ボタンはなく、実行時に自動で確認して、分かる言葉で止める。
        before = numel(page.Records);
        expectAlert(@() page.runModeling(), '目的変数を説明変数に含めることはできません');
        assert(numel(page.Records) == before, '確認で止まったときは学習しません。');
        assert(isequal(page.Steps.SelectedTab, page.StepTabs.Variables), '確認で止まったときは「② 変数を選ぶ」を開きます。');
        page.selectPredictors({'X1'}); page.selectTargets({});
        assert(contains(page.SelectionState.Text, '目的変数と説明変数を選んでください'), '選択の状態を表示していません: %s', page.SelectionState.Text);
        expectAlert(@() page.runModeling(), '目的変数');
        swing = app.page('swing'); swing.setSwingVariables(swing.MODE_WITH, 'RESIST_TH', {});
        expectAlert(@() swing.runModeling(), '下地あり');
        predict_page = app.page('predict'); predict_page.openModel(apc_path); predict_page.Source.open(sample, 'Predict_SHAP', 1);
        predict_page.Mapper.select({'SIN_TH', 'SIN_TH', 'NSG_TH', 'RESIST_TH'});
        expectAlert(@() predict_page.run(), '同じ入力列');
        furnace = app.page('furnace'); furnace.Source.open(sample, 'Furnace', 1); furnace.Wafer.Value = furnace.NONE; furnace.Wafer.ValueChangedFcn([], []);
        expectAlert(@() furnace.run(), 'WaferId');
    end
end

function value = ternary(condition, when_true, when_false)
if condition, value = when_true; else, value = when_false; end
end
function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
function deleteWindow(window)
if isvalid(window), delete(window); end
end
