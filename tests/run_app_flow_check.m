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
apc_path = fullfile(work, 'Train_Model_CD_X.mat');

step('起動とホーム画面', @() app.selectPage('home'));
step('APC：2カーネルの交差検証・SHAP・保存', @checkApc);
step('Swing Curve：下地あり', @checkSwingWithBase);
step('Swing Curve：下地なし・周期カーネル', @checkSwingPeriodic);
step('汎用回帰：GPR・重回帰・PLSの比較と保存', @checkGeneric);
step('炉内補間：2Run・6方式・保存', @checkFurnace);
step('保存モデルで推定：評価つき', @checkPredict);
step('SHAP解析：起動中のモデルを使用', @checkShapPage);
step('実験計画：D最適・I最適・直交表・拡張', @checkDesign);
step('ワードクラウド', @checkWords);
step('設定：テーマ変更で結果が消えない', @checkSettings);
step('Help', @() app.selectPage('help'));
step('細かい操作：並べ替え・書出し・CSV・ヘッダー行', @checkDetails);
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
        page.selectTargets({'CD_X'}); page.confirm(); assert(page.Confirmed, '列対応を確認できません。');
        page.Kernels.Value = {'squaredexponential', 'matern52'}; page.runModeling();
        assert(numel(page.Records) == 2, 'モデルが2個できていません。');
        for index = 1:2
            record = page.Records{index};
            assert(strcmp(record.Status, '成功'), 'APC学習の失敗: %s', record.Note);
            assert(strcmp(record.Scope, '5分割交差検証'), '2条件では交差検証で評価します。');
            assert(strcmp(record.ShapStatus, '成功'), 'SHAPの失敗: %s', record.Note);
            assert(isequal(record.Model.PredictorNames, app.Constants.PREDICTOR_NAMES), '説明変数の名前・順序が仕様と違います。');
        end
        assert(page.SelectedRow >= 1 && ~isempty(page.Result.validCharts()), '結果のグラフが表示されていません。');
        report = page.saveSelectedTo(apc_path);
        assert(report.Success, '保存後検証に失敗しました。');
        variables = whos('-file', apc_path); assert(isequal({variables.name}, {'Train_Model'}), 'MATの変数が Train_Model だけではありません。');
        page.ComputeShap.Value = false; page.Kernels.Value = {'squaredexponential'}; page.selectTargets({'CD_X', 'CD_Y'});
        page.confirm(); page.runModeling();
        assert(numel(page.Records) == 4, '以前の結果を残したまま、2モデルを追加します。');
        assert(strcmp(page.Records{3}.Scope, '学習データ') && strcmp(page.Records{3}.ShapStatus, '未計算'), '1条件・SHAPなしの条件が反映されていません。');
        page.selectRow(3); page.computeShapForSelected();
        assert(strcmp(page.Records{3}.ShapStatus, '成功'), '後からのSHAP計算に失敗しました。');
    end
    function checkSwingWithBase()
        app.selectPage('swing'); page = app.page('swing');
        page.openSample(); page.selectTargets({'CD_X'});
        page.setSwingVariables(page.MODE_WITH, 'RESIST_TH', {'SIN_TH', 'SIN_RN', 'NSG_TH'});
        assert(strcmp(page.Underlayers.Enable, 'on'), '下地ありで、下地の一覧を選べません。');
        mapping = page.MappingTable.Data;
        assert(isequal(mapping(:, 2)', {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'}), '下地ありの列順が違います: %s', strjoin(mapping(:, 2)', ','));
        page.confirm(); page.runModeling();
        record = page.Records{end}; assert(strcmp(record.Status, '成功'), 'Swing学習の失敗: %s', record.Note);
        assert(strcmp(record.Model.PredictorNames{end}, 'RESIST_TH') && numel(record.Model.PredictorNames) == 4, '膜厚が最後の説明変数になっていません。');
        page.setSwingVariables(page.MODE_WITH, 'RESIST_TH', {'SIN_TH'});
        mapping = page.MappingTable.Data;
        assert(isequal(mapping(:, 2)', {'SIN_TH', 'RESIST_TH'}), '下地の選択変更が対応表へ反映されていません。');
        assert(~page.Confirmed, '変数を変えたら確認をやり直します。');
    end
    function checkSwingPeriodic()
        page = app.page('swing');
        page.Source.open(sample, 'Swing_NoBase', 1); page.selectTargets({'CD_X'});
        page.setSwingVariables(page.MODE_WITHOUT, 'RESIST_TH');
        assert(strcmp(page.Underlayers.Enable, 'off'), '下地なしでは下地の一覧を使いません。');
        page.confirm(); page.Kernels.Value = {'swingperiodic'}; page.runModeling();
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
        page.Regressors.linear.Value = true; page.Regressors.pls.Value = true; page.confirm();
        page.runModeling();
        assert(numel(page.Records) == 6, '目的変数2 × 条件3 = 6モデルになりません。');
        labels = cellfun(@(record) modeling_condition_label(record.Condition), page.Records, 'UniformOutput', false);
        for index = 1:6, assert(strcmp(page.Records{index}.Status, '成功'), '%s の失敗: %s', labels{index}, page.Records{index}.Note); end
        linear = find(strcmp(labels, '重回帰'), 1); page.selectRow(linear);
        path = fullfile(work, 'GenericRegression_Model_Y1.mat'); report = page.saveSelectedTo(path);
        assert(report.Success, '重回帰モデルの保存後検証に失敗しました。');
        loaded = load_analysis_model(path); assert(isequal(loaded.PredictorNames, {'X1', 'X2', 'X3'}), '重回帰の説明変数名は列名を保持します。');
        gpr = find(~ismember(labels, {'重回帰'}) & ~startsWith(labels, 'PLS'), 1); page.selectRow(gpr);
        report = page.saveSelectedTo(fullfile(work, 'GenericGPR_Model_Y1.mat')); assert(report.Success, '汎用GPRの保存後検証に失敗しました。');
    end
    function checkFurnace()
        app.selectPage('furnace'); page = app.page('furnace');
        page.openSample();
        assert(strcmp(page.Wafer.Value, 'WaferId') && strcmp(page.Slot.Value, 'BoatSlot') && strcmp(page.Batch.Value, 'Batch'), '列の自動選択が違います。');
        assert(numel(page.Targets.Value) == 2, '膜厚・屈折率の2列を自動選択します。');
        page.confirm(); assert(page.Confirmed, '炉内補間の列を確認できません。'); page.run();
        assert(~isempty(page.Report), '炉内補間の結果がありません。');
        failed = page.Report.Comparison(page.Report.Comparison.Status ~= "成功", :);
        assert(isempty(failed), '失敗した方式: %s', strjoin(failed.Method + "=" + failed.Note, ' / '));
        report = page.saveSelectedTo(fullfile(work, 'FurnaceInterpolation_Model.mat')); assert(report.Success, '炉内モデルの保存検証に失敗しました。');
    end
    function checkPredict()
        app.selectPage('predict'); page = app.page('predict');
        page.openModel(apc_path); page.Source.open(sample, 'Predict_SHAP', 1);
        assert(isequal(page.Mapper.selection(), app.Constants.PREDICTOR_NAMES), '推定の列が自動で割り当たりません。');
        page.Actual.Value = 'CD_X'; page.confirm(); page.run();
        output = page.Result.tableData(page.TABLE_RESULT);
        assert(height(output) == size(page.Source.Data.Cells, 1) && all(isfinite(output.y_pred)), '推定結果が不正です。');
        assert(~isempty(page.Result.tableData('評価指標')), '実測列を選んだときは評価指標を表示します。');
    end
    function checkShapPage()
        app.selectPage('shap'); page = app.page('shap');
        [~, ids] = app.Models.list(); page.selectModel(ids(1));
        page.Source.open(sample, 'Predict_SHAP', 1); page.confirm(); page.run();
        output = page.Result.tableData(page.TABLE_SHAP);
        assert(width(output) == 5 && height(output) == size(page.Source.Data.Cells, 1), 'SHAP値の表が不正です。');
        assert(~isempty(page.Result.validCharts()), 'SHAPのグラフがありません。');
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
    end
    function checkWords()
        app.selectPage('words'); page = app.page('words');
        page.loadText(fullfile(root, 'samples', 'sample_wordcloud.txt')); page.run();
        assert(height(page.Result.tableData(page.TABLE_WORDS)) > 1, '単語を集計できません。');
    end
    function checkSettings()
        app.selectPage('settings'); page = app.page('settings');
        page.Fields.Theme.Value = 'ダーク'; page.Fields.FitMethod.Value = 'sd'; page.save();
        assert(strcmp(app.Settings.Theme, 'ダーク') && isfile(app.SettingsPath), '設定を保存できません。');
        modeling = app.page('apc');
        assert(numel(modeling.Records) == 4 && ~isempty(modeling.Result.validCharts()), '設定の変更で学習結果が消えました。');
        assert(contains(modeling.FitInfo.Text, 'sd'), 'Fit method の表示が更新されていません。');
        app.selectPage('apc'); drawnow; capture('ダークテーマの学習結果');
        page.Fields.Theme.Value = 'ライト'; page.Fields.FitMethod.Value = 'exact'; page.save();
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
        page.selectPredictors({'X1', 'X2'}); page.selectTargets({'Y1'}); page.confirm(); assert(page.Confirmed, 'CSVの列を確認できません。');
        furnace = app.page('furnace'); furnace.Source.open(sample, 'Generic', 1);
        assert(~isempty(furnace.Result.validCharts()), '別のファイルを開いても、炉内補間の結果表示を保ちます。');
        furnace.ColorColumn.Value = 'Batch'; furnace.ColorColumn.ValueChangedFcn([], []);
    end
    function checkValidation()
        app.selectPage('generic'); page = app.page('generic');
        page.selectPredictors({'X1', 'Y1'}); page.selectTargets({'Y1'});
        expectAlert(@() page.confirm(), '目的変数を説明変数に含めることはできません');
        page.selectPredictors({'X1'}); page.selectTargets({});
        expectAlert(@() page.confirm(), '目的変数');
        expectAlert(@() page.runModeling(), '列対応を確認');
        swing = app.page('swing'); swing.setSwingVariables(swing.MODE_WITH, 'RESIST_TH', {});
        expectAlert(@() swing.confirm(), '下地あり');
        predict_page = app.page('predict'); predict_page.Mapper.select({'SIN_TH', 'SIN_TH', 'NSG_TH', 'RESIST_TH'});
        expectAlert(@() predict_page.confirm(), '同じ入力列');
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
