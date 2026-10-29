function [charts, names] = plot_shap_figures(parent, shap_all, inputs, predictor_names)
% SHAP の計算結果を親タブ内に描画する。外部 figure は作らない。
if ~isequal(size(shap_all), size(inputs))
    error('plot_shap_figures:shape', 'SHAP 値と説明変数の形状が一致しません。');
end
[~, order] = sort(mean(abs(shap_all), 1), 'descend');
charts = cell(1, numel(order) + 1); names = cell(size(charts));
diagnostic_charts = {}; diagnostic_names = {};
names{1} = 'SHAP 分布';
tab = uitab(parent, 'Title', names{1}); layout = uigridlayout(tab, [1, 1]);
ax = uiaxes(layout); charts{1} = ax; hold(ax, 'on');
for position = 1:numel(order)
    column = order(position);
    swarmchart(ax, repmat(position, size(inputs, 1), 1), shap_all(:, column), 12, 'filled');
end
ax.XTick = 1:numel(order); ax.XTickLabel = predictor_names(order);
ax.TickLabelInterpreter = 'none'; ax.XTickLabelRotation = 25;
ylabel(ax, 'SHAP value'); title(ax, '平均 |SHAP| の大きい順');
for position = 1:numel(order)
    column = order(position); names{position + 1} = ['SHAP 依存: ' predictor_names{column}];
    tab = uitab(parent, 'Title', names{position + 1});
    others = order(order ~= column);
    if strcmp(predictor_names{column}, 'RESIST_TH')
        color_values = []; color_name = '';
        if ~isempty(others), color_values = inputs(:, others(1)); color_name = predictor_names{others(1)}; end
        view = SwingCurveView(tab, inputs(:, column), shap_all(:, column), color_values, color_name);
        charts{position + 1} = view.Axes;
        diagnostic_charts = {view.DiagnosticAxes.Histogram, view.DiagnosticAxes.QQ, view.DiagnosticAxes.Residual};
        diagnostic_names = {'SHAPスイング近似: 残差分布', 'SHAPスイング近似: 正規Q–Q', 'SHAPスイング近似: 残差対膜厚'};
        continue;
    end
    layout = uigridlayout(tab, [1, 1]); ax = uiaxes(layout); charts{position + 1} = ax;
    if isempty(others)
        scatter(ax, inputs(:, column), shap_all(:, column), 18, 'filled');
    else
        color_column = others(1);
        scatter(ax, inputs(:, column), shap_all(:, column), 18, inputs(:, color_column), 'filled');
        scale = colorbar(ax); scale.Label.String = predictor_names{color_column}; scale.Label.Interpreter = 'none';
    end
    xlabel(ax, predictor_names{column}, 'Interpreter', 'none'); ylabel(ax, 'SHAP value');
    title(ax, names{position + 1}, 'Interpreter', 'none');
end
charts = [charts, diagnostic_charts]; names = [names, diagnostic_names];
end
