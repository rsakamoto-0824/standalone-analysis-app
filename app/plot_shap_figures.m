function [charts, names] = plot_shap_figures(parent, shap_all, inputs, predictor_names, options)
if nargin < 5, options = struct(); end
if ~isfield(options, 'AllowSwingFit'), options.AllowSwingFit = false; end
if ~isfield(options, 'Edition'), options.Edition = app_edition(); end
if ~isfield(options, 'PeriodOptions'), options.PeriodOptions = swing_period_options(); end
if isdeployed && ~strcmp(app_edition(), 'pro'), options.AllowSwingFit = false; end
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
if isfield(options, 'Explainer') && isa(options.Explainer, 'shapley')
    swarmchart(ax, options.Explainer, 'NumImportantPredictors', numel(predictor_names));
else
    % 合成値による表示試験だけは、shapleyオブジェクトなしで標準の描画関数を呼ぶ。
    for position = 1:numel(order)
        column = order(position);
        values = inputs(:, column); span = max(values) - min(values);
        if span > 0, colors = (values - min(values)) / span; else, colors = 0.5 * ones(size(values)); end
        points = swarmchart(ax, shap_all(:, column), repmat(position, size(inputs, 1), 1), 12, colors, 'filled');
        points.XJitter = 'none';
        if isprop(points, 'YJitter'), points.YJitter = 'density'; end
    end
    ax.YTick = 1:numel(order); ax.YTickLabel = predictor_names(order); ax.YDir = 'reverse';
    ax.TickLabelInterpreter = 'none'; ax.YLim = [0.5, numel(order) + 0.5];
    xlabel(ax, 'SHAP value'); title(ax, 'SHAP分布（swarmchart / 平均 |SHAP| 順）');
    colormap(ax, parula); clim(ax, [0, 1]); scale = colorbar(ax);
    scale.Label.String = '入力値（列ごとに0〜1へ規格化）';
end
for position = 1:numel(order)
    column = order(position); names{position + 1} = ['SHAP 依存: ' predictor_names{column}];
    tab = uitab(parent, 'Title', names{position + 1});
    others = order(order ~= column);
    if strcmp(predictor_names{column}, 'RESIST_TH') && options.AllowSwingFit && strcmp(options.Edition, 'pro')
        color_values = []; color_name = '';
        if ~isempty(others), color_values = inputs(:, others(1)); color_name = predictor_names{others(1)}; end
        % 通常版のビルドからProクラスを完全に除くため、直接の静的依存を作らない。
        view = feval('SwingCurveView', tab, inputs(:, column), shap_all(:, column), color_values, color_name, options); %#ok<FVAL>
        charts{position + 1} = view.Axes;
        diagnostic_charts = {view.DiagnosticAxes.Histogram, view.DiagnosticAxes.QQ, view.DiagnosticAxes.Residual};
        diagnostic_names = {'SHAP Swing Curve近似: 残差分布', 'SHAP Swing Curve近似: 正規Q–Q', 'SHAP Swing Curve近似: 残差対膜厚'};
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
    if strcmp(predictor_names{column}, 'RESIST_TH'), ax.XAxis.Exponent = 0; xtickformat(ax, '%.6f'); end
end
charts = [charts, diagnostic_charts]; names = [names, diagnostic_names];
end
