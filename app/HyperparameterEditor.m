classdef HyperparameterEditor < handle
    % Pro 版の汎用回帰で、ハイパーパラメータの値と探索の候補を方式ごとに編集する部品。
    % 左で方式と探索の方法を選び、右の表で「値」（探索しないときに使う値）と「探索の候補」を入力する。
    % 候補が空欄の項目は探索せず、「値」に固定する。
    properties (SetAccess = private)
        Method
        Mode
        Trials
        Summary
        Table
        Values = struct()
        Candidates = struct()
    end
    properties
        ChangedFcn = []
    end
    properties (Access = private)
        Owner
    end
    properties (Constant)
        METHOD_NAMES = {'ランダムフォレスト', 'バギング木', 'EBM（GA2M）', 'XGBoost', 'LightGBM', 'CatBoost'}
        METHOD_CODES = {'forest', 'bagging', 'ebm', 'xgboost', 'lightgbm', 'catboost'}
        MODE_NAMES = {'探索しない（表の「値」で学習）', 'グリッドサーチ（候補の全組み合わせ）', 'ランダムサーチ（候補から試行数だけ選ぶ）'}
        MODE_CODES = {'none', 'grid', 'random'}
        DEFAULT_TRIALS = 10
        MAX_TRIALS = 200
        COLUMN_VALUE = 2
        COLUMN_CANDIDATES = 3
    end
    methods
        function editor = HyperparameterEditor(owner, parent)
            editor.Owner = owner;
            for index = 1:numel(editor.METHOD_CODES)
                method = editor.METHOD_CODES{index}; specs = hyperparameter_specs(method);
                for row = 1:numel(specs)
                    editor.Values.(method).(specs(row).Name) = specs(row).Default;
                    editor.Candidates.(method).(specs(row).Name) = specs(row).Candidates;
                end
            end
            % 上に方式・探索の方法・試行数、その下に試行数の説明、残りに表を置く。
            grid = uigridlayout(parent, [4, 4]); grid.RowHeight = {30, 30, 48, '1x'}; grid.ColumnWidth = {100, '1x', 110, 70};
            uilabel(grid, 'Text', '編集する方式');
            editor.Method = uidropdown(grid, 'Items', editor.METHOD_NAMES, 'ItemsData', editor.METHOD_CODES, ...
                'ValueChangedFcn', @(~, ~) editor.showMethod());
            uilabel(grid, 'Text', sprintf('試行数（1〜%d）', editor.MAX_TRIALS));
            editor.Trials = uieditfield(grid, 'numeric', 'Value', editor.DEFAULT_TRIALS, 'Limits', [1, editor.MAX_TRIALS], ...
                'RoundFractionalValues', 'on', 'ValueChangedFcn', @(~, ~) editor.changed(), ...
                'Tooltip', 'ランダムサーチで試す組み合わせの数です。候補の組み合わせより多い場合は、全部を試します。');
            uilabel(grid, 'Text', '探索の方法');
            editor.Mode = uidropdown(grid, 'Items', editor.MODE_NAMES, 'ItemsData', editor.MODE_CODES, ...
                'ValueChangedFcn', @(~, ~) editor.changed(), ...
                'Tooltip', '選んだ回帰方式のうち、ハイパーパラメータを持つ方式すべてで探索します。');
            editor.Mode.Layout.Column = [2, 4];
            editor.Summary = AppPage.hint(grid, ''); editor.Summary.Layout.Column = [1, 4];
            editor.Table = uitable(grid, 'RowName', {}, ...
                'ColumnName', {'パラメータ', '値', '探索の候補（カンマ区切り）', '説明'}, ...
                'ColumnEditable', [false, true, true, false], 'ColumnWidth', {150, 70, 170, 'auto'}, ...
                'CellEditCallback', @(~, event) editor.cellEdited(event), ...
                'Tooltip', '「値」は探索しないときに使う値、「探索の候補」は探索するときに試す値です。候補が空欄の項目は探索しません。');
            editor.Table.Layout.Column = [1, 4];
            editor.showMethod(); editor.changed();
        end
        function values = parameters(editor, method)
            values = editor.Values.(method);
        end
        function code = mode(editor)
            code = editor.Mode.Value;
        end
        function search = searchSpec(editor, folds, seed)
            % 探索しないときは空。探索するときは、候補を持つ方式ごとの候補をまとめる。
            search = [];
            if strcmp(editor.mode(), 'none'), return; end
            candidates = struct();
            for index = 1:numel(editor.METHOD_CODES)
                method = editor.METHOD_CODES{index}; chosen = editor.searchedCandidates(method);
                if ~isempty(fieldnames(chosen)), candidates.(method) = chosen; end
            end
            search = struct('Mode', editor.mode(), 'Trials', editor.Trials.Value, 'Folds', folds, 'Seed', seed, 'Candidates', candidates);
        end
        function count = trialCount(editor, method)
            % その方式で試す組み合わせの数（探索しないときは0）。
            count = 0;
            if strcmp(editor.mode(), 'none'), return; end
            chosen = editor.searchedCandidates(method); names = fieldnames(chosen);
            if isempty(names), return; end
            count = prod(cellfun(@(name) numel(chosen.(name)), names));
            if strcmp(editor.mode(), 'random'), count = min(count, editor.Trials.Value); end
        end
        % ---------- テストや他の画面から使う操作の入口 ----------
        function setMode(editor, code)
            editor.Mode.Value = code; editor.changed();
        end
        function setValue(editor, method, name, value)
            hyperparameter_values(method, struct(name, value));
            editor.Values.(method).(name) = value; editor.refreshTable(method); editor.changed();
        end
        function setCandidates(editor, method, name, values)
            for value = values(:)', hyperparameter_values(method, struct(name, value)); end
            editor.Candidates.(method).(name) = values(:)'; editor.refreshTable(method); editor.changed();
        end
        function selectMethod(editor, method)
            editor.Method.Value = method; editor.showMethod();
        end
    end
    methods (Access = private)
        function chosen = searchedCandidates(editor, method)
            chosen = struct(); specs = hyperparameter_specs(method);
            for row = 1:numel(specs)
                values = editor.Candidates.(method).(specs(row).Name);
                if ~isempty(values), chosen.(specs(row).Name) = values; end
            end
        end
        function showMethod(editor)
            editor.refreshTable(editor.Method.Value);
        end
        function refreshTable(editor, method)
            if ~strcmp(editor.Method.Value, method), return; end
            specs = hyperparameter_specs(method); rows = cell(numel(specs), 4);
            for row = 1:numel(specs)
                name = specs(row).Name;
                % 値は文字で表示する（整数が 100.0000 のように表示されないようにするため）。
                rows(row, :) = {specs(row).Label, sprintf('%.6g', editor.Values.(method).(name)), ...
                    HyperparameterEditor.formatList(editor.Candidates.(method).(name)), specs(row).Description};
            end
            editor.Table.Data = rows;
        end
        function cellEdited(editor, event)
            method = editor.Method.Value; specs = hyperparameter_specs(method);
            row = event.Indices(1); column = event.Indices(2); name = specs(row).Name;
            try
                if column == editor.COLUMN_VALUE
                    value = event.NewData;
                    if ischar(value) || isstring(value), value = str2double(value); end
                    editor.setValue(method, name, value);
                elseif column == editor.COLUMN_CANDIDATES
                    editor.setCandidates(method, name, HyperparameterEditor.parseList(event.NewData, specs(row).Label));
                end
            catch err
                editor.refreshTable(method);
                editor.Owner.showError(err);
            end
        end
        function changed(editor)
            random = strcmp(editor.mode(), 'random');
            editor.Trials.Enable = matlab.lang.OnOffSwitchState(random);
            if strcmp(editor.mode(), 'none')
                editor.Summary.Text = ['探索しません。表の「値」で学習します。グリッドサーチ・ランダムサーチでは「探索の候補」を入れた項目を' ...
                    '交差検証（上の分割数と乱数seed）の RMSE で比べ、最も良い値で学習し直します。'];
            else
                parts = {};
                for index = 1:numel(editor.METHOD_CODES)
                    count = editor.trialCount(editor.METHOD_CODES{index});
                    if count > 0, parts{end + 1} = sprintf('%s %d通り', editor.METHOD_NAMES{index}, count); end %#ok<AGROW>
                end
                if isempty(parts), parts = {'候補が空欄のため探索しません'}; end
                editor.Summary.Text = sprintf('試す組み合わせ（回帰方式で選んだものだけ実行）：%s。1通りごとに分割数の回数だけ学習します。', strjoin(parts, '、'));
            end
            if ~isempty(editor.ChangedFcn), editor.ChangedFcn(); end
        end
    end
    methods (Static)
        function text = formatList(values)
            text = strjoin(arrayfun(@(value) sprintf('%.6g', value), values, 'UniformOutput', false), ', ');
        end
        function values = parseList(text, label)
            text = strtrim(char(string(text)));
            values = [];
            if isempty(text), return; end
            parts = regexp(text, '[,、\s]+', 'split'); parts = parts(~cellfun(@isempty, parts));
            values = str2double(parts);
            if any(isnan(values)), error('hyperparameter:candidates', '%s の候補は、数値をカンマで区切って入力してください（例: 0.05, 0.1, 0.3）。', label); end
            values = unique(values, 'stable');
        end
    end
end
