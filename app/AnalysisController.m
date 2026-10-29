classdef AnalysisController < handle
    properties (SetAccess = private)
        Window
        Panels = cell(1, 7)
        LogFolder
    end
    properties (Access = private)
        Constants
        Settings
        SettingsPath
        SettingsUI
        MainTabs
    end
    methods
        function app = AnalysisController(window)
            project_root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(project_root, 'core'));
            require_r2025b();
            app.Constants = model_constants();
            app.SettingsPath = fullfile(prefdir, 'StandaloneAnalysisApp', 'settings.json');
            settings_warning = '';
            try
                app.Settings = app_settings('load', app.SettingsPath);
            catch err
                app.Settings = app_settings('defaults'); settings_warning = err.message;
            end
            app.Window = window;
            window.Name = 'スタンドアローン解析アプリ — R2025b';
            window.Position(3:4) = [1320, 860]; window.Resize = 'on'; window.AutoResizeChildren = 'off';
            app.LogFolder = fullfile(prefdir, 'StandaloneAnalysisApp', 'logs');
            tabs = uitabgroup(window, 'TabLocation', 'left'); app.MainTabs = tabs;
            titles = {'APC 学習', 'スイングカーブ学習', '汎用 GPR 学習', '保存モデルで推定', 'SHAP 解析', '実験計画作成', 'ワードクラウド'};
            kinds = {'apc', 'swing', 'generic', 'predict', 'shap', 'doe', 'words'};
            for index = 1:numel(titles)
                tab = uitab(tabs, 'Title', sprintf('%d %s', index, titles{index}));
                app.createPanel(index, tab, kinds{index});
            end
            app.createSettings(uitab(tabs, 'Title', '8 設定'));
            create_app_help(uitab(tabs, 'Title', '9 Help'), project_root);
            window.SizeChangedFcn = @(~, ~) app.resizePanels();
            app.resizePanels(); app.applyTheme();
            if ~isempty(settings_warning), app.message(1, ['設定を読めないため初期値を使用: ' settings_warning]); end
        end
    end
    methods (Access = private)
        function createPanel(app, index, tab, kind)
            state = struct('Kind', kind, 'Data', [], 'Model', [], 'Confirmed', false, ...
                'Result', table(), 'Figures', {{}}, 'FigureNames', {{}}, 'ModelPath', '');
            state.Layout = uigridlayout(tab, [1, 2]); state.Layout.ColumnWidth = {380, '1x'};
            controls = uigridlayout(state.Layout, [14, 1], 'Scrollable', 'on');
            controls.Layout.Row = 1; controls.Layout.Column = 1;
            controls.RowHeight = {42, 30, 50, 30, 76, 30, 32, 180, 32, 32, 32, 24, 34, 120}; state.Controls = controls;
            uilabel(controls, 'Text', '列の順序・割当を確認して実行してください。', 'WordWrap', 'on');
            state.Load = uibutton(controls, 'Text', 'Excel / CSV を開く', 'ButtonPushedFcn', @(~, ~) app.loadData(index));
            state.Source = uilabel(controls, 'Text', '入力ファイル未選択', 'WordWrap', 'on');
            state.LoadModel = uibutton(controls, 'Text', '学習済み MAT を開く', 'ButtonPushedFcn', @(~, ~) app.loadModel(index));
            state.ModelInfo = uitextarea(controls, 'Editable', 'off', 'Value', {'BasisFunction: constant（固定）'});
            state.Mode = uidropdown(controls, 'Items', {'通常'}, 'ValueChangedFcn', @(~, ~) app.updateMapping(index));
            options = uigridlayout(controls, [1, 2]); options.Padding = [0, 0, 0, 0];
            state.Kernel = uidropdown(options, 'Items', app.Constants.KERNELS, 'Value', app.Settings.Kernel, 'Tooltip', 'kernel');
            state.FitMethod = uidropdown(options, 'Items', app.Constants.FIT_METHODS, 'Value', app.Settings.FitMethod, 'Tooltip', 'fit_method');
            state.Mapping = uitable(controls, 'Data', cell(0, 3), 'ColumnName', {'順序', '変数', '入力列'}, ...
                'ColumnEditable', [false, false, true], 'ColumnWidth', {42, 110, 'auto'}, 'CellEditCallback', @(~, ~) app.invalidate(index));
            state.Actual = app.choiceRow(controls, '評価用の実測列（任意）', {'(実測値なし)'});
            state.Actual.ValueChangedFcn = @(~, ~) app.invalidate(index);
            state.Bins = app.numberRow(controls, 'KL / MI ビン数（0=自動）', app.Settings.Bins, [0, 1000]);
            state.Bins.ValueChangedFcn = @(~, ~) app.invalidate(index);
            state.Confirm = uibutton(controls, 'Text', '上表の列対応・順序を確認', 'ButtonPushedFcn', @(~, ~) app.confirmMapping(index));
            state.IsPlot = uicheckbox(controls, 'Text', 'SHAP グラフをアプリ内に表示', 'Value', app.Settings.ShowPlots);
            state.Run = uibutton(controls, 'Text', '実行', 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.run(index));
            state.Messages = uitextarea(controls, 'Editable', 'off', 'Value', {'実行待ち'});
            state.Right = uigridlayout(state.Layout, [3, 1]); state.Right.Layout.Row = 1; state.Right.Layout.Column = 2;
            state.Right.RowHeight = {62, '1x', 34};
            state.Headline = uilabel(state.Right, 'Text', 'RMSE: —    R²: —', 'WordWrap', 'on', 'FontWeight', 'bold');
            state.Views = uitabgroup(state.Right);
            state.Results = app.tableTab(state.Views, '結果'); state.Preview = app.tableTab(state.Views, '入力プレビュー');
            state.Metrics = app.tableTab(state.Views, 'モデル評価'); state.Summary = app.tableTab(state.Views, '列の要約');
            chart_tab = uitab(state.Views, 'Title', 'グラフ'); chart_grid = uigridlayout(chart_tab, [1, 1]);
            state.ChartTabs = uitabgroup(chart_grid); state.Verification = app.tableTab(state.Views, '保存後検証');
            state.BaseTabs = state.Views.Children;
            export_bar = uigridlayout(state.Right, [1, 2]); export_bar.Padding = [0, 0, 0, 0];
            uibutton(export_bar, 'Text', '表示中の表を保存', 'ButtonPushedFcn', @(~, ~) app.exportResult(index));
            uibutton(export_bar, 'Text', 'グラフを PNG に保存', 'ButtonPushedFcn', @(~, ~) app.exportFigure(index));
            if ~any(strcmp(kind, {'predict', 'shap'}))
                state.LoadModel.Visible = 'off'; controls.RowHeight{4} = 0;
                state.Actual.Parent.Visible = 'off'; controls.RowHeight{9} = 0;
            end
            state.Mode.Visible = 'off'; controls.RowHeight{6} = 0;
            if ~any(strcmp(kind, {'apc', 'swing', 'shap'})), state.IsPlot.Visible = 'off'; controls.RowHeight{12} = 0; end
            if strcmp(kind, 'swing')
                state.IsPlot.Text = '学習後にSHAP・スイング近似を計算'; state.IsPlot.Value = false;
                state.IsPlot.Tooltip = '保存・検証後に先頭最大1000行でSHAPを計算します。処理時間が増えます。';
            end
            if strcmp(kind, 'generic')
                delete(state.Mode); controls.RowHeight{6} = 32;
                state.InputCount = app.numberRow(controls, '説明変数の数', app.Settings.InputCount, [1, 100]);
                state.InputCount.Parent.Layout.Row = 6;
                state.InputCount.ValueChangedFcn = @(~, ~) app.updateMapping(index);
            elseif strcmp(kind, 'predict')
                state.Mode.Visible = 'on'; controls.RowHeight{6} = 30; state.Mode.Items = {'汎用推定', '面内推定（既存モデル）'};
            elseif strcmp(kind, 'shap')
                state.Mode.Visible = 'on'; controls.RowHeight{6} = 30; state.Mode.Items = {'SHAP依存確認', 'ノイズ除去用SHAP'};
            end
            if ~any(strcmp(kind, {'apc', 'swing', 'generic'}))
                options.Visible = 'off'; controls.RowHeight{7} = 0;
            else
                state.Kernel.ValueChangedFcn = @(~, ~) app.invalidate(index);
                state.FitMethod.ValueChangedFcn = @(~, ~) app.invalidate(index);
            end
            if any(strcmp(kind, {'doe', 'words'}))
                delete(controls.Children);
                if strcmp(kind, 'doe')
                    controls.RowHeight = {56, 32, 32, 32, 32, 32, 32, 32, 44, 140, 30, 34, 110};
                    uilabel(controls, 'Text', '符号化範囲 −1〜1。拡張では既存点を固定します。直交表の実験数は自動です。', 'WordWrap', 'on');
                    state.Method = app.choiceRow(controls, '方式', {'D最適', 'I最適', '直交表', '拡張 D最適', '拡張 I最適'});
                    state.DesignModel = app.choiceRow(controls, '評価モデル', {'quadratic', 'interaction', 'linear'});
                    state.Factors = app.numberRow(controls, '因子数', app.Settings.Factors, [1, 8]);
                    state.Factors.ValueChangedFcn = @(~, ~) app.updateMapping(index);
                    state.Runs = app.numberRow(controls, '実験数（拡張時は追加数）', app.Settings.Runs, [1, 300]);
                    state.Levels = app.choiceRow(controls, '直交表の水準数', {'2', '3'});
                    state.Seed = app.numberRow(controls, '乱数 seed', app.Settings.Seed, [0, 2^32 - 1]);
                    parameters = {state.Method, state.DesignModel, state.Runs, state.Levels, state.Seed};
                    for parameter = 1:numel(parameters)
                        parameters{parameter}.ValueChangedFcn = @(~, ~) app.invalidate(index);
                    end
                    state.Load = uibutton(controls, 'Text', '既存計画 Excel / CSV を開く', 'ButtonPushedFcn', @(~, ~) app.loadData(index));
                    state.Source = uilabel(controls, 'Text', '既存計画未選択', 'WordWrap', 'on');
                    state.Mapping = uitable(controls, 'Data', cell(0, 3), 'ColumnName', {'順序', '因子', '入力列'}, ...
                        'ColumnEditable', [false, false, true], 'CellEditCallback', @(~, ~) app.invalidate(index));
                    uibutton(controls, 'Text', '既存計画を解除', 'ButtonPushedFcn', @(~, ~) app.clearDesign(index));
                else
                    controls.RowHeight = {56, 32, 260, 34, 110};
                    uilabel(controls, 'Text', '日本語は空白で区切ります。1文字以下の単語は除外します。', 'WordWrap', 'on');
                    uibutton(controls, 'Text', 'テキストファイルを開く', 'ButtonPushedFcn', @(~, ~) app.loadText(index));
                    state.Text = uitextarea(controls, 'Value', {'MATLAB analysis MATLAB model'});
                end
                state.Run = uibutton(controls, 'Text', '実行', 'ButtonPushedFcn', @(~, ~) app.run(index));
                state.Messages = uitextarea(controls, 'Editable', 'off', 'Value', {'実行待ち'});
                state.Headline.Text = '結果とグラフをこの画面内に表示します。';
            end
            app.Panels{index} = state;
        end

        function view = tableTab(~, parent, title_text)
            tab = uitab(parent, 'Title', title_text); layout = uigridlayout(tab, [1, 1]); view = uitable(layout, 'Data', table());
        end
        function field = numberRow(~, parent, label, value, limits)
            row = uigridlayout(parent, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {'1.4x', '1x'};
            uilabel(row, 'Text', label); field = uieditfield(row, 'numeric', 'Value', value, 'Limits', limits, 'RoundFractionalValues', 'on');
        end
        function field = choiceRow(~, parent, label, items)
            row = uigridlayout(parent, [1, 2]); row.Padding = [0, 0, 0, 0];
            uilabel(row, 'Text', label); field = uidropdown(row, 'Items', items);
        end
        function resizePanels(app)
            % 最上位のコンテナーは明示して伸縮し、各タブ内はグリッドに任せる。
            app.MainTabs.Position = [10, 10, max(1, app.Window.Position(3) - 20), max(1, app.Window.Position(4) - 20)];
            for index = 1:numel(app.Panels)
                state = app.Panels{index}; if isempty(state), continue; end
                if app.Window.Position(3) < 1100
                    state.Controls.Layout.Row = 1; state.Controls.Layout.Column = 1;
                    state.Right.Layout.Row = 2; state.Right.Layout.Column = 1;
                    state.Layout.ColumnWidth = {'1x'}; state.Layout.RowHeight = {280, '1x'};
                else
                    state.Layout.ColumnWidth = {380, '1x'};
                    state.Controls.Layout.Row = 1; state.Controls.Layout.Column = 1;
                    state.Right.Layout.Row = 1; state.Right.Layout.Column = 2;
                    state.Layout.RowHeight = {'1x'};
                end
            end
        end
        function loadData(app, index)
            try
                [name, folder] = uigetfile({'*.xlsx;*.csv', 'Excel / CSV'}, '入力ファイル', app.Settings.SaveFolder);
                if isequal(name, 0), return; end
                path = fullfile(folder, name); [~, ~, extension] = fileparts(name); sheet = 1;
                if strcmpi(extension, '.xlsx')
                    sheets = sheetnames(path);
                    [choice, accepted] = listdlg('ListString', cellstr(sheets), 'SelectionMode', 'single', 'PromptString', 'シートを選択');
                    if ~accepted, return; end
                    sheet = char(sheets(choice));
                end
                answer = inputdlg('ヘッダーの行番号', '入力設定', 1, {'1'}); if isempty(answer), return; end
                data = read_input_data(path, sheet, str2double(answer{1})); state = app.Panels{index}; state.Data = data;
                state.Source.Text = sprintf('%s / %d 件', name, size(data.Cells, 1));
                preview = data.Cells(1:min(100, size(data.Cells, 1)), :);
                for item = 1:numel(preview)
                    value = preview{item};
                    if isempty(value) || (isscalar(value) && ismissing(value)), preview{item} = '';
                    elseif ~(ischar(value) || (isnumeric(value) && isscalar(value))), preview{item} = char(string(value)); end
                end
                state.Preview.Data = preview; state.Preview.ColumnName = data.Headers;
                if any(strcmp(state.Kind, {'predict', 'shap'}))
                    state.Actual.Items = [{'(実測値なし)'}, data.Headers]; state.Actual.Value = '(実測値なし)';
                end
                app.Panels{index} = state; app.updateMapping(index);
            catch err
                app.showError(index, err);
            end
        end
        function loadModel(app, index)
            try
                [name, folder] = uigetfile({'*.mat', '学習済みモデル'}, 'モデルを選択', app.Settings.SaveFolder);
                if isequal(name, 0), return; end
                state = app.Panels{index}; state.Model = load_train_model(fullfile(folder, name)); state.ModelPath = fullfile(folder, name);
                state.ModelInfo.Value = {['PredictorNames: ' strjoin(state.Model.PredictorNames, ', ')]; ...
                    ['ResponseName: ' state.Model.ResponseName]; ['MAT: ' name]};
                app.Panels{index} = state; app.updateMapping(index);
            catch err
                app.showError(index, err);
            end
        end
        function updateMapping(app, index)
            state = app.Panels{index}; roles = {}; positional = false;
            switch state.Kind
                case {'apc', 'swing'}, roles = [app.Constants.PREDICTOR_NAMES, {'y'}];
                case 'generic', roles = [cellstr("入力" + string(1:state.InputCount.Value)), {'y'}]; positional = true;
                case 'doe', roles = cellstr("F" + string(1:state.Factors.Value)); positional = true;
                case {'predict', 'shap'}
                    if ~isempty(state.Model)
                        roles = state.Model.PredictorNames;
                        if startsWith(state.Mode.Value, '面内推定'), roles = {'X', 'Y'}; end
                        if strcmp(state.Mode.Value, 'ノイズ除去用SHAP'), roles = app.Constants.PREDICTOR_NAMES; end
                    end
            end
            if ~isempty(state.Data)
                mapping = cell(numel(roles), 3);
                for row = 1:numel(roles)
                    selected = '(未選択)';
                    if any(strcmp(state.Data.Headers, roles{row})), selected = roles{row};
                    elseif positional && row <= numel(state.Data.Headers), selected = state.Data.Headers{row}; end
                    mapping(row, :) = {row, roles{row}, selected};
                end
                state.Mapping.Data = mapping; state.Mapping.ColumnFormat = {'numeric', 'char', [{'(未選択)'}, state.Data.Headers]};
            end
            app.Panels{index} = state; app.invalidate(index);
        end
        function invalidate(app, index)
            state = app.Panels{index}; state.Confirmed = false; app.Panels{index} = state; app.clearOutput(index);
            if strcmp(state.Kind, 'doe')
                app.message(index, '設定・列対応を変更しました。内容を確認して再実行してください。');
            else
                app.message(index, '列対応が未確認です。対応表を確認してください。');
            end
        end
        function clearOutput(app, index)
            state = app.Panels{index}; state.Result = table(); state.Figures = {}; state.FigureNames = {};
            state.Results.Data = table(); state.Metrics.Data = table(); state.Summary.Data = table(); state.Verification.Data = table();
            delete(state.ChartTabs.Children);
            extra = state.Views.Children(~ismember(state.Views.Children, state.BaseTabs)); delete(extra);
            state.Headline.Text = 'RMSE: —    R²: —'; app.Panels{index} = state;
        end
        function matrix = mappedInput(~, state)
            if isempty(state.Data), error('AnalysisApp:noInput', '入力ファイルを選択してください。'); end
            mapping = state.Mapping.Data;
            if isempty(mapping), error('AnalysisApp:noMapping', 'モデルを読み込み、列を割り当ててください。'); end
            matrix = assign_required_columns(state.Data, mapping(:, 2), mapping(:, 3));
            if any(strcmp(state.Kind, {'predict', 'shap'})) && ~strcmp(state.Actual.Value, '(実測値なし)')
                if any(strcmp(mapping(:, 3), state.Actual.Value)), error('AnalysisApp:responseLeak', '実測値に説明変数と同じ列は指定できません。'); end
                extract_numeric_columns(state.Data, {state.Actual.Value});
            end
        end
        function confirmMapping(app, index)
            try
                state = app.Panels{index}; app.mappedInput(state);
                if any(strcmp(state.Kind, {'predict', 'shap'})) && isempty(state.Model), error('AnalysisApp:noModel', 'モデルを選択してください。'); end
                state.Confirmed = true; app.Panels{index} = state; app.message(index, '列対応・順序を確認済みです。実行できます。');
            catch err
                app.showError(index, err);
            end
        end
        function run(app, index)
            state = app.Panels{index}; state.Run.Enable = 'off'; cleanup = onCleanup(@() set(state.Run, 'Enable', 'on'));
            try
                if ~any(strcmp(state.Kind, {'doe', 'words'})) && ~state.Confirmed, error('AnalysisApp:unconfirmed', '列対応・順序の確認ボタンを押してください。'); end
                if ~any(strcmp(state.Kind, {'doe', 'words'})) && state.Bins.Value > 0
                    validate_bin_count(state.Bins.Value, 'AnalysisApp');
                end
                app.clearOutput(index); state.Messages.Value = {'処理中'}; drawnow;
                if any(strcmp(state.Kind, {'apc', 'swing', 'generic'})), app.trainAndSave(index);
                elseif strcmp(state.Kind, 'doe'), app.runDesign(index);
                elseif strcmp(state.Kind, 'words')
                    [words, counts] = create_wordCloud(strjoin(string(state.Text.Value), newline));
                    app.result(index, table(words, counts, 'VariableNames', {'Word', 'Count'}));
                    tab = uitab(state.ChartTabs, 'Title', 'Word Cloud'); layout = uigridlayout(tab, [1, 1]);
                    chart = wordcloud(layout, words, counts); chart.Title = 'Word Cloud'; app.registerCharts(index, {chart}, {'Word Cloud'});
                    state.Headline.Text = sprintf('%d種類の単語を集計しました。グラフは「グラフ」内で表示します。', numel(words));
                else
                    matrix = app.mappedInput(state);
                    if strcmp(state.Kind, 'predict')
                        if startsWith(state.Mode.Value, '面内推定')
                            [prediction, outside, warnings] = predict_in_plane(state.Model, matrix); app.showWarnings(index, warnings);
                            output = table(state.Data.RowNumbers, prediction, outside, 'VariableNames', {'SourceRow', 'y_pred', 'OutsideTrainingRange'});
                        else
                            prediction = predict(state.Model, format_model_input(state.Model, matrix));
                            output = table(state.Data.RowNumbers, prediction, 'VariableNames', {'SourceRow', 'y_pred'});
                        end
                        app.result(index, output);
                    else
                        prediction = predict(state.Model, format_model_input(state.Model, matrix)); app.runShap(index, state.Model, matrix, false);
                    end
                    app.evaluateImported(index, matrix, prediction);
                end
                app.applyTheme(); app.message(index, '処理を終了しました。');
            catch err
                app.showError(index, err);
            end
        end
        function trainAndSave(app, index)
            state = app.Panels{index}; started = tic; [~, name, extension] = fileparts(state.Data.FileName);
            entry = struct('Function', state.Kind, 'InputFile', [name extension], 'Rows', size(state.Data.Cells, 1), ...
                'Kernel', state.Kernel.Value, 'FitMethod', state.FitMethod.Value, 'SavePath', '', ...
                'Verification', [], 'PredictorNames', {{}}, 'ResponseName', '', 'Status', 'started');
            try
                matrix = app.mappedInput(state); X = matrix(:, 1:end - 1); y = matrix(:, end);
                kernel = state.Kernel.Value; fit_method = state.FitMethod.Value;
                switch state.Kind
                    case 'apc', [model, warnings] = train_apc_model(X, y, state.IsPlot.Value, kernel, fit_method);
                    case 'swing', [model, warnings] = train_swing_curve_model(X(:, 1:3), X(:, 4), y, kernel, fit_method);
                    case 'generic', [model, warnings] = train_generic_gpr_model(X, y, kernel, fit_method);
                end
                entry.PredictorNames = model.PredictorNames; entry.ResponseName = model.ResponseName; app.showWarnings(index, warnings);
                prediction = predict(model, format_model_input(model, X));
                app.displayEvaluation(index, X, y, prediction, '学習データへの当てはまり（汎化性能ではありません）');
                app.result(index, table(state.Data.RowNumbers, y, prediction, y - prediction, 'VariableNames', {'SourceRow', 'Actual', 'Predicted', 'Residual'}));
                [name, folder] = uiputfile('*.mat', '学習済みモデルを保存', fullfile(app.Settings.SaveFolder, 'Train_Model.mat'));
                if isequal(name, 0)
                    entry.Status = 'save_cancelled'; entry.ElapsedSeconds = toc(started); app.logTraining(index, entry);
                    app.message(index, '保存をキャンセルしました。評価結果は表示します。後続 SHAP は行いません。'); return;
                end
                entry.SavePath = fullfile(folder, name); save_train_model(model, entry.SavePath);
                expected = struct('KernelFunction', kernel, 'FitMethod', fit_method, 'BasisFunction', 'constant', 'NumObservations', size(X, 1));
                report = verify_saved_model(entry.SavePath, model, state.Kind, expected);
                state.Verification.Data = report.Checks; entry.Verification = table2struct(report.Checks); app.message(index, report.Message);
                if ~report.Success, error('AnalysisApp:verificationFailed', '%s', app.Constants.INVALID_MODEL_MESSAGE); end
                if strcmp(state.Kind, 'apc') || (strcmp(state.Kind, 'swing') && state.IsPlot.Value)
                    app.runShap(index, model, X, true);
                end
                entry.Status = 'completed';
            catch err
                entry.Status = ['failed:' err.identifier]; entry.ElapsedSeconds = toc(started); app.logTraining(index, entry); rethrow(err);
            end
            entry.ElapsedSeconds = toc(started); app.logTraining(index, entry);
        end
        function evaluateImported(app, index, matrix, prediction)
            state = app.Panels{index};
            if ~strcmp(state.Actual.Value, '(実測値なし)')
                actual = extract_numeric_columns(state.Data, {state.Actual.Value});
                app.displayEvaluation(index, matrix, actual, prediction, '読込データで評価（学習に未使用かは利用者が確認）');
            elseif size(matrix, 1) >= 2
                names = [string(state.Mapping.Data(:, 2))', "Predicted"];
                state.Summary.Data = summarize_model_columns([matrix, prediction], names);
                state.Headline.Text = '実測値列なし：RMSE・R² は未計算。入力と予測値の要約を表示します。';
            else
                state.Headline.Text = '1件の推定結果です。評価・要約には2件以上が必要です。';
            end
        end
        function displayEvaluation(app, index, inputs, actual, predicted, scope)
            state = app.Panels{index};
            if numel(actual) < 2, state.Headline.Text = '評価には実測値が2件以上必要です。'; return; end
            metrics = evaluate_predictions(actual, predicted, state.Bins.Value); state.Metrics.Data = metrics;
            state.Headline.Text = sprintf('RMSE: %.6g    R²: %.6g    n = %d\n%s', metrics.Value(2), metrics.Value(1), numel(actual), scope);
            names = [string(state.Mapping.Data(1:size(inputs, 2), 2))', "Actual", "Predicted", "Residual"];
            state.Summary.Data = summarize_model_columns([inputs, actual, predicted, actual - predicted], names);
            tab = uitab(state.ChartTabs, 'Title', '実測値と予測値'); layout = uigridlayout(tab, [1, 1]); ax = uiaxes(layout);
            scatter(ax, actual, predicted, 20, 'filled'); hold(ax, 'on'); limits = [min([actual; predicted]), max([actual; predicted])];
            plot(ax, limits, limits, '--'); xlabel(ax, 'Actual'); ylabel(ax, 'Predicted'); title(ax, '実測値と予測値');
            tab = uitab(state.ChartTabs, 'Title', '残差'); layout = uigridlayout(tab, [1, 1]); residual_ax = uiaxes(layout);
            scatter(residual_ax, predicted, actual - predicted, 20, 'filled'); yline(residual_ax, 0, '--');
            xlabel(residual_ax, 'Predicted'); ylabel(residual_ax, 'Actual - Predicted'); title(residual_ax, '残差');
            app.registerCharts(index, {ax, residual_ax}, {'実測値と予測値', '残差'});
        end
        function runShap(app, index, model, matrix, is_training)
            state = app.Panels{index};
            if is_training && size(matrix, 1) > app.Constants.MAX_SHAP_POINTS
                app.message(index, 'SHAP は先頭1000件まで計算します。評価指標は全件で計算しています。'); matrix = matrix(1:app.Constants.MAX_SHAP_POINTS, :);
            end
            progress = uiprogressdlg(app.Window, 'Title', 'SHAP 解析', 'Message', 'SHAP 値を計算中', 'Indeterminate', 'on');
            cleanup = onCleanup(@() close(progress)); drawnow;
            if ~is_training && strcmp(state.Mode.Value, 'ノイズ除去用SHAP')
                [resist, ~, shap_all] = denoise_for_swing_curve(model, matrix(:, 1:3), matrix(:, 4));
                output = table(state.Data.RowNumbers, resist, 'VariableNames', {'SourceRow', 'shap_resist'});
            else
                [~, shap_all] = calc_shap_dependence(model, matrix);
                output = array2table(shap_all, 'VariableNames', model.PredictorNames);
                output = addvars(output, state.Data.RowNumbers(1:size(shap_all, 1)), 'Before', 1, 'NewVariableNames', 'SourceRow');
            end
            if is_training
                view = app.tableTab(state.Views, 'SHAP 値'); view.Data = output;
            else
                app.result(index, output);
            end
            clear cleanup;
            if state.IsPlot.Value
                [charts, names] = plot_shap_figures(state.ChartTabs, shap_all, matrix, model.PredictorNames); app.registerCharts(index, charts, names);
            end
        end
        function runDesign(app, index)
            state = app.Panels{index}; existing = zeros(0, state.Factors.Value);
            if startsWith(state.Method.Value, '拡張')
                existing = app.mappedInput(state);
            elseif ~isempty(state.Data)
                app.message(index, '通常の作成では既存点を使いません。固定する場合は拡張を選択してください。');
            end
            if contains(state.Method.Value, 'D最適')
                method = 'D';
            elseif contains(state.Method.Value, 'I最適')
                method = 'I';
            else
                method = 'orthogonal';
            end
            progress = uiprogressdlg(app.Window, 'Title', '実験計画作成', 'Message', '計画を探索中', 'Indeterminate', 'on');
            cleanup = onCleanup(@() close(progress)); drawnow;
            [design, details] = create_experiment_design(method, state.Factors.Value, state.Runs.Value, state.Seed.Value, ...
                state.DesignModel.Value, str2double(state.Levels.Value), existing);
            output = array2table(design, 'VariableNames', cellstr("F" + string(1:size(design, 2))));
            kind = repmat("追加", size(design, 1), 1); kind(1:details.FixedRows) = "既存";
            output = addvars(output, (1:size(design, 1))', kind, 'Before', 1, 'NewVariableNames', {'Run', 'Type'}); app.result(index, output);
            report = design_diagnostics(design, state.DesignModel.Value);
            state.Headline.Text = sprintf('実験数 %d（既存 %d＋追加 %d）/ 選択モデルのランク %d / %d 項', ...
                size(design, 1), details.FixedRows, details.AddedRows, report.Rank, report.Terms);
            if report.Rank < report.Terms, app.message(index, 'ランク不足です。すべての係数を独立に推定できません。'); end
            view = app.tableTab(state.Views, '交絡の線形関係');
            view.Data = array2table(report.Dependencies, 'RowNames', cellstr(report.Names)); view.RowName = cellstr(report.Names);
            tab = uitab(state.ChartTabs, 'Title', '交絡の可視化'); layout = uigridlayout(tab, [1, 1]); ax = uiaxes(layout);
            image = imagesc(ax, report.Similarity, [0, 1]); image.AlphaData = isfinite(report.Similarity);
            colorbar(ax); ax.XTick = 1:numel(report.Names); ax.YTick = ax.XTick;
            ax.XTickLabel = report.Names; ax.YTickLabel = report.Names; ax.XTickLabelRotation = 60; ax.TickLabelInterpreter = 'none';
            title(ax, sprintf('二次モデル項の |cosθ| / ランク %d / %d', report.FullRank, report.FullTerms));
            app.registerCharts(index, {ax}, {'交絡の可視化'});
            app.message(index, sprintf('seed=%d、基準値=%g。D/I は局所探索で、最適性の保証はありません。', details.Seed, details.Criterion));
            app.message(index, '対角線以外の1は2項の完全交絡。0列は空白。複数項の依存は「交絡の線形関係」の各列で確認（係数の加重和=0）。');
        end
        function clearDesign(app, index)
            state = app.Panels{index}; state.Data = []; state.Mapping.Data = cell(0, 3); state.Preview.Data = table();
            state.Source.Text = '既存計画未選択'; app.Panels{index} = state; app.clearOutput(index);
        end
        function registerCharts(app, index, charts, names)
            state = app.Panels{index}; state.Figures = [state.Figures, charts(:)']; state.FigureNames = [state.FigureNames, names(:)']; app.Panels{index} = state;
        end
        function result(app, index, output)
            state = app.Panels{index}; state.Result = output; state.Results.Data = output; app.Panels{index} = state;
        end
        function message(app, index, text)
            state = app.Panels{index}; state.Messages.Value = [status_lines(state.Messages.Value); status_lines(text)];
        end
        function showWarnings(app, index, warnings)
            if isempty(warnings), return; end
            app.message(index, warnings); uialert(app.Window, strjoin(warnings, newline), '警告', 'Icon', 'warning');
        end
        function showError(app, index, err)
            app.message(index, err.message); uialert(app.Window, err.message, '処理を中止しました', 'Icon', 'error');
        end
        function logTraining(app, index, entry)
            try
                write_training_log(app.LogFolder, entry);
            catch err
                app.message(index, ['ログ保存失敗: ' err.message]);
            end
        end
        function exportResult(app, index)
            try
                state = app.Panels{index}; data = table();
                if strcmp(state.Views.SelectedTab.Title, 'グラフ')
                    chart_tab = state.ChartTabs.SelectedTab;
                    if ~isempty(chart_tab) && isa(chart_tab.UserData, 'SwingCurveView'), data = chart_tab.UserData.currentTable(); end
                else
                    view = findobj(state.Views.SelectedTab, 'Type', 'uitable');
                    if ~isempty(view), data = view(1).Data; end
                end
                if isempty(data), error('AnalysisApp:noResult', '結果・評価・要約・スイング近似などの表を選択してください。'); end
                if strcmp(state.Views.SelectedTab.Title, '入力プレビュー'), error('AnalysisApp:preview', 'プレビューは先頭100行のみです。計算結果のタブを選択してください。'); end
                if ~istable(data), data = cell2table(data, 'VariableNames', matlab.lang.makeValidName(view(1).ColumnName)); end
                [name, folder] = uiputfile({'*.csv', 'CSV'; '*.xlsx', 'Excel'}, '表示中の表を保存', fullfile(app.Settings.SaveFolder, 'result.csv'));
                if isequal(name, 0), return; end
                writetable(data, fullfile(folder, name), 'WriteRowNames', ~isempty(data.Properties.RowNames)); app.message(index, ['保存しました: ' name]);
            catch err
                app.showError(index, err);
            end
        end
        function exportFigure(app, index)
            try
                state = app.Panels{index}; valid = cellfun(@isgraphics, state.Figures); charts = state.Figures(valid); names = state.FigureNames(valid);
                if isempty(charts), error('AnalysisApp:noChart', '保存するグラフがありません。'); end
                [choice, accepted] = listdlg('ListString', names, 'SelectionMode', 'single', 'PromptString', '保存するグラフ'); if ~accepted, return; end
                [name, folder] = uiputfile('*.png', 'グラフを保存', fullfile(app.Settings.SaveFolder, 'chart.png')); if isequal(name, 0), return; end
                state.Views.SelectedTab = state.ChartTabs.Parent.Parent;
                container = charts{choice}.Parent;
                while ~isempty(container) && ~isequal(container, app.Window)
                    if isa(container, 'matlab.ui.container.Tab'), container.Parent.SelectedTab = container; end
                    container = container.Parent;
                end
                drawnow;
                exportgraphics(charts{choice}, fullfile(folder, name), 'Resolution', 150);
            catch err
                app.showError(index, err);
            end
        end
        function loadText(app, index)
            try
                [name, folder] = uigetfile({'*.txt', 'テキスト'}, 'テキスト', app.Settings.SaveFolder); if isequal(name, 0), return; end
                state = app.Panels{index}; state.Text.Value = splitlines(string(fileread(fullfile(folder, name))));
            catch err
                app.showError(index, err);
            end
        end
        function createSettings(app, tab)
            layout = uigridlayout(tab, [13, 1], 'Scrollable', 'on'); layout.RowHeight = {48, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 36, 70};
            uilabel(layout, 'Text', '保存した設定は次回起動にも反映します。適用時は現在の評価結果と列対応の確認を解除します。', 'WordWrap', 'on');
            row = uigridlayout(layout, [1, 3]); row.ColumnWidth = {150, '1x', 100}; row.Padding = [0, 0, 0, 0];
            uilabel(row, 'Text', 'デフォルト保存先'); app.SettingsUI.SaveFolder = uieditfield(row, 'Value', app.Settings.SaveFolder);
            uibutton(row, 'Text', 'フォルダ選択', 'ButtonPushedFcn', @(~, ~) app.chooseFolder());
            app.SettingsUI.Theme = app.choiceRow(layout, 'カラーテーマ', {'ライト', 'ダーク'});
            app.SettingsUI.Kernel = app.choiceRow(layout, '既定 kernel', app.Constants.KERNELS);
            app.SettingsUI.FitMethod = app.choiceRow(layout, '既定 fit_method', app.Constants.FIT_METHODS);
            app.SettingsUI.InputCount = app.numberRow(layout, '汎用 GPR の説明変数数', app.Settings.InputCount, [1, 100]);
            app.SettingsUI.Bins = app.numberRow(layout, 'KL / MI ビン数（0=自動）', app.Settings.Bins, [0, 1000]);
            app.SettingsUI.Factors = app.numberRow(layout, '実験計画の因子数', app.Settings.Factors, [1, 8]);
            app.SettingsUI.Runs = app.numberRow(layout, '実験数 / 追加数', app.Settings.Runs, [1, 300]);
            app.SettingsUI.Seed = app.numberRow(layout, '実験計画の seed', app.Settings.Seed, [0, 2^32 - 1]);
            app.SettingsUI.ShowPlots = uicheckbox(layout, 'Text', '既定で SHAP グラフを表示', 'Value', app.Settings.ShowPlots);
            row = uigridlayout(layout, [1, 2]); row.Padding = [0, 0, 0, 0];
            uibutton(row, 'Text', '設定を保存・適用', 'ButtonPushedFcn', @(~, ~) app.saveSettings());
            uibutton(row, 'Text', '初期値を画面に戻す（保存前）', 'ButtonPushedFcn', @(~, ~) app.fillSettings(app_settings('defaults')));
            app.SettingsUI.Message = uilabel(layout, 'Text', ['設定保存先: ' app.SettingsPath], 'WordWrap', 'on'); app.fillSettings(app.Settings);
        end
        function fillSettings(app, values)
            fields = fieldnames(values);
            for index = 1:numel(fields), app.SettingsUI.(fields{index}).Value = values.(fields{index}); end
        end
        function chooseFolder(app)
            folder = uigetdir(app.SettingsUI.SaveFolder.Value, 'デフォルト保存先');
            if ~isequal(folder, 0), app.SettingsUI.SaveFolder.Value = folder; end
        end
        function saveSettings(app)
            try
                proposed = app.Settings; fields = fieldnames(proposed);
                for index = 1:numel(fields), proposed.(fields{index}) = app.SettingsUI.(fields{index}).Value; end
                app.Settings = app_settings('save', app.SettingsPath, proposed);
                for index = 1:numel(app.Panels)
                    state = app.Panels{index};
                    if any(strcmp(state.Kind, {'apc', 'swing', 'generic'})), state.Kernel.Value = app.Settings.Kernel; state.FitMethod.Value = app.Settings.FitMethod; end
                    if any(strcmp(state.Kind, {'apc', 'swing', 'generic', 'predict', 'shap'})), state.Bins.Value = app.Settings.Bins; end
                    if any(strcmp(state.Kind, {'apc', 'shap'})), state.IsPlot.Value = app.Settings.ShowPlots; end
                    if strcmp(state.Kind, 'generic'), state.InputCount.Value = app.Settings.InputCount; end
                    if strcmp(state.Kind, 'doe'), state.Factors.Value = app.Settings.Factors; state.Runs.Value = app.Settings.Runs; state.Seed.Value = app.Settings.Seed; end
                    if ~strcmp(state.Kind, 'words'), app.updateMapping(index); end
                end
                app.applyTheme(); app.SettingsUI.Message.Text = ['保存・適用しました: ' app.SettingsPath];
            catch err
                uialert(app.Window, err.message, '設定を保存できませんでした');
            end
        end
        function applyTheme(app)
            apply_app_theme(app.Window, app.Settings.Theme);
        end
    end
end
