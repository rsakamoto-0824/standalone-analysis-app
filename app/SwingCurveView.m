classdef SwingCurveView < handle
    properties (SetAccess = private)
        Axes
        Controls
        Summary
        Tables
        TableTabs
        Layout
        Fit = []
    end
    properties (Access = private)
        Thickness
        Contribution
        Colors
        ColorName
    end
    methods
        function view = SwingCurveView(parent, thickness, contribution, colors, color_name)
            view.Thickness = thickness(:); view.Contribution = contribution(:);
            view.Colors = colors; view.ColorName = color_name;
            layout = uigridlayout(parent, [4, 1], 'Scrollable', 'on');
            layout.RowHeight = {64, 66, 330, 155}; view.Layout = layout;
            controls = uigridlayout(layout, [2, 6]); controls.Padding = [0, 0, 0, 0];
            controls.Layout.Row = 1; controls.Layout.Column = 1;
            controls.RowHeight = {30, 30}; controls.RowSpacing = 4; controls.ColumnSpacing = 6;
            controls.ColumnWidth = {70, '1x', 70, '1x', 150, 94};
            uilabel(controls, 'Text', '膜厚下限');
            view.Controls.RangeMin = uieditfield(controls, 'numeric', 'Value', min(thickness));
            uilabel(controls, 'Text', '膜厚上限');
            view.Controls.RangeMax = uieditfield(controls, 'numeric', 'Value', max(thickness));
            view.Controls.Trend = uicheckbox(controls, 'Text', '直線トレンドを含む', 'Value', true);
            view.Controls.Update = uibutton(controls, 'Text', '近似を更新', 'ButtonPushedFcn', @(~, ~) view.refit());
            uilabel(controls, 'Text', '周期下限');
            view.Controls.PeriodMin = uieditfield(controls, 'numeric', 'Limits', [0, Inf], 'Value', 0);
            uilabel(controls, 'Text', '周期上限');
            view.Controls.PeriodMax = uieditfield(controls, 'numeric', 'Limits', [0, Inf], 'Value', 0);
            hint = uilabel(controls, 'Text', '周期0/0＝自動。単位は入力のまま。', 'WordWrap', 'on'); hint.Layout.Column = [5, 6];
            view.Summary = uilabel(layout, 'Text', '近似前', 'WordWrap', 'on');
            view.Summary.Layout.Row = 2; view.Summary.Layout.Column = 1;
            plot_panel = uipanel(layout, 'BorderType', 'none'); plot_panel.Layout.Row = 3; plot_panel.Layout.Column = 1;
            plot_layout = uigridlayout(plot_panel, [1, 1]); plot_layout.Padding = [0, 0, 0, 0];
            view.Axes = uiaxes(plot_layout);
            view.TableTabs = uitabgroup(layout);
            view.TableTabs.Layout.Row = 4; view.TableTabs.Layout.Column = 1;
            view.Tables.Metrics = view.tableTab('近似指標');
            view.Tables.Extrema = view.tableTab('極値の膜厚');
            view.Tables.Slopes = view.tableTab('隣接する山・谷の傾き');
            fields = {'RangeMin', 'RangeMax', 'PeriodMin', 'PeriodMax', 'Trend'};
            for index = 1:numel(fields)
                view.Controls.(fields{index}).ValueChangedFcn = @(~, ~) view.clearFit();
            end
            parent.UserData = view;
            view.refit();
        end

        function refit(view)
            view.clearFit();
            try
                range = [view.Controls.RangeMin.Value, view.Controls.RangeMax.Value];
                if range(1) >= range(2), error('SwingCurveView:range', '膜厚下限は上限より小さくしてください。'); end
                if range(1) < min(view.Thickness) || range(2) > max(view.Thickness)
                    error('SwingCurveView:range', '表示範囲は読込データの膜厚範囲内で指定してください。');
                end
                periods = [view.Controls.PeriodMin.Value, view.Controls.PeriodMax.Value];
                if all(periods == 0), periods = [];
                elseif any(periods == 0), error('SwingCurveView:period', '周期は両方0（自動）、または両方正の値で指定してください。'); end
                selected = view.Thickness >= range(1) & view.Thickness <= range(2);
                fit = fit_swing_curve(view.Thickness(selected), view.Contribution(selected), ...
                    struct('PeriodBounds', periods, 'IncludeTrend', view.Controls.Trend.Value));
                [extrema, segments] = swing_curve_extrema(fit, range);
                view.Fit = fit;
                view.Tables.Metrics.Data = table(["Period"; "Amplitude"; "R2_SHAP_fit"; "RMSE_SHAP_fit"; "BulkSlope"; ...
                    "OffsetAtCenter"; "CenterThickness"; "PhaseRadians"; "IncludeLinearTrend"; "Count"; "RangeMin"; "RangeMax"; "PeriodMin"; "PeriodMax"], ...
                    [fit.Period; fit.Amplitude; fit.RSquared; fit.RMSE; fit.Slope; fit.Offset; fit.Center; fit.PhaseRadians; double(fit.IncludeTrend); ...
                    fit.Count; range'; fit.SearchBounds'], 'VariableNames', {'Metric', 'Value'});
                view.Tables.Extrema.Data = extrema; view.Tables.Slopes.Data = segments;
                view.drawFit(fit, range, extrema, segments);
                messages = fit.Warnings;
                if isempty(extrema), messages(end + 1) = "この範囲に極大・極小はありません。";
                elseif isempty(segments), messages(end + 1) = "同種の極値が2個ないため隣接傾きは算出しません。"; end
                view.Summary.Text = sprintf('SHAP近似: 周期 %.6g / 振幅 %.6g / R² %.6g / RMSE %.6g / n=%d\n直線傾き %.6g（SHAP値/膜厚単位）。一定振幅モデルでは山間・谷間の傾きは同じです。\n%s', ...
                    fit.Period, fit.Amplitude, fit.RSquared, fit.RMSE, fit.Count, fit.Slope, strjoin(messages, ' '));
                view.Summary.Tooltip = view.Summary.Text;
                window = ancestor(view.Axes, 'figure');
                if mean(window.Color) < 0.5, theme = 'ダーク'; else, theme = 'ライト'; end
                apply_app_theme(window, theme);
            catch err
                view.Summary.Text = ['近似できません: ' err.message];
                view.Summary.Tooltip = view.Summary.Text;
            end
        end

        function clearFit(view)
            view.Fit = []; view.Summary.Text = '設定を変更したら「近似を更新」を押してください。';
            fields = fieldnames(view.Tables);
            for index = 1:numel(fields), view.Tables.(fields{index}).Data = table(); end
            ax = view.Axes; cla(ax); hold(ax, 'on');
            if isempty(view.Colors)
                scatter(ax, view.Thickness, view.Contribution, 18, 'filled', 'DisplayName', 'SHAP値');
            else
                scatter(ax, view.Thickness, view.Contribution, 18, view.Colors, 'filled', 'DisplayName', 'SHAP値');
                scale = colorbar(ax); scale.Label.String = view.ColorName; scale.Label.Interpreter = 'none';
            end
            xlabel(ax, 'RESIST_TH（入力の膜厚単位）', 'Interpreter', 'none'); ylabel(ax, 'SHAP値（応答と同じ単位）');
            title(ax, 'RESIST_TH の SHAP 依存図', 'Interpreter', 'none');
            ax.XLimMode = 'auto'; ax.YLimMode = 'auto'; legend(ax, 'off');
        end

        function data = currentTable(view)
            table_view = findobj(view.TableTabs.SelectedTab, 'Type', 'uitable'); data = table_view(1).Data;
        end
    end
    methods (Access = private)
        function result = tableTab(view, label)
            tab = uitab(view.TableTabs, 'Title', label); layout = uigridlayout(tab, [1, 1]);
            result = uitable(layout, 'Data', table());
        end

        function drawFit(view, fit, range, extrema, segments)
            ax = view.Axes; grid = linspace(range(1), range(2), max(1001, ceil(30 * diff(range) / fit.Period)));
            label = '正弦波＋オフセット';
            if fit.IncludeTrend, label = [label '＋直線トレンド']; end
            plot(ax, grid, swing_curve_values(fit, grid), 'LineWidth', 1.8, 'Color', [0.9, 0.35, 0.1], 'DisplayName', label);
            types = ["極大", "極小"]; colors = {[0.75, 0.2, 0.65], [0.1, 0.65, 0.65]};
            for kind = 1:2
                rows = extrema.Type == types(kind); points = extrema(rows, :);
                if isempty(points), continue; end
                scatter(ax, points.Thickness, points.SHAP, 45, colors{kind}, 'filled', 'DisplayName', char(types(kind)));
                if height(points) >= 2
                    plot(ax, points.Thickness, points.SHAP, '--', 'Color', colors{kind}, 'LineWidth', 1.3, ...
                        'DisplayName', sprintf('%s間 m=%.5g', types(kind), fit.Slope));
                end
                if kind == 1, alignment = 'bottom'; else, alignment = 'top'; end
                if height(extrema) <= 24
                    text(ax, points.Thickness, points.SHAP, cellstr(compose('%s %.6g', types(kind), points.Thickness)), ...
                        'VerticalAlignment', alignment, 'HorizontalAlignment', 'center', 'FontSize', 9, 'Clipping', 'on');
                end
            end
            ax.XLim = range;
            title(ax, sprintf('SHAP スイング近似 / 周期 %.5g / 振幅 %.5g / R² %.4g / RMSE %.4g', ...
                fit.Period, fit.Amplitude, fit.RSquared, fit.RMSE), 'Interpreter', 'none');
            legend(ax, 'Location', 'best'); ax.XGrid = 'on'; ax.YGrid = 'on';
            if height(segments) > 0, view.TableTabs.SelectedTab = view.Tables.Slopes.Parent.Parent; end
        end
    end
end
