function plot_category_flows(ax, layout, column_names, level_names, color_names, color_label)
% category_flow_layout の配置で、Parallel Sets / Sankey Diagram / Alluvial Diagram を描く。
% Alluvial Diagram（layout.Style が 'alluvial'）は、層（水準）を幅の広い箱にして、水準名と件数を箱の中に書く。
%   column_names 列（縦軸）の名前、level_names 列ごとの水準名（string の cell）
%   color_names  帯の色の凡例に使う名前（色の番号の順）。空なら凡例を出さない
%   color_label  数値の列で色を付けたとき（layout.Ribbons.Value がある）の色の目盛りの名前
% 帯の Value が数値なら、その値を連続した色（parula）で表し、色の目盛り（colorbar）を出す。
if nargin < 6, color_label = ''; end
NODE_WIDTH = 0.06; CURVE_POINTS = 40; RIBBON_ALPHA = 0.45; LABEL_LIMIT = 24;
alluvial = isfield(layout, 'Style') && strcmp(layout.Style, 'alluvial');
% Alluvial の層の箱：幅、色、中に名前を書く最小の高さ（全体を1とする割合）。
% 名前と件数は2行に分けて箱の中に書く（1行だと箱の幅からはみ出しやすいため）。低い箱は箱の右に1行で書く。
ALLUVIAL_WIDTH = 0.34; STRATUM_COLOR = [0.93, 0.94, 0.96]; STRATUM_EDGE = [0.25, 0.30, 0.38]; INSIDE_LABEL_HEIGHT = 0.09;
if alluvial, NODE_WIDTH = ALLUVIAL_WIDTH; end
cla(ax); hold(ax, 'on');
numeric = any(isfinite(layout.Ribbons.Value));
colors = lines(max(1, max([layout.Ribbons.Color; 1], [], 'omitnan')));
if numeric
    % 数値の列：帯ごとの平均を、値の範囲で 0〜1 にそろえて色の並びから選ぶ。
    palette = parula(256); range = [min(layout.Ribbons.Value), max(layout.Ribbons.Value)];
    if diff(range) == 0, range = range + [-0.5, 0.5]; end
end
blend = (1 - cos(linspace(0, pi, CURVE_POINTS))) / 2;
for index = 1:height(layout.Ribbons)
    ribbon = layout.Ribbons(index, :);
    x_left = ribbon.Column + NODE_WIDTH / 2; x_right = ribbon.Column + 1 - NODE_WIDTH / 2;
    x = x_left + (x_right - x_left) * linspace(0, 1, CURVE_POINTS);
    lower = ribbon.LeftBottom + (ribbon.RightBottom - ribbon.LeftBottom) * blend;
    upper = ribbon.LeftTop + (ribbon.RightTop - ribbon.LeftTop) * blend;
    if numeric
        if isfinite(ribbon.Value)
            face = palette(1 + round(255 * (ribbon.Value - range(1)) / diff(range)), :);
        else
            face = [0.7, 0.7, 0.7];
        end
    else
        face = colors(ribbon.Color, :);
    end
    patch(ax, [x, fliplr(x)], [lower, fliplr(upper)], face, 'EdgeColor', 'none', ...
        'FaceAlpha', RIBBON_ALPHA, 'HitTest', 'off');
end
columns = numel(column_names);
for index = 1:height(layout.Nodes)
    node = layout.Nodes(index, :);
    if node.Count == 0, continue; end
    x = node.Column + NODE_WIDTH / 2 * [-1, 1, 1, -1];
    name = char(level_names{node.Column}(node.Level));
    if numel(name) > LABEL_LIMIT, name = [name(1:LABEL_LIMIT) '…']; end
    if alluvial
        patch(ax, x, [node.Bottom, node.Bottom, node.Top, node.Top], STRATUM_COLOR, 'EdgeColor', STRATUM_EDGE, 'LineWidth', 0.8);
        % 低い箱は名前が入らないため、箱の右に書く。
        if node.Top - node.Bottom >= INSIDE_LABEL_HEIGHT
            text(ax, node.Column, (node.Bottom + node.Top) / 2, {name, sprintf('（%d）', node.Count)}, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'Interpreter', 'none', 'FontSize', 9, 'Clipping', 'on');
        else
            text(ax, node.Column + NODE_WIDTH / 2 + 0.01, (node.Bottom + node.Top) / 2, sprintf('%s（%d）', name, node.Count), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Interpreter', 'none', 'FontSize', 8, 'Clipping', 'on');
        end
        continue;
    end
    patch(ax, x, [node.Bottom, node.Bottom, node.Top, node.Top], [0.25, 0.30, 0.38], 'EdgeColor', 'none');
    alignment = 'left'; offset = NODE_WIDTH;
    if node.Column == columns, alignment = 'right'; offset = -NODE_WIDTH; end
    text(ax, node.Column + offset, (node.Bottom + node.Top) / 2, sprintf('%s（%d）', name, node.Count), ...
        'HorizontalAlignment', alignment, 'VerticalAlignment', 'middle', 'Interpreter', 'none', 'FontSize', 9, 'Clipping', 'on');
end
% 凡例は色ごとに見えない線を1本ずつ置いて作る。
used = unique(layout.Ribbons.Color)'; handles = gobjects(0);
if isempty(color_names) || numeric, used = []; end
if numeric
    colormap(ax, palette); clim(ax, range); scale = colorbar(ax);
    scale.Label.String = sprintf('%s（帯ごとの平均）', color_label); scale.Label.Interpreter = 'none';
end
for color = used
    handles(end + 1) = plot(ax, NaN, NaN, 's', 'MarkerFaceColor', colors(color, :), 'MarkerEdgeColor', 'none', ...
        'MarkerSize', 10, 'DisplayName', char(color_names(color))); %#ok<AGROW>
end
if ~isempty(handles), legend(ax, handles, 'Location', 'eastoutside', 'Interpreter', 'none'); end
ax.XLim = [1 - 0.5, columns + 0.5]; ax.YLim = [-0.02, 1.02];
ax.XTick = 1:columns; ax.XTickLabel = column_names; ax.TickLabelInterpreter = 'none';
ax.YTick = []; ax.YColor = 'none'; box(ax, 'off'); hold(ax, 'off');
end
