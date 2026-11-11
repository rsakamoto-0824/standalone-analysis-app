classdef AnalysisController < handle
    properties (SetAccess = private)
        Window
        Panels = cell(1, 7)
        LogFolder
        Furnace = []
        Edition
        ModelRegistry = struct('Label', {}, 'Model', {}, 'Kind', {}, 'Record', {})
        ModelingRecords = {}
        RunSequence = 0
    end
    properties (Access = private)
        Constants
        Settings
        SettingsPath
        SettingsUI
        MainTabs
        FurnaceTab
    end
    methods
        function app = AnalysisController(window, edition)
            project_root = fileparts(fileparts(mfilename('fullpath')));
            addpath(fullfile(project_root, 'core'));
            require_r2025b();
            if nargin < 2, edition = app_edition(); end
            if ~any(strcmp(edition, {'standard', 'pro'})) || (isdeployed && ~strcmp(edition, app_edition()))
                error('AnalysisApp:edition', 'この実行ファイルの版は変更できません。');
            end
            app.Edition = edition;
            app.Constants = model_constants();
            app.SettingsPath = fullfile(prefdir, 'StandaloneAnalysisApp', 'settings.json');
            settings_warning = '';
            try
                app.Settings = app_settings('load', app.SettingsPath);
            catch err
                app.Settings = app_settings('defaults'); settings_warning = err.message;
            end
            app.Window = window;
            window.Name = 'Process Insight Tool';
            if strcmp(app.Edition, 'pro'), window.Name = [window.Name ' Pro']; end
            window.Position(3:4) = [1320, 860]; window.Resize = 'on'; window.AutoResizeChildren = 'off';
            app.LogFolder = fullfile(prefdir, 'StandaloneAnalysisApp', 'logs');
            tabs = AnalysisNavigation(window); app.MainTabs = tabs;
            titles = {'APC 学習', 'Swing Curve学習', '汎用 GPR 学習', '保存モデルで推定', 'SHAP 解析', '実験計画作成', 'ワードクラウド'};
            kinds = {'apc', 'swing', 'generic', 'predict', 'shap', 'doe', 'words'};
            for index = 1:numel(titles)
                display_number = index + double(index >= 4);
                tab = tabs.addPage(sprintf('%d %s', display_number, titles{index}));
                app.createPanel(index, tab, kinds{index});
                if index == 3, app.FurnaceTab = tabs.addPage('4 炉内補間'); end
            end
            tabs.SelectionChangedFcn = @(~, event) app.openFurnace(event.NewValue);
            app.createSettings(tabs.addPage('9 設定'));
            create_app_help(tabs.addPage('10 Help'), project_root, app.Edition);
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
            controls = uigridlayout(state.Layout, [13, 1], 'Scrollable', 'on');
            controls.Layout.Row = 1; controls.Layout.Column = 1;
            controls.RowHeight = {42, 30, 50, 30, 76, 30, 32, 180, 32, 32, 24, 34, 120}; state.Controls = controls;
            uilabel(controls, 'Text', '列の順序・割当を確認して実行してください。', 'WordWrap', 'on');
            state.Load = uibutton(controls, 'Text', 'Excel / CSV を開く', 'ButtonPushedFcn', @(~, ~) app.loadData(index));
            state.Source = uilabel(controls, 'Text', '入力ファイル未選択', 'WordWrap', 'on');
            state.LoadModel = uibutton(controls, 'Text', '学習済み MAT を開く', 'ButtonPushedFcn', @(~, ~) app.loadModel(index));
            state.ModelInfo = uitextarea(controls, 'Editable', 'off', 'Value', {'BasisFunction: constant（固定）'});
            state.Mode = uidropdown(controls, 'Items', {'通常'}, 'ValueChangedFcn', @(~, ~) app.updateMapping(index));
            options = uigridlayout(controls, [2, 2]); options.Padding = [0, 0, 0, 0]; options.RowHeight = {30, 30}; options.RowSpacing = 4;
            kernels = app.Constants.KERNELS; default_kernel = app.Settings.Kernel;
            if strcmp(kind, 'swing'), kernels = app.Constants.SWING_KERNELS; default_kernel = app.Settings.SwingKernel; end
            state.Kernel = uidropdown(options, 'Items', kernels, 'Value', default_kernel, 'Tooltip', 'kernel。swingperiodicはRESIST_THの周期を内部で最適化します。');
            state.FitMethod = uidropdown(options, 'Items', app.Constants.FIT_METHODS, 'Value', app.Settings.FitMethod, 'Tooltip', 'fit_method');
            compare_button = uibutton(options, 'Text', '条件比較・モデル保存を開く', 'ButtonPushedFcn', @(~, ~) app.openComparison(index));
            compare_button.Layout.Row = 2; compare_button.Layout.Column = [1, 2];
            state.Mapping = uitable(controls, 'Data', cell(0, 3), 'ColumnName', {'順序', '変数', '入力列'}, ...
                'ColumnEditable', [false, false, true], 'ColumnWidth', {42, 110, 'auto'}, 'CellEditCallback', @(~, ~) app.invalidate(index));
            state.Actual = app.choiceRow(controls, '評価用の目的変数・実測列（任意）', {'(実測値なし)'});
            state.Actual.ValueChangedFcn = @(~, ~) app.invalidate(index);
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
            if any(strcmp(kind, {'apc', 'swing', 'generic'}))
                controls.RowHeight{7} = 100;
                options.RowHeight = {30, 30, 30};
                state.ShapOpen = uibutton(options, 'Text', 'MAT保存なしのSHAP実行画面を開く', ...
                    'ButtonPushedFcn', @(~, ~) app.openShapSelection(index));
                state.ShapOpen.Layout.Row = 3; state.ShapOpen.Layout.Column = [1, 2];
            end
            state.BaseTabs = state.Views.Children;
            export_bar = uigridlayout(state.Right, [1, 3]); export_bar.Padding = [0, 0, 0, 0];
            uibutton(export_bar, 'Text', '表示中の表を保存', 'ButtonPushedFcn', @(~, ~) app.exportResult(index));
            uibutton(export_bar, 'Text', 'グラフを PNG に保存', 'ButtonPushedFcn', @(~, ~) app.exportFigure(index));
            state.CopyFigure = uibutton(export_bar, 'Text', 'グラフをコピー', ...
                'Tooltip', 'グラフを画像としてクリップボードへコピーし、ExcelやPowerPointなどへ貼り付けます。', ...
                'ButtonPushedFcn', @(~, ~) app.copyFigure(index));
            if ~any(strcmp(kind, {'predict', 'shap'}))
                state.LoadModel.Visible = 'off'; controls.RowHeight{4} = 0;
                state.Actual.Parent.Visible = 'off'; controls.RowHeight{9} = 0;
            end
            state.Mode.Visible = 'off'; controls.RowHeight{6} = 0;
            if ~any(strcmp(kind, {'apc', 'swing', 'generic', 'shap'})), state.IsPlot.Visible = 'off'; controls.RowHeight{11} = 0; end
            if strcmp(kind, 'swing')
                controls.RowHeight{5} = 100;
                state.IsPlot.Text = 'SHAPグラフを表示（計算は保存前に実行）'; state.IsPlot.Value = true;
                state.IsPlot.Tooltip = '各目的変数・条件のモデルで先頭最大1000行のSHAPを計算します。';
            end
            if strcmp(kind, 'generic')
                delete(state.Mode); controls.RowHeight{6} = 32;
                count = app.Settings.InputCount; if strcmp(kind, 'swing'), count = 1; end
                state.InputCount = app.numberRow(controls, '説明変数の数（最低1）', count, [1, 100]);
                state.InputCount.Parent.Layout.Row = 6;
                state.InputCount.ValueChangedFcn = @(~, ~) app.updateMapping(index);
            elseif strcmp(kind, 'swing')
                state.Mode.Visible = 'on'; controls.RowHeight{6} = 32;
                state.Mode.Items = {'下地なし（膜厚のみ）', '下地あり'};
                state.Mode.ValueChangedFcn = @(~, ~) app.updateMapping(index);
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
                    state.Levels = app.choiceRow(controls, '水準数（最大5）', {'2', '3', '4', '5'}); state.Levels.Value = '3';
                    seed_hint = uilabel(controls, 'Text', '乱数seedは「9 設定」で指定します。'); seed_hint.Layout.Row = 7;
                    parameters = {state.Method, state.DesignModel, state.Runs, state.Levels};
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
            if strcmp(kind, 'swing'), app.createSwingOptions(index); app.describeSwingKernel(index); end
            if any(strcmp(kind, {'apc', 'swing', 'generic', 'shap'})), app.createShapSelection(index); end
            if any(strcmp(kind, {'apc', 'swing', 'generic'})), app.createModelingSelection(index); end
        end

        function createSwingOptions(app, index)
            state = app.Panels{index}; options = swing_period_options(); tab = uitab(state.Views, 'Title', 'Swing Curve設定');
            layout = uigridlayout(tab, [8, 2]); layout.ColumnWidth = {'1.2x', '1x'}; layout.RowHeight = {50, 32, 32, 38, 32, 32, 32, 60};
            hint = uilabel(layout, 'Text', '説明変数は最低1列。最後の説明変数RESIST_THに、レジスト膜厚（nm）の列を割り当てます。', 'WordWrap', 'on'); hint.Layout.Column = [1, 2];
            uilabel(layout, 'Text', '露光波長（nm）'); state.Wavelength = uieditfield(layout, 'numeric', 'Value', options.Wavelength, 'Limits', [eps, Inf]);
            uilabel(layout, 'Text', 'レジスト屈折率'); state.RefractiveIndex = uieditfield(layout, 'numeric', 'Value', options.RefractiveIndex, 'Limits', [eps, Inf]);
            state.PeriodReference = uilabel(layout, 'Text', '', 'WordWrap', 'on'); state.PeriodReference.Layout.Column = [1, 2];
            state.CustomPeriod = uicheckbox(layout, 'Text', '周期の評価範囲を指定', 'Value', false); state.CustomPeriod.Layout.Column = [1, 2];
            uilabel(layout, 'Text', '周期下限（nm）'); state.PeriodLower = uieditfield(layout, 'numeric', 'Value', options.PeriodBounds(1), 'Limits', [eps, Inf]);
            uilabel(layout, 'Text', '周期上限（nm）'); state.PeriodUpper = uieditfield(layout, 'numeric', 'Value', options.PeriodBounds(2), 'Limits', [eps, Inf]);
            hint = uilabel(layout, 'Text', '未指定時は波長÷屈折率の75〜125%を探索します。周期はGPRの学習パラメータに含めず、周辺尤度で内部探索します。', 'WordWrap', 'on'); hint.Layout.Column = [1, 2];
            state.BaseTabs = [state.BaseTabs(:); tab]; app.Panels{index} = state;
            fields = {'Wavelength', 'RefractiveIndex', 'CustomPeriod', 'PeriodLower', 'PeriodUpper'};
            for item = 1:numel(fields), state.(fields{item}).ValueChangedFcn = @(~, ~) app.swingOptionsChanged(index); end
            app.swingOptionsChanged(index);
        end
        function swingOptionsChanged(app, index)
            state = app.Panels{index}; reference = state.Wavelength.Value / state.RefractiveIndex.Value;
            state.PeriodReference.Text = sprintf('基準周期 = 波長÷屈折率 = %.6f nm', reference);
            enabled = matlab.lang.OnOffSwitchState(state.CustomPeriod.Value);
            state.PeriodLower.Enable = enabled; state.PeriodUpper.Enable = enabled;
            app.invalidate(index);
        end
        function options = periodOptions(app, index)
            state = app.Panels{index}; bounds = [];
            if state.CustomPeriod.Value, bounds = [state.PeriodLower.Value, state.PeriodUpper.Value]; end
            options = swing_period_options(state.Wavelength.Value, state.RefractiveIndex.Value, bounds);
        end
        function context = comparisonContext(app, index)
            context = struct(); state = app.Panels{index};
            if strcmp(state.Kind, 'swing')
                context.PredictorNames = state.Mapping.Data(1:end-1, 2)'; context.PeriodOptions = app.periodOptions(index);
            end
        end
        function openShapSelection(app, index)
            state = app.Panels{index}; state.Views.SelectedTab = state.ShapRun.Parent.Parent;
        end
        function createShapSelection(app, index)
            state = app.Panels{index}; tab = uitab(state.Views, 'Title', 'SHAP実行');
            layout = uigridlayout(tab, [5, 1]); layout.RowHeight = {70, 34, 36, 80, '1x'};
            message = 'モデル学習 → SHAP評価 → 条件比較 → 選択モデルをMAT保存。下の一覧ではモデルを選んでSHAPを再計算できます。';
            if strcmp(state.Kind, 'generic'), message = 'モデルを学習してから、下の対象でSHAPを計算できます。MAT保存は必須ではありません。'; end
            if strcmp(state.Kind, 'shap'), message = 'MATを読み込むか、画面内で学習・比較したモデルを選びます。入力列の確認後、MATを保存せずSHAPを計算できます。'; end
            uilabel(layout, 'Text', message, 'WordWrap', 'on');
            state.ShapModel = uidropdown(layout, 'Items', {'対象モデルなし'}, 'ItemsData', 0, 'Value', 0, 'Enable', 'off', ...
                'ValueChangedFcn', @(~, ~) app.selectShapModel(index));
            state.ShapRun = uibutton(layout, 'Text', '保存せず、選択したモデルでSHAPを計算', 'Enable', 'off', 'ButtonPushedFcn', @(~, ~) app.runSelectedShap(index));
            uilabel(layout, 'Text', '学習画面では選択モデルの学習データ（先頭最大1000行）を使用します。SHAP解析画面では確認した入力ファイルを使用します。通常版は分布・依存図まで、Pro版はレジスト膜厚の近似・カーブ評価も利用できます。APC学習画面にはSwing Curve評価を付けません。', 'WordWrap', 'on');
            state.BaseTabs = [state.BaseTabs(:); tab]; app.Panels{index} = state;
            if any(strcmp(state.Kind, {'apc', 'swing'}))
                state.IsPlot.Text = 'SHAPグラフを表示（計算は保存前に実行）';
            end
            if any(strcmp(state.Kind, {'apc', 'swing', 'generic'})), state.Run.Text = 'モデリング・SHAP評価を実行'; end
        end
        function createModelingSelection(app,index)
            state=app.Panels{index}; tab=uitab(state.Views,'Title','モデリング条件');
            state.ModelingTab=tab;
            row_heights=state.Controls.RowHeight;
            target_grid=uigridlayout(state.Controls,[2,1]); target_grid.Layout.Row=4; target_grid.Layout.Column=1;
            target_grid.Padding=[0,0,0,0]; target_grid.RowHeight={24,'1x'};
            row_heights{4}=136; state.Controls.RowHeight=row_heights;
            uilabel(target_grid,'Text','目的変数（複数選択可・Ctrl / Command）');
            state.Targets=uilistbox(target_grid,'Items',{'入力待ち'},'Value',{},'Multiselect','on','Enable','off', ...
                'Tooltip','入力ファイルの目的変数を選択します。複数列はCtrl（MacはCommand）を押しながら選択します。', ...
                'ValueChangedFcn',@(~,~)app.targetsChanged(index));
            grid=uigridlayout(tab,[6,2]); grid.ColumnWidth={'1x','1x'}; grid.RowHeight={28,80,40,36,28,150};
            label=uilabel(grid,'Text','目的変数は左の入力欄で選択します。各列を別モデルで学習・SHAP評価します。','WordWrap','on'); label.Layout.Column=[1,2];
            state.TargetSummary=uilabel(grid,'Text','目的変数：未選択','WordWrap','on'); state.TargetSummary.Layout.Row=[2,3]; state.TargetSummary.Layout.Column=[1,2];
            if strcmp(state.Kind,'swing')
                state.Mapping.ColumnEditable=[false,false,false];
                label=uilabel(grid,'Text','レジスト膜厚の入力列'); label.Layout.Row=4; label.Layout.Column=1;
                state.ResistColumn=uidropdown(grid,'Items',{'入力待ち'},'ValueChangedFcn',@(~,~)app.updateMapping(index)); state.ResistColumn.Layout.Row=4; state.ResistColumn.Layout.Column=2;
                label=uilabel(grid,'Text','下地ありで追加する説明変数（複数選択）'); label.Layout.Row=5; label.Layout.Column=[1,2];
                state.Underlayers=uilistbox(grid,'Items',{'入力待ち'},'Value',{},'Multiselect','on','Enable','off','ValueChangedFcn',@(~,~)app.updateMapping(index)); state.Underlayers.Layout.Row=6; state.Underlayers.Layout.Column=[1,2];
            else
                label=uilabel(grid,'Text','左の対応表は説明変数だけです。目的変数と同じ列を説明変数に割り当てないでください。','WordWrap','on'); label.Layout.Row=4; label.Layout.Column=[1,2];
            end
            state.BaseTabs=[state.BaseTabs(:);tab];
            state.Study=ModelingStudyView(state.Views,state.Kernel.Items,state.Kernel.Value,state.FitMethod.Value,@()app.runModeling(index,true),@()app.displaySelectedModel(index),@()app.saveSelectedModel(index));
            state.BaseTabs=[state.BaseTabs(:);state.Study.Tab]; app.Panels{index}=state;
        end
        function targetsChanged(app,index)
            app.updateTargetSummary(index); app.invalidate(index);
        end
        function updateTargetSummary(app,index)
            state=app.Panels{index}; selected=cellstr(string(state.Targets.Value));
            if isempty(selected), state.TargetSummary.Text='目的変数：未選択';
            else, state.TargetSummary.Text=['目的変数：' strjoin(selected,', ')]; end
        end
        function initializeTrainingColumns(app,index)
            state=app.Panels{index}; headers=state.Data.Headers;
            if ~isfield(state,'Targets'), return; end
            defaults=headers(ismember(lower(string(headers)),["cd","y","膜厚","屈折率"]));
            if ~isempty(defaults), defaults=defaults(1); end
            set(state.Targets,'Items',headers,'Value',defaults,'Enable','on');
            if strcmp(state.Kind,'swing')
                resist=find(strcmpi(headers,'RESIST_TH'),1); if isempty(resist), resist=1; end
                set(state.ResistColumn,'Items',headers,'Value',headers{resist});
                layers=headers(ismember(headers,app.Constants.PREDICTOR_NAMES(1:3)));
                set(state.Underlayers,'Items',headers,'Value',layers);
            end
            app.Panels{index}=state; app.updateTargetSummary(index);
        end
        function identifier = registerModel(app, model, label, kind, target, record)
            if nargin < 5, target = 0; end
            if nargin < 6, record = []; end
            identifier = numel(app.ModelRegistry) + 1;
            label = sprintf('%d: %s', identifier, label);
            app.ModelRegistry(end+1) = struct('Label', label, 'Model', model, 'Kind', kind, 'Record', record);
            for panel = 1:numel(app.Panels)
                state = app.Panels{panel};
                if isempty(state) || ~isfield(state, 'ShapModel'), continue; end
                previous = state.ShapModel.Value; if previous == 0 || panel == target, previous = identifier; end
                set(state.ShapModel, 'Items', {app.ModelRegistry.Label}, 'ItemsData', 1:numel(app.ModelRegistry), 'Value', previous, 'Enable', 'on');
                state.ShapRun.Enable = 'on';
                if strcmp(state.Kind, 'shap'), app.selectShapModel(panel); end
            end
        end
        function registerComparisonModels(app, index, report)
            identifiers = zeros(numel(report.Models), 1);
            for candidate = 1:numel(report.Models)
                if report.Summary.Status(candidate) == "成功"
                    identifiers(candidate) = app.registerModel(report.Models{candidate}, [app.Panels{index}.Kind ': 比較 ' char(report.Summary.Kernel(candidate))], app.Panels{index}.Kind);
                end
            end
            best = find(report.Summary.Rank == 1, 1);
            if ~isempty(best), app.Panels{index}.ShapModel.Value = identifiers(best); end
        end
        function selectShapModel(app, index)
            state = app.Panels{index};
            if ~strcmp(state.Kind, 'shap') || state.ShapModel.Value == 0, return; end
            selected = app.ModelRegistry(state.ShapModel.Value); state.Model = selected.Model;
            state.SelectedModelKind = selected.Kind; state.ModelPath = '';
            state.ModelInfo.Value = {selected.Label; ['PredictorNames: ' strjoin(selected.Model.PredictorNames, ', ')]; '画面内のモデルを使用（MAT保存は不要）'};
            app.Panels{index} = state; app.updateMapping(index);
        end
        function runSelectedShap(app, index)
            try
                state = app.Panels{index}; selected = app.ModelRegistry(state.ShapModel.Value);
                state.SelectedModelKind = selected.Kind; app.Panels{index} = state;
                if strcmp(state.Kind, 'shap')
                    if ~state.Confirmed, error('AnalysisApp:unconfirmed', '選択モデルに合わせて入力列を確認してください。'); end
                    matrix = app.mappedInput(state); training = false; rows = state.Data.RowNumbers; row_label = 'SourceRow';
                else
                    matrix = selected.Model.X; if istable(matrix), matrix = table2array(matrix); end
                    training = true; rows = (1:size(matrix, 1))'; row_label = 'ModelRow';
                end
                cleanup = app.lockControls([]); %#ok<NASGU>
                app.MainTabs.SelectedTab = state.Layout.Parent;
                show_plot = state.IsPlot.Value || strcmp(state.Kind, 'swing');
                app.runShap(index, selected.Model, matrix, training, rows, row_label, show_plot);
                if show_plot
                    state.Views.SelectedTab = state.ChartTabs.Parent.Parent;
                elseif training
                    state.Views.SelectedTab = state.Views.Children(strcmp({state.Views.Children.Title}, 'SHAP 値'));
                else
                    state.Views.SelectedTab = state.Results.Parent.Parent;
                end
                state.Headline.Text = ['SHAP対象: ' selected.Label newline '「モデル評価」の表には、直前の学習・推定結果を保持しています。'];
                app.applyTheme();
                app.message(index, ['MAT保存なしでSHAPを計算しました: ' selected.Label]);
            catch err
                app.showError(index, err);
            end
        end
        function source = scatterSource(app, index, inputs, actual)
            state = app.Panels{index};
            if ~isempty(state.Data) && size(state.Data.Cells, 1) == numel(actual)
                source = state.Data;
            else
                source = struct('Headers', {cellstr("入力" + string(1:size(inputs, 2)))}, 'Cells', {num2cell(inputs)});
            end
        end

        function view = tableTab(~, parent, title_text)
            tab = uitab(parent, 'Title', title_text); layout = uigridlayout(tab, [1, 1]); view = uitable(layout, 'Data', table());
        end
        function field = numberRow(~, parent, label, value, limits)
            row = uigridlayout(parent, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {'1.4x', '1x'};
            uilabel(row, 'Text', label); field = uieditfield(row, 'numeric', 'Value', value, 'Limits', limits, 'RoundFractionalValues', 'on');
        end
        function field = decimalRow(~,parent,label,value,limits)
            row=uigridlayout(parent,[1,2]); row.Padding=[0,0,0,0]; row.ColumnWidth={'1.4x','1x'};
            uilabel(row,'Text',label); field=uieditfield(row,'numeric','Value',value,'Limits',limits,'ValueDisplayFormat','%.9g');
        end
        function field = choiceRow(~, parent, label, items)
            row = uigridlayout(parent, [1, 2]); row.Padding = [0, 0, 0, 0];
            uilabel(row, 'Text', label); field = uidropdown(row, 'Items', items);
        end
        function resizePanels(app)
            % 左の見出し幅は固定し、各画面の入力と結果だけを組み替える。
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
            if ~isempty(app.Furnace), app.Furnace.resize(app.Window.Position(3)); end
        end
        function openFurnace(app, selected_tab)
            if nargin > 1 && ~isequal(selected_tab, app.FurnaceTab), return; end
            if isempty(app.Furnace)
                app.Furnace = FurnaceInterpolationView(app.FurnaceTab, app.Window, app.Settings, @() app.lockControls(app.Furnace), app.LogFolder);
                apply_app_theme(app.Furnace.Layout, app.Settings.Theme);
            end
            app.MainTabs.SelectedTab = app.FurnaceTab;
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
                    set(state.Actual,'Items',[{'(実測値なし)'}, data.Headers],'Value','(実測値なし)','Enable','on');
                end
                app.Panels{index} = state; app.initializeTrainingColumns(index); app.updateMapping(index);
                state.Views.SelectedTab=state.Preview.Parent.Parent;
                if isfield(state,'Targets')
                    app.message(index,'入力を読み込みました。左の「目的変数」で対象列を選び、説明変数との列対応を確認してください。');
                end
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
                periodic = swing_kernel_info(state.Model.KernelFunction);
                if ~isempty(periodic)
                    state.ModelInfo.Value = [state.ModelInfo.Value; {sprintf('swingperiodic / 周期 %.8g（入力の膜厚単位）', periodic.Period)}];
                    state.Controls.RowHeight{5} = 100;
                end
                app.Panels{index} = state; app.registerModel(state.Model, ['MAT: ' name], 'loaded');
                if isfield(state, 'ShapModel'), state.ShapModel.Value = numel(app.ModelRegistry); end
                state.SelectedModelKind = 'loaded'; app.Panels{index} = state; app.updateMapping(index);
            catch err
                app.showError(index, err);
            end
        end
        function updateMapping(app, index)
            state = app.Panels{index}; roles = {}; positional = false;
            switch state.Kind
                case 'apc', roles = app.Constants.PREDICTOR_NAMES;
                case 'swing'
                    roles = {'RESIST_TH'}; selected_inputs = {state.ResistColumn.Value};
                    state.Underlayers.Enable = matlab.lang.OnOffSwitchState(strcmp(state.Mode.Value,'下地あり'));
                    if strcmp(state.Mode.Value,'下地あり')
                        layers = cellstr(string(state.Underlayers.Value)); layers(strcmp(layers,state.ResistColumn.Value)) = [];
                        roles = [layers(:)',roles]; selected_inputs = [layers(:)',selected_inputs];
                    end
                case 'generic', roles = cellstr("入力" + string(1:state.InputCount.Value)); positional = true;
                case 'doe', roles = cellstr("F" + string(1:state.Factors.Value)); positional = true;
                case {'predict', 'shap'}
                    if ~isempty(state.Model)
                        roles = state.Model.PredictorNames;
                        if startsWith(state.Mode.Value, '面内推定'), roles = {'X', 'Y'}; end
                        if strcmp(state.Mode.Value, 'ノイズ除去用SHAP'), roles = state.Model.PredictorNames; end
                    end
            end
            if ~isempty(state.Data)
                mapping = cell(numel(roles), 3);
                for row = 1:numel(roles)
                    selected = '(未選択)';
                    if strcmp(state.Kind,'swing')
                        selected = selected_inputs{row};
                    elseif any(strcmp(state.Data.Headers, roles{row}))
                        selected = roles{row};
                    elseif positional && row <= numel(state.Data.Headers)
                        selected = state.Data.Headers{row};
                    end
                    mapping(row, :) = {row, roles{row}, selected};
                end
                state.Mapping.Data = mapping; state.Mapping.ColumnFormat = {'numeric', 'char', [{'(未選択)'}, state.Data.Headers]};
            end
            app.Panels{index} = state; app.invalidate(index);
        end
        function invalidate(app, index)
            state = app.Panels{index}; state.Confirmed = false; app.Panels{index} = state; app.clearOutput(index);
            if strcmp(state.Kind, 'swing'), app.describeSwingKernel(index); end
            if strcmp(state.Kind, 'doe')
                app.message(index, '設定・列対応を変更しました。内容を確認して再実行してください。');
            else
                app.message(index, '列対応が未確認です。対応表を確認してください。');
            end
        end
        function clearOutput(app, index)
            app.clearModelOutput(index);
            state = app.Panels{index};
            if isfield(state, 'Comparison'), state.Comparison.clear(); end
            state.Figures = {}; state.FigureNames = {}; app.Panels{index} = state;
        end
        function clearModelOutput(app, index)
            state = app.Panels{index}; state.Result = table(); state.Figures = {}; state.FigureNames = {};
            state.Results.Data = table(); state.Metrics.Data = table(); state.Summary.Data = table(); state.Verification.Data = table();
            delete(state.ChartTabs.Children);
            extra = state.Views.Children(~ismember(state.Views.Children, state.BaseTabs)); delete(extra);
            state.Headline.Text = 'RMSE: —    R²: —'; app.Panels{index} = state;
            if isfield(state, 'Comparison') && ~isempty(state.Comparison.Report)
                app.registerCharts(index, state.Comparison.Charts, state.Comparison.ChartNames);
            end
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
                if any(strcmp(state.Kind,{'apc','swing','generic'})), modeling_input_data(state.Data,state.Mapping.Data,state.Targets.Value); end
                if strcmp(state.Kind,'swing') && strcmp(state.Mode.Value,'下地あり') && size(state.Mapping.Data,1)<2
                    error('modeling:underlayers','下地ありモードでは、膜厚以外の説明変数を1列以上選択してください。');
                end
                if any(strcmp(state.Kind, {'predict', 'shap'})) && isempty(state.Model), error('AnalysisApp:noModel', 'モデルを選択してください。'); end
                state.Confirmed = true; app.Panels{index} = state; app.message(index, '列対応・順序を確認済みです。実行できます。');
            catch err
                app.showError(index, err);
            end
        end
        function run(app, index)
            state = app.Panels{index}; app.MainTabs.SelectedTab = state.Layout.Parent;
            state.Run.Enable = 'off'; cleanup = onCleanup(@() set(state.Run, 'Enable', 'on'));
            try
                if ~any(strcmp(state.Kind, {'doe', 'words'})) && ~state.Confirmed, error('AnalysisApp:unconfirmed', '列対応・順序の確認ボタンを押してください。'); end
                if ~any(strcmp(state.Kind, {'doe', 'words'})) && app.Settings.Bins > 0
                    validate_bin_count(app.Settings.Bins, 'AnalysisApp');
                end
                app.clearOutput(index); state.Messages.Value = {'処理中'}; drawnow;
                if any(strcmp(state.Kind, {'apc', 'swing', 'generic'})), app.runModeling(index, false);
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
        function openComparison(app,index)
            state=app.Panels{index}; state.Views.SelectedTab=state.Study.Tab;
        end
        function runModeling(app,index,compare,services)
            state=app.Panels{index}; progress=[];
            try
                if ~state.Confirmed, error('AnalysisApp:unconfirmed','説明変数と目的変数の対応を確認してください。'); end
                [inputs,responses,names,targets]=modeling_input_data(state.Data,state.Mapping.Data,state.Targets.Value);
                kernels={state.Kernel.Value}; methods={state.FitMethod.Value}; folds=0; seed=0;
                if compare, kernels=cellstr(string(state.Study.Kernels.Value)); methods=cellstr(string(state.Study.FitMethods.Value)); folds=state.Study.Folds.Value; seed=state.Study.Seed.Value; end
                conditions=struct('Kernel',{},'FitMethod',{});
                for kernel=1:numel(kernels)
                    for method=1:numel(methods), conditions(end+1)=struct('Kernel',kernels{kernel},'FitMethod',methods{method}); end %#ok<AGROW>
                end
                period_options=swing_period_options();
                if strcmp(state.Kind,'swing'), period_options=app.periodOptions(index); end
                if nargin<4
                    services=struct('Trainer',@(x,y,c,callback)train_modeling_candidate(state.Kind,x,y,names,c,period_options,callback), ...
                        'Predictor',@(model,x)predict(model,format_model_input(model,x)),'Shap',@calc_shap_dependence);
                end
                options=struct('Folds',folds,'Seed',seed,'Bins',app.Settings.Bins);
                controls_cleanup=app.lockControls(state.Study); %#ok<NASGU>
                progress=uiprogressdlg(app.Window,'Title','モデリング・SHAP評価','Message','条件を準備中','Indeterminate','on','Cancelable','on');
                progress_cleanup=onCleanup(@()app.closeProgress(progress));
                records=evaluate_modeling_batch(inputs,responses,names,targets,conditions,options,services,@(event)app.batchProgress(progress,event));
                clear progress_cleanup;
                app.RunSequence=app.RunSequence+1; previous_models=numel(app.ModelRegistry);
                for item=1:numel(records)
                    r=records{item}; r.Id=0; r.Run=app.RunSequence; r.Kind=state.Kind; r.Source=state.Data; r.SourceRows=state.Data.RowNumbers;
                    r.Bins=app.Settings.Bins; r.PeriodOptions=period_options; r.Mode=state.Kind;
                    if strcmp(state.Kind,'swing'), r.Mode=state.Mode.Value; end
                    if ~isempty(r.Model)
                        r.Id=numel(app.ModelRegistry)+1;
                        label=sprintf('%s / %s / %s / %s / 条件%d',state.Kind,r.Target,r.Condition.Kernel,r.Condition.FitMethod,r.Run);
                        app.registerModel(r.Model,label,state.Kind,index,r);
                    end
                    app.ModelingRecords{end+1}=r;
                end
                state.Study.refresh(app.ModelingRecords,state.Kind);
                clear controls_cleanup;
                if numel(app.ModelRegistry)>previous_models
                    state.Study.Selection.Value=numel(app.ModelRegistry); app.displaySelectedModel(index);
                end
                state.Views.SelectedTab=state.Study.Tab;
                app.message(index,'モデリング・SHAP評価が終了しました。条件を比較してから保存対象を選んでください。');
                app.logTraining(index,struct('Function',state.Kind,'Rows',size(inputs,1),'Targets',{targets},'Conditions',numel(conditions),'Status','evaluated_before_save'));
            catch err
                app.closeProgress(progress); app.showError(index,err);
            end
        end
        function batchProgress(~,progress,event)
            progress.Message=sprintf('%s / %s / 条件 %d（全%d条件）',event.Target,event.Stage,event.Condition,event.Conditions); drawnow;
            if progress.CancelRequested, error('AnalysisApp:cancelled','モデリングを中止しました。既存の比較結果は保持し、今回の部分結果は追加しません。'); end
        end
        function displaySelectedModel(app,index)
            try
                state=app.Panels{index}; id=state.Study.selectedIdentifier(); selected=app.ModelRegistry(id); r=selected.Record;
                if isempty(r), error('modeling:noRecord','学習・評価したモデルを選択してください。'); end
                app.clearModelOutput(index); state=app.Panels{index}; state.SelectedModelKind=r.Kind; app.Panels{index}=state;
                context=struct('Names',{r.InputNames},'Source',r.Source,'Bins',r.Bins);
                app.displayEvaluation(index,r.Inputs,r.Actual,r.Prediction,[r.Target ' / ' r.Scope ' / ' r.Condition.Kernel ' / ' r.Condition.FitMethod],context);
                app.result(index,table(r.SourceRows,r.Actual,r.Prediction,r.Actual-r.Prediction,r.TrainingPrediction, ...
                    'VariableNames',{'SourceRow','Actual','Predicted','Residual','TrainingPredicted'}));
                if ~isempty(r.FoldId)
                    app.result(index,addvars(app.Panels{index}.Result,r.FoldId,'After','SourceRow','NewVariableNames','Fold'));
                    view=app.tableTab(state.Views,'検証分割'); view.Data=r.FoldMetrics;
                end
                if ~isempty(r.Details), app.displayPeriodicTraining(index,r.Details); end
                if ~isempty(r.Shap)
                    cached=r.Shap; cached.PeriodOptions=r.PeriodOptions;
                    app.runShap(index,r.Model,r.Shap.Inputs,true,r.SourceRows,'SourceRow',state.IsPlot.Value,cached);
                else
                    app.message(index,['このモデルのSHAPは未完了です。「SHAP実行」で再計算できます。 ' r.Note]);
                end
                app.applyTheme();
            catch err
                app.showError(index,err);
            end
        end
        function saveSelectedModel(app,index)
            try
                state=app.Panels{index}; id=state.Study.selectedIdentifier(); r=app.ModelRegistry(id).Record;
                if isempty(r), error('modeling:noRecord','保存する学習済みモデルを選んでください。'); end
                cleanup=app.lockControls(state.Study); %#ok<NASGU>
                [saved,report]=app.saveModel(index,r.Model,r.Condition.Kernel,r.Condition.FitMethod,size(r.Inputs,1),r.Target);
                if isempty(saved), return; end
                if ~report.Success, error('AnalysisApp:verificationFailed','%s',app.Constants.INVALID_MODEL_MESSAGE); end
                app.logTraining(index,struct('Function',r.Kind,'Target',r.Target,'SavePath',saved,'Status','selected_model_saved','Verification',table2struct(report.Checks)));
                state.Views.SelectedTab=state.Verification.Parent.Parent;
                app.message(index,['選択したモデルだけを保存・検証しました。SHAPの再計算は行いません: ' r.Target]);
            catch err
                app.showError(index,err);
            end
        end
        function [path,report]=saveModel(app,index,model,kernel,fit_method,rows,target)
            if nargin<7, target=''; end
            path=''; report=[]; state=app.Panels{index};
            [name,folder]=uiputfile('*.mat',['選択モデルを保存: ' char(target)],fullfile(app.Settings.SaveFolder,default_model_filename(state.Kind,target)));
            if isequal(name,0), return; end
            path=fullfile(folder,name); save_train_model(model,path);
            expected=struct('KernelFunction',char(kernel),'FitMethod',fit_method,'BasisFunction','constant','NumObservations',rows);
            report=verify_saved_model(path,model,state.Kind,expected); state.Verification.Data=report.Checks; app.message(index,report.Message);
        end
        function cleanup = lockControls(app, view)
            controls = findall(app.Window, '-property', 'Enable'); enabled = get(controls, 'Enable');
            if ~iscell(enabled), enabled = {enabled}; end
            set(controls, 'Enable', 'off'); cleanup = onCleanup(@() app.unlockControls(controls, enabled, view));
        end
        function unlockControls(~, controls, enabled, view)
            for item = 1:numel(controls)
                if isvalid(controls(item)), controls(item).Enable = enabled{item}; end
            end
            if ~isempty(view), view.setBusy(false); end
        end
        function closeProgress(~, progress)
            if ~isempty(progress) && isvalid(progress), close(progress); end
        end
        function periodProgress(~, progress, count, maximum, period)
            if isempty(progress), return; end
            progress.Message = sprintf('候補 %d / 最大%d：周期 %.7g\n候補ごとにGPRを学習し、周辺尤度を比較しています。', count, maximum, period);
            drawnow;
            if progress.CancelRequested, error('AnalysisApp:cancelled', '周期探索を中止しました。モデルは保存していません。'); end
        end
        function describeSwingKernel(app, index)
            state = app.Panels{index};
            if strcmpi(state.Kernel.Value, 'swingperiodic')
                state.ModelInfo.Value = {'swingperiodic：RESIST_THの周期カーネル'; ...
                    '周期の基準は露光波長÷屈折率。範囲を画面で変更できます。'; '候補ごとに再学習するため時間が増えます。'; '周期はGPRのKernelParametersには含めません。'};
            else
                state.ModelInfo.Value = {'BasisFunction: constant（固定）'};
            end
        end
        function displayPeriodicTraining(app, index, details)
            state = app.Panels{index};
            state.ModelInfo.Value = {sprintf('swingperiodic / 周期 %.8g（入力の膜厚単位）', details.Period); ...
                sprintf('%s %.8g / 評価 %d回', details.Criterion, details.LogLikelihood, details.Evaluations); ...
                sprintf('探索範囲 %.7g 〜 %.7g / fit_method=%s', details.SearchBounds, details.FitMethod); ...
                '周期はKernelParametersの外で最適化。大域最適性は未保証。'};
            view = app.tableTab(state.Views, '周期の最適化'); view.Data = details.Trace;
            tab = uitab(state.ChartTabs, 'Title', '周期探索（周辺尤度）'); layout = uigridlayout(tab, [1, 1]); ax = uiaxes(layout);
            valid = details.Trace.Succeeded; [periods, order] = sort(details.Trace.Period(valid)); likelihood = details.Trace.LogLikelihood(valid);
            plot(ax, periods, likelihood(order), '.-', 'DisplayName', '評価した候補'); hold(ax, 'on');
            scatter(ax, details.Period, details.LogLikelihood, 60, 'filled', 'DisplayName', '採用した周期');
            xlabel(ax, '周期（入力の膜厚単位）'); ylabel(ax, details.Criterion); title(ax, '大きい尤度の周期を採用');
            legend(ax, 'Location', 'best'); grid(ax, 'on'); app.registerCharts(index, {ax}, {'周期探索（周辺尤度）'});
            app.message(index, sprintf('内部最適化の周期 %.8g。探索履歴は「周期の最適化」で確認・保存できます。', details.Period));
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
        function displayEvaluation(app, index, inputs, actual, predicted, scope, context)
            state = app.Panels{index};
            if numel(actual) < 2, state.Headline.Text = '評価には実測値が2件以上必要です。'; return; end
            if nargin<7, context=struct('Names',{state.Mapping.Data(1:size(inputs,2),2)'},'Source',app.scatterSource(index,inputs,actual),'Bins',app.Settings.Bins); end
            metrics = evaluate_predictions(actual, predicted, context.Bins); state.Metrics.Data = display_metric_names(metrics);
            state.Headline.Text = sprintf('RMSE: %.6g    R²: %.6g    n = %d\n%s', metrics.Value(2), metrics.Value(1), numel(actual), scope);
            names = [string(context.Names), "Actual", "Predicted", "Residual"];
            state.Summary.Data = summarize_model_columns([inputs, actual, predicted, actual - predicted], names);
            source = context.Source;
            view = EvaluationScatterView(state.ChartTabs, actual, predicted, source);
            app.registerCharts(index, view.Axes, view.Names);
        end
        function runShap(app, index, model, matrix, is_training, source_rows, row_label, show_plot, cached)
            state = app.Panels{index};
            if nargin < 6, source_rows = state.Data.RowNumbers; end
            if nargin < 7, row_label = 'SourceRow'; end
            if nargin < 8, show_plot = state.IsPlot.Value; end
            if is_training && size(matrix, 1) > app.Constants.MAX_SHAP_POINTS
                app.message(index, 'SHAP は先頭1000件まで計算します。評価指標は全件で計算しています。'); matrix = matrix(1:app.Constants.MAX_SHAP_POINTS, :);
            end
            if ~isempty(state.ChartTabs.Children)
                old_tabs = state.ChartTabs.Children(startsWith(string({state.ChartTabs.Children.Title}), 'SHAP')); delete(old_tabs);
            end
            old_values = state.Views.Children(strcmp({state.Views.Children.Title}, 'SHAP 値')); delete(old_values);
            progress = uiprogressdlg(app.Window, 'Title', 'SHAP 解析', 'Message', 'SHAP 値を計算中', 'Indeterminate', 'on');
            cleanup = onCleanup(@() close(progress)); drawnow;
            if nargin>=9 && ~isempty(cached)
                explainer=cached.Explainer; shap_all=cached.Values;
                output=array2table(shap_all,'VariableNames',model.PredictorNames);
                output=addvars(output,source_rows(1:size(shap_all,1)),'Before',1,'NewVariableNames',row_label);
            elseif ~is_training && strcmp(state.Mode.Value, 'ノイズ除去用SHAP')
                [resist, explainer, shap_all] = denoise_for_swing_curve(model, matrix(:, 1:end-1), matrix(:, end));
                output = table(source_rows(1:numel(resist)), resist, 'VariableNames', {row_label, 'shap_resist'});
            else
                [explainer, shap_all] = calc_shap_dependence(model, matrix);
                output = array2table(shap_all, 'VariableNames', model.PredictorNames);
                output = addvars(output, source_rows(1:size(shap_all, 1)), 'Before', 1, 'NewVariableNames', row_label);
            end
            if is_training
                view = app.tableTab(state.Views, 'SHAP 値'); view.Data = output;
            else
                app.result(index, output);
            end
            clear cleanup;
            if show_plot
                options = struct('Edition', app.Edition, 'AllowSwingFit', ~strcmp(state.Kind, 'apc'), 'PeriodOptions', swing_period_options());
                options.Explainer = explainer;
                if isfield(state, 'SelectedModelKind') && strcmp(state.SelectedModelKind, 'apc'), options.AllowSwingFit = false; end
                if nargin>=9 && isfield(cached,'PeriodOptions')
                    options.PeriodOptions=cached.PeriodOptions;
                elseif options.AllowSwingFit && any(strcmp(model.PredictorNames,'RESIST_TH'))
                    options.PeriodOptions=app.periodOptions(2);
                end
                [charts, names] = plot_shap_figures(state.ChartTabs, shap_all, matrix, model.PredictorNames, options); app.registerCharts(index, charts, names);
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
            [design, details] = create_experiment_design(method, state.Factors.Value, state.Runs.Value, app.Settings.Seed, ...
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
                if strcmp(state.Views.SelectedTab.Title,'条件比較・モデル保存')
                    data=state.Study.currentTable();
                elseif strcmp(state.Views.SelectedTab.Title, 'カーネル比較')
                    data = state.Comparison.currentTable();
                elseif strcmp(state.Views.SelectedTab.Title, 'グラフ')
                    chart_tab = state.ChartTabs.SelectedTab;
                    if ~isempty(chart_tab) && isa(chart_tab.UserData, 'SwingCurveView'), data = chart_tab.UserData.currentTable(); end
                else
                    view = findobj(state.Views.SelectedTab, 'Type', 'uitable');
                    if ~isempty(view), data = view(1).Data; end
                end
                if isempty(data), error('AnalysisApp:noResult', '結果・評価・要約・Swing Curve近似などの表を選択してください。'); end
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
                state = app.Panels{index};
                valid = cellfun(@(chart) isgraphics(chart) && (~isa(chart, 'matlab.ui.control.UIAxes') || ~isempty(chart.Children)), state.Figures);
                charts = state.Figures(valid); names = state.FigureNames(valid);
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
        function copyFigure(app, index)
            try
                state = app.Panels{index}; copied_name = copy_app_chart(state.Figures, state.FigureNames);
                if ~isempty(copied_name), app.message(index, ['クリップボードにコピーしました: ' copied_name]); end
            catch err
                app.showError(index, err);
            end
        end
        function createSettings(app, tab)
            layout = uigridlayout(tab, [16, 1], 'Scrollable', 'on'); layout.RowHeight = {48, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 32, 36, 70};
            uilabel(layout, 'Text', '保存した設定は次回起動にも反映します。適用時は現在の評価結果と列対応の確認を解除します。', 'WordWrap', 'on');
            row = uigridlayout(layout, [1, 3]); row.ColumnWidth = {150, '1x', 100}; row.Padding = [0, 0, 0, 0];
            uilabel(row, 'Text', 'デフォルト保存先'); app.SettingsUI.SaveFolder = uieditfield(row, 'Value', app.Settings.SaveFolder);
            uibutton(row, 'Text', 'フォルダ選択', 'ButtonPushedFcn', @(~, ~) app.chooseFolder());
            app.SettingsUI.Theme = app.choiceRow(layout, 'カラーテーマ', {'ライト', 'ダーク'});
            app.SettingsUI.Kernel = app.choiceRow(layout, '既定 kernel', app.Constants.KERNELS);
            app.SettingsUI.SwingKernel = app.choiceRow(layout, 'Swing Curve専用 kernel', app.Constants.SWING_KERNELS);
            app.SettingsUI.FitMethod = app.choiceRow(layout, '既定 fit_method', app.Constants.FIT_METHODS);
            app.SettingsUI.InputCount = app.numberRow(layout, '汎用 GPR の説明変数数', app.Settings.InputCount, [1, 100]);
            app.SettingsUI.Bins = app.numberRow(layout, '全画面共通 KL / MI ビン数（0=自動）', app.Settings.Bins, [0, 1000]);
            app.SettingsUI.Factors = app.numberRow(layout, '実験計画の因子数', app.Settings.Factors, [1, 8]);
            app.SettingsUI.Runs = app.numberRow(layout, '実験数 / 追加数', app.Settings.Runs, [1, 300]);
            app.SettingsUI.Seed = app.numberRow(layout, '実験計画の seed', app.Settings.Seed, [0, 2^32 - 1]);
            app.SettingsUI.RBFWidth = app.decimalRow(layout, '炉内補間 RBF幅（0=自動）', app.Settings.RBFWidth, [0,Inf]);
            app.SettingsUI.RBFRidge = app.decimalRow(layout, '炉内補間 RBF正則化', app.Settings.RBFRidge, [1e-12,1]);
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
                    if any(strcmp(state.Kind, {'apc', 'swing', 'generic'}))
                        state.Kernel.Value = app.Settings.Kernel; state.FitMethod.Value = app.Settings.FitMethod;
                        if strcmp(state.Kind, 'swing'), state.Kernel.Value = app.Settings.SwingKernel; end
                    end
                    if any(strcmp(state.Kind, {'apc', 'generic', 'shap'})), state.IsPlot.Value = app.Settings.ShowPlots; end
                    if strcmp(state.Kind, 'generic'), state.InputCount.Value = app.Settings.InputCount; end
                    if strcmp(state.Kind, 'doe'), state.Factors.Value = app.Settings.Factors; state.Runs.Value = app.Settings.Runs; end
                    if ~strcmp(state.Kind, 'words'), app.updateMapping(index); end
                end
                if ~isempty(app.Furnace), app.Furnace.applySettings(app.Settings); end
                app.applyTheme(); app.SettingsUI.Message.Text = ['保存・適用しました: ' app.SettingsPath];
            catch err
                uialert(app.Window, err.message, '設定を保存できませんでした');
            end
        end
        function applyTheme(app)
            apply_app_theme(app.Window, app.Settings.Theme);
            app.MainTabs.applyTheme(app.Settings.Theme);
        end
    end
end
