function plot_category_flows(ax, layout, column_names, level_names, color_names)
% category_flow_layout の配置で、Parallel Sets / Sankey Diagram を描く。
%   column_names 列（縦軸）の名前、level_names 列ごとの水準名（string の cell）
%   color_names  帯の色の凡例に使う名前（Parallel Sets は最初の列の水準名）。空なら凡例を出さない（Sankey）
NODE_WIDTH = 0.06; CURVE_POINTS = 40; RIBBON_ALPHA = 0.45; LABEL_LIMIT = 24;
cla(ax); hold(ax, 'on');
colors = lines(max(1, max(layout.Ribbons.Color)));
blend = (1 - cos(linspace(0, pi, CURVE_POINTS))) / 2;
for index = 1:height(layout.Ribbons)
    ribbon = layout.Ribbons(index, :);
    x_left = ribbon.Column + NODE_WIDTH / 2; x_right = ribbon.Column + 1 - NODE_WIDTH / 2;
    x = x_left + (x_right - x_left) * linspace(0, 1, CURVE_POINTS);
    lower = ribbon.LeftBottom + (ribbon.RightBottom - ribbon.LeftBottom) * blend;
    upper = ribbon.LeftTop + (ribbon.RightTop - ribbon.LeftTop) * blend;
    patch(ax, [x, fliplr(x)], [lower, fliplr(upper)], colors(ribbon.Color, :), 'EdgeColor', 'none', ...
        'FaceAlpha', RIBBON_ALPHA, 'HitTest', 'off');
end
columns = numel(column_names);
for index = 1:height(layout.Nodes)
    node = layout.Nodes(index, :);
    if node.Count == 0, continue; end
    x = node.Column + NODE_WIDTH / 2 * [-1, 1, 1, -1];
    patch(ax, x, [node.Bottom, node.Bottom, node.Top, node.Top], [0.25, 0.30, 0.38], 'EdgeColor', 'none');
    name = char(level_names{node.Column}(node.Level));
    if numel(name) > LABEL_LIMIT, name = [name(1:LABEL_LIMIT) '…']; end
    alignment = 'left'; offset = NODE_WIDTH;
    if node.Column == columns, alignment = 'right'; offset = -NODE_WIDTH; end
    text(ax, node.Column + offset, (node.Bottom + node.Top) / 2, sprintf('%s（%d）', name, node.Count), ...
        'HorizontalAlignment', alignment, 'VerticalAlignment', 'middle', 'Interpreter', 'none', 'FontSize', 9, 'Clipping', 'on');
end
% 凡例は色ごとに見えない線を1本ずつ置いて作る。
used = unique(layout.Ribbons.Color)'; handles = gobjects(0);
if isempty(color_names), used = []; end
for color = used
    handles(end + 1) = plot(ax, NaN, NaN, 's', 'MarkerFaceColor', colors(color, :), 'MarkerEdgeColor', 'none', ...
        'MarkerSize', 10, 'DisplayName', char(color_names(color))); %#ok<AGROW>
end
if ~isempty(handles), legend(ax, handles, 'Location', 'eastoutside', 'Interpreter', 'none'); end
ax.XLim = [1 - 0.5, columns + 0.5]; ax.YLim = [-0.02, 1.02];
ax.XTick = 1:columns; ax.XTickLabel = column_names; ax.TickLabelInterpreter = 'none';
ax.YTick = []; ax.YColor = 'none'; box(ax, 'off'); hold(ax, 'off');
end
