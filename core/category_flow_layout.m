function layout = category_flow_layout(groups, level_counts, style, color)
% Parallel Sets と Sankey Diagram の配置（描画は app/plot_category_flows.m）。
%   groups       行 × 列のグループ番号（1〜水準数）。列が縦軸の並び（左から右）
%   level_counts 列ごとの水準数
%   style        'sets'   ：Parallel Sets。行の組み合わせ（経路）ごとに帯を通す
%                'sankey' ：Sankey Diagram。隣り合う2列の水準の組ごとに流れをまとめる
%   color（省略可）帯の色の決め方 struct('Mode', ..., 'Values', 行ごとの値)
%                'none'     ：Parallel Sets は最初の列の水準、Sankey は流れの元の水準（ノードの通し番号）で色を付ける
%                'category' ：任意の列のグループ番号（Values）で帯を分け、その番号で色を付ける
%                'numeric'  ：任意の数値の列（Values）の帯ごとの平均で、連続した色を付ける
% 縦方向は全体を1とする割合で表し、水準（ノード）の間には少し隙間を空ける。
%   layout.Nodes  表：Column, Level, Count, Bottom, Top
%   layout.Ribbons 表：Column（左の列）, FromLevel, ToLevel, Count, Color, Value, LeftBottom, LeftTop, RightBottom, RightTop
%                  Color は色の番号（'numeric' では NaN）、Value は帯の平均（'numeric' 以外は NaN）
GAP = 0.02;
if nargin < 4 || isempty(color), color = struct('Mode', 'none', 'Values', []); end
[rows, columns] = size(groups);
if columns < 2, error('flow:columns', '2列以上を選んでください。'); end
if rows < 1, error('flow:rows', '行がありません。'); end
if ~strcmp(color.Mode, 'none') && numel(color.Values) ~= rows, error('flow:color', '色の列の行数がデータと一致しません。'); end
% 水準（ノード）の位置。各列で、水準の件数に比例した高さを下から積む。
node_column = []; node_level = []; node_count = []; node_bottom = []; node_top = [];
usable = 1 - GAP * (max(level_counts) - 1);
for column = 1:columns
    counts = accumarray(groups(:, column), 1, [level_counts(column), 1]);
    gap = GAP; if level_counts(column) > 1, gap = (1 - usable) / (level_counts(column) - 1); end
    position = 0;
    for level = 1:level_counts(column)
        height = usable * counts(level) / rows;
        node_column(end + 1, 1) = column; node_level(end + 1, 1) = level; node_count(end + 1, 1) = counts(level); %#ok<AGROW>
        node_bottom(end + 1, 1) = position; node_top(end + 1, 1) = position + height; %#ok<AGROW>
        position = position + height + gap;
    end
end
layout.Nodes = table(node_column, node_level, node_count, node_bottom, node_top, ...
    'VariableNames', {'Column', 'Level', 'Count', 'Bottom', 'Top'});
unit = usable / rows;
% 帯を分けるための色の番号（'category' のときだけ使う）。
key = zeros(rows, 1); if strcmp(color.Mode, 'category'), key = double(color.Values(:)); end
if strcmp(style, 'sets')
    layout.Ribbons = setsRibbons(groups, layout.Nodes, unit, key, color);
elseif strcmp(style, 'sankey')
    layout.Ribbons = sankeyRibbons(groups, level_counts, layout.Nodes, unit, key, color);
else
    error('flow:style', 'sets または sankey を指定してください。');
end
end

function ribbons = setsRibbons(groups, nodes, unit, key, color)
% 行の組み合わせ（経路。色で分けるときは色の番号も含む）ごとに、各ノードの中で経路の場所を決める。
% 各列では「その列の水準 → 色 → 最初の列の水準 → 残りの列」の順に並べ、同じ色の帯がまとまるようにする。
[paths, ~, member] = unique([groups, key], 'rows'); counts = accumarray(member, 1);
columns = size(groups, 2); path_key = paths(:, end); paths = paths(:, 1:columns);
slot_bottom = zeros(size(paths, 1), columns);
for column = 1:columns
    order_keys = [paths(:, column), path_key, paths(:, 1), paths(:, [2:column - 1, column + 1:end])];
    [~, order] = sortrows(order_keys);
    for level = unique(paths(:, column))'
        in_level = order(paths(order, column) == level);
        base = nodes.Bottom(nodes.Column == column & nodes.Level == level);
        slot_bottom(in_level, column) = base + [0; cumsum(counts(in_level(1:end - 1)))] * unit;
    end
end
[colors, values] = ribbonColors(member, size(paths, 1), paths(:, 1), path_key, color);
data = zeros(0, 10);
for column = 1:columns - 1
    heights = counts * unit;
    data = [data; repmat(column, size(paths, 1), 1), paths(:, column), paths(:, column + 1), counts, colors, values, ...
        slot_bottom(:, column), slot_bottom(:, column) + heights, slot_bottom(:, column + 1), slot_bottom(:, column + 1) + heights]; %#ok<AGROW>
end
ribbons = ribbonTable(data);
end

function ribbons = sankeyRibbons(groups, level_counts, nodes, unit, key, color)
% 隣り合う2列の水準の組（色で分けるときは色の番号も）ごとに流れをまとめる。
% 元のノードでは「行き先 → 色」の順、行き先のノードでは「元 → 色」の順に積む。
data = zeros(0, 10);
for column = 1:size(groups, 2) - 1
    [pairs, ~, member] = unique([groups(:, column:column + 1), key], 'rows'); flows = accumarray(member, 1);
    from = pairs(:, 1); to = pairs(:, 2); pair_key = pairs(:, 3);
    left = zeros(numel(flows), 1); right = left;
    [~, order] = sortrows([from, to, pair_key]);
    for level = unique(from)'
        members = order(from(order) == level); base = nodes.Bottom(nodes.Column == column & nodes.Level == level);
        left(members) = base + [0; cumsum(flows(members(1:end - 1)))] * unit;
    end
    [~, order] = sortrows([to, from, pair_key]);
    for level = unique(to)'
        members = order(to(order) == level); base = nodes.Bottom(nodes.Column == column + 1 & nodes.Level == level);
        right(members) = base + [0; cumsum(flows(members(1:end - 1)))] * unit;
    end
    offset = sum(level_counts(1:column - 1));
    [colors, values] = ribbonColors(member, numel(flows), offset + from, pair_key, color);
    heights = flows * unit;
    data = [data; repmat(column, numel(flows), 1), from, to, flows, colors, values, left, left + heights, right, right + heights]; %#ok<AGROW>
end
ribbons = ribbonTable(data);
end

function [colors, values] = ribbonColors(member, count, default_color, key, color)
% 帯の色の番号と、数値の列で色を付けるときの帯ごとの平均。
values = NaN(count, 1);
switch color.Mode
    case 'category'
        colors = key;
    case 'numeric'
        colors = NaN(count, 1);
        numbers = double(color.Values(:)); finite = isfinite(numbers);
        sums = accumarray(member(finite), numbers(finite), [count, 1]); counts = accumarray(member(finite), 1, [count, 1]);
        values = sums ./ counts; values(counts == 0) = NaN;
    otherwise
        colors = default_color;
end
end

function ribbons = ribbonTable(data)
ribbons = array2table(data, 'VariableNames', {'Column', 'FromLevel', 'ToLevel', 'Count', 'Color', 'Value', ...
    'LeftBottom', 'LeftTop', 'RightBottom', 'RightTop'});
end
