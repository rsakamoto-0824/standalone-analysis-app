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
drawn = false;
if isfield(options, 'Explainer') && isa(options.Explainer, 'shapley')
    try
        swarmchart(ax, options.Explainer, 'NumImportantPredictors', numel(predictor_names)); drawn = true;
    catch
        % shapleyオブジェクトから直接描けない場合も、同じSHAP値を標準のswarmchartで描いて表示を続ける。
        cla(ax); hold(ax, 'on');
    end
end
if ~drawn
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
    % 色の初期値は、自身を除いて最も重要な説明変数（原仕様5.6）。画面の「色の変数」で任意に変更できる。
    others = order(order ~= column); default_color = 0;
    if ~isempty(others), default_color = others(1); end
    if strcmp(predictor_names{column}, 'RESIST_TH') && options.AllowSwingFit && strcmp(options.Edition, 'pro')
        options.ColorDefault = default_color;
        % 通常版のビルドからProクラスを完全に除くため、直接の静的依存を作らない。
        view = feval('SwingCurveView', tab, inputs(:, column), shap_all(:, column), inputs, predictor_names, options); %#ok<FVAL>
        charts{position + 1} = view.Axes;
        diagnostic_charts = {view.DiagnosticAxes.Histogram, view.DiagnosticAxes.QQ, view.DiagnosticAxes.Residual};
        diagnostic_names = {'SHAP Swing Curve近似: 残差分布', 'SHAP Swing Curve近似: 正規Q–Q', 'SHAP Swing Curve近似: 残差対膜厚'};
        continue;
    end
    charts{position + 1} = dependenceChart(tab, inputs, shap_all(:, column), predictor_names, column, default_color, names{position + 1});
end
charts = [charts, diagnostic_charts]; names = [names, diagnostic_names];
end

function ax = dependenceChart(tab, inputs, shap_values, predictor_names, column, default_color, title_text)
% SHAP依存図。上の「色の変数」で、点の色に使う説明変数を選び直せる。
NO_COLOR = 0;
layout = uigridlayout(tab, [2, 1]); layout.RowHeight = {30, '1x'}; layout.Padding = [4, 4, 4, 4];
row = uigridlayout(layout, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {150, 260, '1x'};
uilabel(row, 'Text', '色の変数（説明変数）');
choice = uidropdown(row, 'Items', [{'(単色)'}, predictor_names(:)'], 'ItemsData', [NO_COLOR, 1:numel(predictor_names)], ...
    'Value', default_color, 'Tooltip', '点の色に使う説明変数を選びます。SHAP値や評価は変わりません。');
uilabel(row, 'Text', '');
ax = uiaxes(layout);
choice.ValueChangedFcn = @(field, ~) draw(field.Value);
draw(default_color);

    function draw(color_column)
        cla(ax); colorbar(ax, 'off');
        if color_column == NO_COLOR
            scatter(ax, inputs(:, column), shap_values, 18, 'filled');
        else
            scatter(ax, inputs(:, column), shap_values, 18, inputs(:, color_column), 'filled');
            scale = colorbar(ax); scale.Label.String = predictor_names{color_column}; scale.Label.Interpreter = 'none';
        end
        xlabel(ax, predictor_names{column}, 'Interpreter', 'none'); ylabel(ax, 'SHAP value');
        title(ax, title_text, 'Interpreter', 'none'); grid(ax, 'on');
        if strcmp(predictor_names{column}, 'RESIST_TH'), ax.XAxis.Exponent = 0; xtickformat(ax, '%.6f'); end
        window = ancestor(ax, 'figure');
        if ~isempty(window) && mean(window.Color) < 0.5, apply_app_theme(ax, 'ダーク'); end
    end
end
