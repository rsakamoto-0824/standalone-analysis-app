classdef SettingsPage < AppPage
    % 設定の画面。保存した内容は次回の起動にも反映する。
    % 設定を変えても、表示中の結果や学習済みモデルの一覧は消さない（次の実行から反映）。
    properties (SetAccess = private)
        Fields = struct()
        PathInfo
    end
    properties (Constant)
        LABEL_WIDTH = 300
        FIELD_WIDTH = 320
        THEMES = {'ライト', 'ダーク'}
        MAX_BINS = 1000
        MAX_FACTORS = 8
        MAX_RUNS = 300
        MAX_SEED = 2^32 - 1
    end
    methods
        function page = SettingsPage(app, parent)
            page@AppPage(app, parent);
            constants = app.Constants; limits = furnace_constants();
            % 保存ボタンは常に見える位置へ置き、項目の一覧だけをスクロールさせる。
            outer = uigridlayout(page.Body, [3, 1]); outer.RowHeight = {40, '1x', 36}; outer.Padding = [0, 0, 0, 0];
            AppPage.hint(outer, ['ここで保存した設定は次回の起動にも反映します。Fit method・KL/MIビン数・実験計画のseed・炉内補間のRBF条件は、' ...
                'この画面だけで変更します。変更は次の実行から反映し、表示中の結果や学習済みモデルの一覧は消えません。']);
            grid = uigridlayout(outer, [17, 3], 'Scrollable', 'on'); grid.RowHeight = repmat({28}, 1, 17); grid.RowSpacing = 6;
            grid.ColumnWidth = {page.LABEL_WIDTH, page.FIELD_WIDTH, '1x'};
            page.heading(grid, '共通');
            page.label(grid, 'ファイルの保存先（最初に開くフォルダ）');
            row = uigridlayout(grid, [1, 2]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {'1x', 80};
            page.Fields.SaveFolder = uieditfield(row, 'text');
            uibutton(row, 'Text', '選択…', 'ButtonPushedFcn', @(~, ~) page.chooseFolder());
            page.note(grid, '');
            page.label(grid, 'カラーテーマ');
            page.Fields.Theme = uidropdown(grid, 'Items', page.THEMES); page.note(grid, '');
            page.heading(grid, 'ガウス過程回帰（GPR）');
            page.label(grid, 'カーネルの初期値（APC・汎用回帰）');
            page.Fields.Kernel = uidropdown(grid, 'Items', constants.KERNELS); page.note(grid, '');
            page.label(grid, 'カーネルの初期値（Swing Curve）');
            % swingperiodic（周期カーネル）は Pro 版だけの選択肢。
            swing_kernels = constants.KERNELS; if strcmp(app.Edition, 'pro'), swing_kernels = constants.SWING_KERNELS; end
            page.Fields.SwingKernel = uidropdown(grid, 'Items', swing_kernels); page.note(grid, '');
            page.label(grid, 'Fit method（すべてのGPRに共通）');
            page.Fields.FitMethod = uidropdown(grid, 'Items', constants.FIT_METHODS);
            page.note(grid, 'exact が標準。sd / sr / fic は行数が多いときの近似です。');
            page.heading(grid, '評価とSHAP');
            page.label(grid, 'KL / 相互情報量のビン数（0＝自動）');
            page.Fields.Bins = page.integerField(grid, [0, page.MAX_BINS]); page.note(grid, '0、または2〜1000。全画面で同じ値を使います。');
            page.Fields.ShowPlots = uicheckbox(grid, 'Text', '学習時のSHAP計算・SHAPグラフ表示を初期状態でオンにする');
            page.Fields.ShowPlots.Layout.Column = [1, 3];
            page.heading(grid, '実験計画');
            page.label(grid, '因子数の初期値');
            page.Fields.Factors = page.integerField(grid, [1, page.MAX_FACTORS]); page.note(grid, '');
            page.label(grid, '実験数の初期値（拡張では追加数）');
            page.Fields.Runs = page.integerField(grid, [1, page.MAX_RUNS]); page.note(grid, '');
            page.label(grid, '乱数seed');
            page.Fields.Seed = page.integerField(grid, [0, page.MAX_SEED]); page.note(grid, '同じseedなら同じ計画を再現できます。');
            page.heading(grid, '炉内補間');
            page.label(grid, 'RBFの幅（0＝自動）');
            page.Fields.RBFWidth = uieditfield(grid, 'numeric', 'Limits', [0, Inf], 'ValueDisplayFormat', '%.9g');
            page.note(grid, '0 は計測Slot間隔の中央値の2倍。単位はSlot。');
            page.label(grid, 'RBFの正則化');
            page.Fields.RBFRidge = uieditfield(grid, 'numeric', 'Limits', [limits.MinimumRBFRidge, limits.MaximumRBFRidge], 'ValueDisplayFormat', '%.9g');
            page.note(grid, sprintf('%g 〜 %g', limits.MinimumRBFRidge, limits.MaximumRBFRidge));
            row = uigridlayout(outer, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {220, 220, '1x'};
            AppPage.primaryButton(row, '設定を保存して適用', @(~, ~) page.save());
            uibutton(row, 'Text', '初期値を画面に戻す（保存前）', 'ButtonPushedFcn', @(~, ~) page.fill(app_settings('defaults')));
            page.PathInfo = uilabel(row, 'Text', ['設定ファイル: ' app.SettingsPath], 'Interpreter', 'none');
            page.fill(app.Settings);
            page.message('値を変更したら「設定を保存して適用」を押してください。');
        end
        function fill(page, values)
            names = fieldnames(page.Fields);
            for index = 1:numel(names)
                field = page.Fields.(names{index}); value = values.(names{index});
                % 通常版で、Pro 版の設定（swingperiodic）が保存されていた場合は初期値に戻す。
                if any(strcmp(names{index}, {'Kernel', 'SwingKernel'})) && ~any(strcmp(field.Items, value)), value = page.App.Constants.DEFAULT_KERNEL; end
                field.Value = value;
            end
        end
        function save(page)
            try
                proposed = page.settings(); names = fieldnames(page.Fields);
                for index = 1:numel(names), proposed.(names{index}) = page.Fields.(names{index}).Value; end
                page.App.applySettings(proposed);
                page.message('設定を保存して適用しました。次の実行から反映します。');
            catch err
                page.showError(err);
            end
        end
    end
    methods (Access = private)
        function chooseFolder(page)
            folder = uigetdir(page.Fields.SaveFolder.Value, 'ファイルの保存先');
            figure(page.App.Window);
            if ~isequal(folder, 0), page.Fields.SaveFolder.Value = folder; end
        end
        function heading(~, grid, text)
            label = uilabel(grid, 'Text', text, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom'); label.Layout.Column = [1, 3];
        end
        function label(~, grid, text)
            uilabel(grid, 'Text', text);
        end
        function note(~, grid, text)
            uilabel(grid, 'Text', text);
        end
        function field = integerField(~, grid, limits)
            field = uieditfield(grid, 'numeric', 'Limits', limits, 'RoundFractionalValues', 'on');
        end
    end
end
