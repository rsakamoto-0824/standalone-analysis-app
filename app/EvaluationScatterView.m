classdef EvaluationScatterView < handle
    properties (SetAccess = private)
        Axes
        Choices
        Names = {'実測値と予測値', '残差'}
    end
    properties (Access = private)
        Actual
        Predicted
        Source
    end
    methods
        function view = EvaluationScatterView(parent, actual, predicted, source)
            view.Actual = actual(:); view.Predicted = predicted(:); view.Source = source;
            view.Axes = cell(1, 2); view.Choices = cell(1, 2);
            for index = 1:2
                tab = uitab(parent, 'Title', view.Names{index}); tab.UserData = view;
                grid = uigridlayout(tab, [2, 1]); grid.RowHeight = {32, '1x'};
                row = uigridlayout(grid, [1, 2]); row.ColumnWidth = {100, '1x'}; row.Padding = [0, 0, 0, 0];
                uilabel(row, 'Text', '色を指定する列');
                view.Choices{index} = uidropdown(row, 'Items', [{'(単色)'}, source.Headers], ...
                    'ValueChangedFcn', @(field, ~) view.update(field.Value));
                view.Axes{index} = uiaxes(grid);
            end
            view.update('(単色)');
        end
        function update(view, column)
            for index = 1:2
                view.Choices{index}.Value = column;
                ax = view.Axes{index}; cla(ax); colorbar(ax, 'off'); hold(ax, 'on');
                if index == 1
                    x = view.Actual; y = view.Predicted;
                else
                    x = view.Predicted; y = view.Actual - view.Predicted;
                end
                color_scatter(ax, x, y, view.Source, column);
                if index == 1
                    limits = [min([x; y]), max([x; y])]; plot(ax, limits, limits, '--');
                    xlabel(ax, 'Actual'); ylabel(ax, 'Predicted');
                else
                    yline(ax, 0, '--'); xlabel(ax, 'Predicted'); ylabel(ax, 'Actual - Predicted');
                end
                title(ax, view.Names{index}); grid(ax, 'on');
                window = ancestor(ax, 'figure');
                if mean(window.Color) < 0.5, apply_app_theme(ax, 'ダーク'); end
            end
        end
    end
end
