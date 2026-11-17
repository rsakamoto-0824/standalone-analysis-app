classdef EvaluationScatterView < handle
    % 「実測値と予測値」と「残差」の散布図を、1つのタブに横並びで表示する。
    % 色の列は2つの図で共通。書出しでは2つを並べた図、または片方だけを選べる。
    properties (SetAccess = private)
        Axes
        Panel
        Choice
        Tab
        Names = {'実測値と予測値', '残差'}
    end
    properties (Constant)
        TAB_TITLE = '実測値と予測値・残差'
        COMBINED_NAME = '実測値と予測値・残差（2つ並べた図）'
    end
    properties (Access = private)
        Actual
        Predicted
        Source
    end
    methods
        function view = EvaluationScatterView(parent, actual, predicted, source)
            view.Actual = actual(:); view.Predicted = predicted(:); view.Source = source;
            view.Tab = uitab(parent, 'Title', view.TAB_TITLE); view.Tab.UserData = view;
            grid = uigridlayout(view.Tab, [2, 1]); grid.RowHeight = {32, '1x'}; grid.Padding = [4, 4, 4, 4];
            row = uigridlayout(grid, [1, 3]); row.ColumnWidth = {130, 260, '1x'}; row.Padding = [0, 0, 0, 0];
            uilabel(row, 'Text', '色を指定する列');
            view.Choice = uidropdown(row, 'Items', [{'(単色)'}, source.Headers], ...
                'Tooltip', '入力ファイルの任意の列で点を色分けします。評価値は変わりません。', ...
                'ValueChangedFcn', @(field, ~) view.update(field.Value));
            uilabel(row, 'Text', '');
            % 2つの図を1つの入れ物に入れ、並べた図としてもコピー・保存できるようにする。
            view.Panel = uipanel(grid, 'BorderType', 'none');
            plots = uigridlayout(view.Panel, [1, 2]); plots.Padding = [0, 0, 0, 0]; plots.ColumnSpacing = 12;
            view.Axes = {uiaxes(plots), uiaxes(plots)};
            view.update('(単色)');
        end
        function [charts, names] = charts(view)
            % ResultPanel へ登録する図。並べた図を先頭にする。
            charts = [{view.Panel}, view.Axes]; names = [{view.COMBINED_NAME}, view.Names];
        end
        function update(view, column)
            view.Choice.Value = column;
            for index = 1:2
                ax = view.Axes{index}; cla(ax); colorbar(ax, 'off'); hold(ax, 'on');
                if index == 1
                    x = view.Actual; y = view.Predicted;
                else
                    x = view.Predicted; y = view.Actual - view.Predicted;
                end
                color_scatter(ax, x, y, view.Source, column);
                if index == 1
                    limits = [min([x; y]), max([x; y])]; plot(ax, limits, limits, '--', 'DisplayName', 'y = x');
                    xlabel(ax, '実測値（Actual）'); ylabel(ax, '予測値（Predicted）');
                else
                    yline(ax, 0, '--'); xlabel(ax, '予測値（Predicted）'); ylabel(ax, '残差（実測 − 予測）');
                end
                title(ax, view.Names{index}); grid(ax, 'on');
                window = ancestor(ax, 'figure');
                if mean(window.Color) < 0.5, apply_app_theme(ax, 'ダーク'); end
            end
        end
    end
end
