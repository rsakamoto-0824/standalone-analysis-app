classdef AnalysisController < handle
    properties (SetAccess = private)
        Window
        Panels = cell(1, 10)
        LogFolder
    end
    properties (Access = private)
        Constants
    end
    methods
        function app = AnalysisController(window)
            project_root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(project_root, 'core'));
            require_r2025b();
            app.Constants = model_constants();
            app.Window = window;
            app.Window.Name = 'スタンドアローン解析アプリ — R2025b';
            app.Window.Position(3:4) = [1320, 860];
            app.LogFolder = fullfile(prefdir, 'StandaloneAnalysisApp', 'logs');
            root = uigridlayout(window, [1, 1]);
            tabs = uitabgroup(root, 'TabLocation', 'left');
            titles = {'1 APC 学習', '2 スイングカーブ学習', '3 面内学習・推定', ...
                '4 汎用 GPR 学習', '5 保存モデルで推定', '6 SHAP 解析', ...
                '7 評価指標', '8 列の要約統計量', '9 D 最適計画', '10 ワードクラウド'};
            kinds = {'apc', 'swing', 'in_plane', 'generic', 'predict', ...
                'shap', 'metrics', 'summary', 'doe', 'words'};
            for index = 1:numel(titles)
                tab = uitab(tabs, 'Title', titles{index});
                app.createPanel(index, tab, kinds{index});
            end
        end
    end
    methods (Access = private)
        function createPanel(app, index, tab, kind)
            layout = uigridlayout(tab, [1, 2]);
            layout.ColumnWidth = {390, '1x'};
            control_panel = uipanel(layout, 'Scrollable', 'on');
            controls = uigridlayout(control_panel, [14, 1]);
            controls.RowHeight = {36, 30, 48, 30, 60, 30, 35, 180, 30, 90, 30, 25, 34, 80};
            state = struct('Kind', kind, 'Data', [], 'TestData', [], 'Model', [], ...
                'Confirmed', false, 'Result', table(), 'Figures', {{}}, 'ModelPath', '');
            state.Description = uilabel(controls, 'Text', '列の順序と割当を確認してから実行してください。', 'WordWrap', 'on');
            state.Load = uibutton(controls, 'Text', 'Excel / CSV を開く', 'ButtonPushedFcn', @(~, ~) app.loadData(index, false));
            state.Source = uilabel(controls, 'Text', '入力ファイル未選択', 'WordWrap', 'on');
            state.LoadModel = uibutton(controls, 'Text', '学習済み MAT を開く', 'ButtonPushedFcn', @(~, ~) app.loadModel(index));
            state.ModelInfo = uitextarea(controls, 'Editable', 'off', 'Value', {'BasisFunction: constant（固定）'});
            state.Mode = uidropdown(controls, 'Items', {'通常'}, 'ValueChangedFcn', @(~, ~) app.updateMapping(index));
            options = uigridlayout(controls, [1, 2]);
            options.Padding = [0, 0, 0, 0];
            options.ColumnWidth = {'1x', '1x'};
            state.Kernel = uidropdown(options, 'Items', app.Constants.KERNELS, 'Tooltip', 'kernel');
            state.FitMethod = uidropdown(options, 'Items', app.Constants.FIT_METHODS, 'Tooltip', 'fit_method');
            state.Mapping = uitable(controls, 'Data', cell(0, 3), ...
                'ColumnName', {'順序', '変数', '入力列'}, 'ColumnEditable', [false, false, true], ...
                'ColumnWidth', {42, 125, 'auto'}, 'CellEditCallback', @(~, ~) app.invalidate(index));
            state.TestLoad = uibutton(controls, 'Text', '推定用 Excel / CSV を開く（省略可）', ...
                'ButtonPushedFcn', @(~, ~) app.loadData(index, true));
            state.TestMapping = uitable(controls, 'Data', cell(0, 3), ...
                'ColumnName', {'順序', '変数', '推定用入力列'}, 'ColumnEditable', [false, false, true], ...
                'CellEditCallback', @(~, ~) app.invalidate(index));
            state.Confirm = uibutton(controls, 'Text', '上表の列対応・順序を確認', ...
                'ButtonPushedFcn', @(~, ~) app.confirmMapping(index));
            state.IsPlot = uicheckbox(controls, 'Text', 'グラフを表示（IsPlot = 1）', 'Value', false);
            state.Run = uibutton(controls, 'Text', '実行', 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) app.run(index));
            state.Messages = uitextarea(controls, 'Editable', 'off', 'Value', {'実行待ち'});
            right = uigridlayout(layout, [5, 1]);
            right.RowHeight = {'1x', 34, 24, 180, 24};
            view_tabs = uitabgroup(right);
            result_tab = uitab(view_tabs, 'Title', '結果');
            result_grid = uigridlayout(result_tab, [1, 1]);
            state.Results = uitable(result_grid, 'Data', table());
            preview_tab = uitab(view_tabs, 'Title', '入力プレビュー');
            preview_grid = uigridlayout(preview_tab, [1, 1]);
            state.Preview = uitable(preview_grid, 'Data', cell(0, 0));
            export_bar = uigridlayout(right, [1, 2]);
            export_bar.Padding = [0, 0, 0, 0];
            uibutton(export_bar, 'Text', '結果を CSV / Excel に保存', 'ButtonPushedFcn', @(~, ~) app.exportResult(index));
            uibutton(export_bar, 'Text', 'グラフを PNG に保存', 'ButtonPushedFcn', @(~, ~) app.exportFigure(index));
            uilabel(right, 'Text', '保存後の自動検証');
            state.Verification = uitable(right, 'Data', table());
            uilabel(right, 'Text', '警告・検証結果はこの画面に残ります。', 'FontColor', [0.35, 0.35, 0.35]);
            if ~any(strcmp(kind, {'predict', 'shap'}))
                state.LoadModel.Visible = 'off';
                controls.RowHeight{4} = 0;
            end
            if ~strcmp(kind, 'in_plane')
                state.TestLoad.Visible = 'off'; state.TestMapping.Visible = 'off';
                controls.RowHeight{9} = 0; controls.RowHeight{10} = 0;
            end
            if ~any(strcmp(kind, {'apc', 'shap'}))
                state.IsPlot.Visible = 'off'; controls.RowHeight{12} = 0;
            end
            if strcmp(kind, 'generic')
                delete(state.Mode);
                state.InputCount = uieditfield(controls, 'numeric', 'Value', 4, ...
                    'Limits', [1, Inf], 'RoundFractionalValues', 'on', ...
                    'Tooltip', '説明変数の数（順序は対応表で変更）', ...
                    'ValueChangedFcn', @(~, ~) app.updateMapping(index));
                state.InputCount.Layout.Row = 6;
            elseif strcmp(kind, 'predict')
                state.Mode.Items = {'汎用推定', '面内推定'};
            elseif strcmp(kind, 'shap')
                state.Mode.Items = {'SHAP依存確認', 'ノイズ除去用SHAP'};
            elseif strcmp(kind, 'metrics')
                state.Mode.Items = {'一括（rmse / mae / r / r_squared）', 'RMSE', 'RMSPE (%)', ...
                    'MAE', 'Pearson r', 'r²（相関係数の2乗）', 'KL (nats)', '相互情報量 (bits)'};
                state.Mode.ValueChangedFcn = @(~, ~) app.invalidate(index);
                delete(options.Children);
                uilabel(options, 'Text', 'ビン数（0 = 自動）');
                state.Bins = uieditfield(options, 'numeric', 'Value', 0, 'Limits', [0, Inf], 'RoundFractionalValues', 'on');
            elseif strcmp(kind, 'summary')
                state.Mapping.Visible = 'off';
                state.Columns = uilistbox(controls, 'Items', {}, 'Multiselect', 'on', ...
                    'ValueChangedFcn', @(~, ~) app.invalidate(index));
                state.Columns.Layout.Row = 8;
                state.Description.Text = '対象列を複数選択できます。要約統計量だけは NaN を除外します。';
            end
            if ~any(strcmp(kind, app.Constants.MODEL_TYPES)) && ~strcmp(kind, 'metrics')
                options.Visible = 'off'; controls.RowHeight{7} = 0;
            end
            if any(strcmp(kind, {'doe', 'words'}))
                delete(controls.Children);
                controls.RowHeight = {48, 32, 32, 32, 32, 220, 36, 90};
                uilabel(controls, 'Text', '結果は右の表に表示します。', 'WordWrap', 'on');
                if strcmp(kind, 'doe')
                    state.Factors = app.numberRow(controls, '因子数', 3, [1, Inf]);
                    state.Runs = app.numberRow(controls, '実験数', 20, [1, Inf]);
                    seed_row = uigridlayout(controls, [1, 2]);
                    uilabel(seed_row, 'Text', 'seed（空欄 = shuffle）');
                    state.Seed = uieditfield(seed_row, 'text', 'Value', '42');
                    uilabel(controls, 'Text', '二次モデルの D 最適計画を作成します。');
                    uilabel(controls, 'Text', '因子は符号化された計画値です。');
                else
                    uibutton(controls, 'Text', 'テキストファイルを開く', 'ButtonPushedFcn', @(~, ~) app.loadText(index));
                    uilabel(controls, 'Text', '日本語は空白で区切って入力してください。');
                    uilabel(controls, 'Text', '日本語の自動分かち書きは行いません。');
                    uilabel(controls, 'Text', '1文字以下の単語は除外します。');
                    state.Text = uitextarea(controls, 'Value', {'MATLAB analysis MATLAB model'});
                end
                state.Run = uibutton(controls, 'Text', '実行', 'ButtonPushedFcn', @(~, ~) app.run(index));
                state.Messages = uitextarea(controls, 'Editable', 'off', 'Value', {'実行待ち'});
            end
            app.Panels{index} = state;
        end

        function field = numberRow(~, parent, label, value, limits)
            row = uigridlayout(parent, [1, 2]); row.Padding = [0, 0, 0, 0];
            uilabel(row, 'Text', label);
            field = uieditfield(row, 'numeric', 'Value', value, 'Limits', limits, 'RoundFractionalValues', 'on');
        end

        function loadData(app, index, is_test)
            try
                [name, folder] = uigetfile({'*.xlsx;*.csv', 'Excel / CSV'});
                if isequal(name, 0), return; end
                fullName = fullfile(folder, name);
                [~, ~, extension] = fileparts(name);
                sheet = 1;
                if strcmpi(extension, '.xlsx')
                    sheets = sheetnames(fullName);
                    [choice, accepted] = listdlg('ListString', cellstr(sheets), ...
                        'SelectionMode', 'single', 'PromptString', 'シートを選択してください');
                    if ~accepted, return; end
                    sheet = char(sheets(choice));
                end
                answer = inputdlg('ヘッダーの行番号', '入力設定', 1, {'1'});
                if isempty(answer), return; end
                data = read_input_data(fullName, sheet, str2double(answer{1}));
                state = app.Panels{index};
                if is_test
                    state.TestData = data;
                    state.TestLoad.Text = ['推定用: ' name];
                else
                    state.Data = data;
                    state.Source.Text = sprintf('%s / ヘッダー %d 行目 / %d 件', name, data.HeaderRow, size(data.Cells, 1));
                    preview = data.Cells(1:min(100, size(data.Cells, 1)), :);
                    for cell_index = 1:numel(preview)
                        value = preview{cell_index};
                        if isempty(value) || (isscalar(value) && ismissing(value))
                            preview{cell_index} = '';
                        elseif ~(ischar(value) || (isnumeric(value) && isscalar(value)) || (islogical(value) && isscalar(value)))
                            preview{cell_index} = char(string(value));
                        end
                    end
                    state.Preview.Data = preview;
                    state.Preview.ColumnName = data.Headers;
                    if strcmp(state.Kind, 'summary')
                        state.Columns.Items = data.Headers;
                        state.Columns.Value = data.Headers(1);
                    end
                end
                app.Panels{index} = state;
                app.updateMapping(index);
            catch err
                app.showError(index, err);
            end
        end

        function loadModel(app, index)
            try
                [name, folder] = uigetfile({'*.mat', '学習済みモデル'});
                if isequal(name, 0)
                    app.message(index, '学習済モデルの選択がキャンセルされました'); return;
                end
                state = app.Panels{index};
                state.Model = load_train_model(fullfile(folder, name));
                state.ModelPath = fullfile(folder, name);
                state.ModelInfo.Value = {['PredictorNames: ' strjoin(state.Model.PredictorNames, ', ')]; ...
                    ['ResponseName: ' state.Model.ResponseName]; ['MAT: ' name]};
                app.Panels{index} = state;
                app.updateMapping(index);
            catch err
                app.showError(index, err);
            end
        end

        function updateMapping(app, index)
            state = app.Panels{index};
            roles = {};
            switch state.Kind
                case {'apc', 'swing'}
                    roles = [app.Constants.PREDICTOR_NAMES, {'y'}];
                case 'in_plane'
                    roles = {'X', 'Y', 'y'};
                case 'generic'
                    count = state.InputCount.Value;
                    roles = [cellstr("入力" + string(1:count)), {'y'}];
                case {'predict', 'shap'}
                    if ~isempty(state.Model)
                        roles = state.Model.PredictorNames;
                        if strcmp(state.Mode.Value, '面内推定'), roles = {'X', 'Y'}; end
                        if strcmp(state.Mode.Value, 'ノイズ除去用SHAP'), roles = app.Constants.PREDICTOR_NAMES; end
                    end
                case 'metrics'
                    roles = {'col1', 'col2'};
            end
            if ~isempty(state.Data)
                state.Mapping.Data = app.makeMapping(roles, state.Data.Headers, strcmp(state.Kind, 'generic'));
                state.Mapping.ColumnFormat = {'numeric', 'char', [{'(未選択)'}, state.Data.Headers]};
            end
            if ~isempty(state.TestData)
                state.TestMapping.Data = app.makeMapping({'X', 'Y'}, state.TestData.Headers, false);
                state.TestMapping.ColumnFormat = {'numeric', 'char', [{'(未選択)'}, state.TestData.Headers]};
            end
            app.Panels{index} = state;
            app.invalidate(index);
        end

        function mapping = makeMapping(~, roles, headers, positional)
            mapping = cell(numel(roles), 3);
            for row = 1:numel(roles)
                selected = '(未選択)';
                if any(strcmp(headers, roles{row}))
                    selected = roles{row};
                elseif positional && row <= numel(headers)
                    selected = headers{row};
                end
                mapping(row, :) = {row, roles{row}, selected};
            end
        end

        function invalidate(app, index)
            state = app.Panels{index};
            state.Confirmed = false; state.Result = table();
            state.Figures = {};
            state.Results.Data = table(); state.Verification.Data = table();
            app.Panels{index} = state;
            app.message(index, '列対応が未確認です。対応表を確認してください。');
        end

        function matrix = mappedInput(~, state, is_test)
            if is_test
                data = state.TestData; mapping = state.TestMapping.Data;
            else
                data = state.Data; mapping = state.Mapping.Data;
            end
            if isempty(data), error('AnalysisApp:noInput', '入力ファイルを選択してください。'); end
            if strcmp(state.Kind, 'summary') && ~is_test
                names = cellstr(string(state.Columns.Value));
                matrix = extract_numeric_columns(data, names, true);
            else
                if isempty(mapping), error('AnalysisApp:noMapping', 'モデルを読み込み、列を割り当ててください。'); end
                matrix = assign_required_columns(data, mapping(:, 2), mapping(:, 3));
            end
        end

        function confirmMapping(app, index)
            try
                state = app.Panels{index};
                app.mappedInput(state, false);
                if ~isempty(state.TestData), app.mappedInput(state, true); end
                if any(strcmp(state.Kind, {'predict', 'shap'})) && isempty(state.Model)
                    error('AnalysisApp:noModel', '学習済みモデルを選択してください。');
                end
                state.Confirmed = true;
                app.Panels{index} = state;
                app.message(index, '列対応・順序を確認済みです。実行できます。');
            catch err
                app.showError(index, err);
            end
        end

        function run(app, index)
            state = app.Panels{index};
            state.Run.Enable = 'off';
            cleanup = onCleanup(@() set(state.Run, 'Enable', 'on'));
            try
                if ~any(strcmp(state.Kind, {'doe', 'words'})) && ~state.Confirmed
                    error('AnalysisApp:mappingNotConfirmed', '列対応・順序の確認ボタンを押してください。');
                end
                state.Result = table(); state.Results.Data = table();
                state.Verification.Data = table(); state.Figures = {};
                app.Panels{index} = state;
                state.Messages.Value = {'処理中'};
                if any(strcmp(state.Kind, app.Constants.MODEL_TYPES))
                    app.trainAndSave(index);
                elseif strcmp(state.Kind, 'doe')
                    seed_text = strtrim(state.Seed.Value);
                    if isempty(seed_text), seed = []; else, seed = str2double(seed_text); end
                    design = create_D_DOE(state.Factors.Value, state.Runs.Value, seed);
                    app.result(index, array2table(design));
                elseif strcmp(state.Kind, 'words')
                    [words, counts] = create_wordCloud(strjoin(string(state.Text.Value), newline));
                    app.result(index, table(words, counts, 'VariableNames', {'Word', 'Count'}));
                    chart = figure('Name', 'Word Cloud', 'Color', 'white');
                    wordcloud(words, counts); title('Word Cloud', 'FontSize', 14, 'FontWeight', 'bold');
                    state = app.Panels{index}; state.Figures = {chart}; app.Panels{index} = state;
                else
                    matrix = app.mappedInput(state, false);
                    switch state.Kind
                        case 'predict'
                            if strcmp(state.Mode.Value, '面内推定')
                                [prediction, outside_rows, warnings] = predict_in_plane(state.Model, matrix);
                                app.result(index, table(state.Data.RowNumbers, prediction, outside_rows, ...
                                    'VariableNames', {'SourceRow', 'y_pred', 'OutsideTrainingRange'}));
                                app.showWarnings(index, warnings);
                            else
                                prediction = predict(state.Model, format_model_input(state.Model, matrix));
                                app.result(index, table(state.Data.RowNumbers, prediction, 'VariableNames', {'SourceRow', 'y_pred'}));
                            end
                        case 'shap'
                            app.runShap(index, state.Model, matrix, false);
                        case 'metrics'
                            app.calculateMetrics(index, matrix);
                        case 'summary'
                            names = cellstr(string(state.Columns.Value));
                            summary = calc_column_summary(matrix(:, 1));
                            output = table(string(summary(:, 1)), cell2mat(summary(:, 2)), ...
                                'VariableNames', {'Statistic', matlab.lang.makeValidName(names{1})});
                            for column = 2:size(matrix, 2)
                                summary = calc_column_summary(matrix(:, column));
                                name = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(names{column}), output.Properties.VariableNames);
                                output.(name) = cell2mat(summary(:, 2));
                            end
                            app.result(index, output);
                    end
                end
                app.message(index, '処理を終了しました。');
            catch err
                app.showError(index, err);
            end
        end

        function trainAndSave(app, index)
            state = app.Panels{index};
            started = tic;
            [~, input_name, extension] = fileparts(state.Data.FileName);
            entry = struct('Function', state.Kind, 'InputFile', [input_name extension], ...
                'Rows', size(state.Data.Cells, 1), 'Kernel', state.Kernel.Value, ...
                'FitMethod', state.FitMethod.Value, 'SavePath', '', 'Verification', [], ...
                'PredictorNames', {{}}, 'ResponseName', '', 'Status', 'started');
            try
                matrix = app.mappedInput(state, false);
                X = matrix(:, 1:end - 1); y = matrix(:, end);
                kernel = state.Kernel.Value; fit_method = state.FitMethod.Value;
                switch state.Kind
                    case 'apc'
                        [Train_Model, warnings] = train_apc_model(X, y, state.IsPlot.Value, kernel, fit_method);
                    case 'swing'
                        [Train_Model, warnings] = train_swing_curve_model(X(:, 1:3), X(:, 4), y, kernel, fit_method);
                    case 'in_plane'
                        [Train_Model, warnings] = train_in_plane_model(X, y, kernel, fit_method);
                    case 'generic'
                        [Train_Model, warnings] = train_generic_gpr_model(X, y, kernel, fit_method);
                end
                entry.PredictorNames = Train_Model.PredictorNames;
                entry.ResponseName = Train_Model.ResponseName;
                app.showWarnings(index, warnings);
                [name, folder] = uiputfile('*.mat', '学習済みモデルを保存');
                if isequal(name, 0)
                    % TODO(要確認 Q-06) 保存キャンセル後は面内推定も SHAP も行わない。
                    entry.Status = 'save_cancelled';
                    entry.ElapsedSeconds = toc(started); app.logTraining(index, entry);
                    app.message(index, '保存がキャンセルされました。後続の推定・SHAP は行いません。');
                    return;
                end
                entry.SavePath = fullfile(folder, name);
                save_train_model(Train_Model, entry.SavePath);
                expected = struct('KernelFunction', kernel, 'FitMethod', fit_method, ...
                    'BasisFunction', 'constant', 'NumObservations', size(X, 1));
                report = verify_saved_model(entry.SavePath, Train_Model, state.Kind, expected);
                state.Verification.Data = report.Checks;
                entry.Verification = table2struct(report.Checks);
                app.message(index, report.Message);
                if ~report.Success
                    error('AnalysisApp:verificationFailed', '%s', app.Constants.INVALID_MODEL_MESSAGE);
                end
                app.result(index, report.Checks);
                if strcmp(state.Kind, 'apc')
                    app.runShap(index, Train_Model, X, true);
                elseif strcmp(state.Kind, 'in_plane') && ~isempty(state.TestData)
                    test_matrix = app.mappedInput(state, true);
                    [prediction, outside_rows, warnings] = predict_in_plane(Train_Model, test_matrix);
                    app.result(index, table(state.TestData.RowNumbers, prediction, outside_rows, ...
                        'VariableNames', {'SourceRow', 'y_pred', 'OutsideTrainingRange'}));
                    app.showWarnings(index, warnings);
                end
                entry.Status = 'completed';
            catch err
                entry.Status = ['failed:' err.identifier];
                entry.ElapsedSeconds = toc(started); app.logTraining(index, entry);
                rethrow(err);
            end
            entry.ElapsedSeconds = toc(started); app.logTraining(index, entry);
        end

        function runShap(app, index, Train_Model, matrix, is_apc)
            state = app.Panels{index};
            if is_apc && size(matrix, 1) > app.Constants.MAX_SHAP_POINTS
                app.showWarnings(index, string(sprintf('SHAP 計算データを先頭 1000 件に制限します（全 %d 件）。', size(matrix, 1))));
                matrix = matrix(1:app.Constants.MAX_SHAP_POINTS, :);
            end
            progress = uiprogressdlg(app.Window, 'Title', 'SHAP 解析', 'Message', 'SHAP 値を算出しています。', 'Indeterminate', 'on');
            cleanup = onCleanup(@() close(progress));
            drawnow;
            if ~is_apc && strcmp(state.Mode.Value, 'ノイズ除去用SHAP')
                [resist, shap_obj, shap_all] = denoise_for_swing_curve(Train_Model, matrix(:, 1:3), matrix(:, 4));
                output = table(state.Data.RowNumbers, resist, 'VariableNames', {'SourceRow', 'shap_resist'});
            else
                [shap_obj, shap_all] = calc_shap_dependence(Train_Model, matrix);
                output = array2table(shap_all, 'VariableNames', Train_Model.PredictorNames);
                output = addvars(output, state.Data.RowNumbers(1:size(shap_all, 1)), ...
                    'Before', 1, 'NewVariableNames', 'SourceRow');
            end
            app.result(index, output);
            clear cleanup;
            if state.IsPlot.Value
                figures = plot_shap_figures(shap_obj, shap_all, Train_Model.PredictorNames);
                state = app.Panels{index}; state.Figures = figures; app.Panels{index} = state;
            end
        end

        function calculateMetrics(app, index, matrix)
            state = app.Panels{index};
            col1 = matrix(:, 1); col2 = matrix(:, 2);
            bins = state.Bins.Value; if bins == 0, bins = []; end
            switch state.Mode.Value
                case '一括（rmse / mae / r / r_squared）', values = calc_all_metrics(col1, col2);
                case 'RMSE', values = {'rmse', calc_rmse(col1, col2)};
                case 'RMSPE (%)', values = {'rmspe_percent', calc_rmspe(col1, col2)};
                case 'MAE', values = {'mae', calc_mae(col1, col2)};
                case 'Pearson r', values = {'r', calc_pearson(col1, col2)};
                case 'r²（相関係数の2乗）', values = {'r_squared', calc_r_squared(col1, col2)};
                case 'KL (nats)', values = {'kl_nats', calc_kl_divergence(col1, col2, bins)};
                case '相互情報量 (bits)', values = {'mutual_information_bits', calc_mutual_information(col1, col2, bins)};
            end
            app.result(index, cell2table(values, 'VariableNames', {'Metric', 'Value'}));
        end

        function result(app, index, output)
            state = app.Panels{index}; state.Result = output; state.Results.Data = output;
            app.Panels{index} = state;
        end

        function message(app, index, text)
            state = app.Panels{index};
            state.Messages.Value = [cellstr(string(state.Messages.Value)); cellstr(string(text(:)))];
        end

        function showWarnings(app, index, warnings)
            if isempty(warnings), return; end
            app.message(index, warnings);
            uialert(app.Window, strjoin(warnings, newline), '警告', 'Icon', 'warning');
        end

        function showError(app, index, err)
            app.message(index, string(err.message));
            uialert(app.Window, err.message, '処理を中止しました', 'Icon', 'error');
        end

        function logTraining(app, index, entry)
            try
                write_training_log(app.LogFolder, entry);
            catch err
                app.message(index, '学習ログの保存に失敗しました。');
                uialert(app.Window, err.message, 'ログ保存エラー', 'Icon', 'warning');
            end
        end

        function exportResult(app, index)
            try
                state = app.Panels{index};
                if isempty(state.Result), error('AnalysisApp:noResult', '保存する結果がありません。'); end
                [name, folder] = uiputfile({'*.csv', 'CSV'; '*.xlsx', 'Excel'}, '結果を保存');
                if isequal(name, 0), return; end
                writetable(state.Result, fullfile(folder, name));
                app.message(index, ['結果を保存しました: ' name]);
            catch err
                app.showError(index, err);
            end
        end

        function exportFigure(app, index)
            try
                state = app.Panels{index};
                figures = state.Figures(cellfun(@isgraphics, state.Figures));
                if isempty(figures), error('AnalysisApp:noChart', '保存するグラフがありません。'); end
                names = cellfun(@(chart) chart.Name, figures, 'UniformOutput', false);
                [choice, accepted] = listdlg('ListString', names, 'SelectionMode', 'single', 'PromptString', '保存するグラフ');
                if ~accepted, return; end
                [name, folder] = uiputfile('*.png', 'グラフを保存');
                if isequal(name, 0), return; end
                exportgraphics(figures{choice}, fullfile(folder, name), 'Resolution', 150);
            catch err
                app.showError(index, err);
            end
        end

        function loadText(app, index)
            try
                [name, folder] = uigetfile({'*.txt', 'テキスト'});
                if isequal(name, 0), return; end
                state = app.Panels{index};
                state.Text.Value = splitlines(string(fileread(fullfile(folder, name))));
            catch err
                app.showError(index, err);
            end
        end
    end
end
