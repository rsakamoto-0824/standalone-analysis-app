function layout = category_flow_layout(groups, level_counts, style)
% Parallel Sets と Sankey Diagram の配置（描画は app/plot_category_flows.m）。
%   groups       行 × 列のグループ番号（1〜水準数）。列が縦軸の並び（左から右）
%   level_counts 列ごとの水準数
%   style        'sets'   ：Parallel Sets。行の組み合わせ（経路）ごとに帯を通し、色は最初の列の水準
%                'sankey' ：Sankey Diagram。隣り合う2列の水準の組ごとに流れをまとめ、色は流れの元の水準（ノードの通し番号）
% 縦方向は全体を1とする割合で表し、水準（ノード）の間には少し隙間を空ける。
%   layout.Nodes  表：Column, Level, Count, Bottom, Top
%   layout.Ribbons 表：Column（左の列）, FromLevel, ToLevel, Count, Color, LeftBottom, LeftTop, RightBottom, RightTop
GAP = 0.02;
[rows, columns] = size(groups);
if columns < 2, error('flow:columns', '2列以上を選んでください。'); end
if rows < 1, error('flow:rows', '行がありません。'); end
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
if strcmp(style, 'sets')
    layout.Ribbons = setsRibbons(groups, layout.Nodes, unit);
elseif strcmp(style, 'sankey')
    layout.Ribbons = sankeyRibbons(groups, level_counts, layout.Nodes, unit);
else
    error('flow:style', 'sets または sankey を指定してください。');
end
end

function ribbons = setsRibbons(groups, nodes, unit)
% 行の組み合わせ（経路）ごとに、各ノードの中で経路の場所を決める。
% 各列では「その列の水準 → 最初の列の水準 → 残りの列」の順に並べ、同じ色の帯がまとまるようにする。
[paths, ~, member] = unique(groups, 'rows'); counts = accumarray(member, 1);
columns = size(groups, 2); slot_bottom = zeros(size(paths, 1), columns);
for column = 1:columns
    order_keys = [paths(:, column), paths(:, 1), paths(:, [2:column - 1, column + 1:end])];
    [~, order] = sortrows(order_keys);
    for level = unique(paths(:, column))'
        in_level = order(paths(order, column) == level);
        base = nodes.Bottom(nodes.Column == column & nodes.Level == level);
        slot_bottom(in_level, column) = base + [0; cumsum(counts(in_level(1:end - 1)))] * unit;
    end
end
count = size(paths, 1) * (columns - 1); data = zeros(count, 9); row = 0;
for column = 1:columns - 1
    for path = 1:size(paths, 1)
        row = row + 1; height = counts(path) * unit;
        data(row, :) = [column, paths(path, column), paths(path, column + 1), counts(path), paths(path, 1), ...
            slot_bottom(path, column), slot_bottom(path, column) + height, slot_bottom(path, column + 1), slot_bottom(path, column + 1) + height];
    end
end
ribbons = ribbonTable(data);
end

function ribbons = sankeyRibbons(groups, level_counts, nodes, unit)
% 隣り合う2列の水準の組ごとに流れをまとめる。元のノードでは行き先の順、行き先のノードでは元の順に積む。
data = zeros(0, 9);
for column = 1:size(groups, 2) - 1
    pairs = accumarray(groups(:, column:column + 1), 1, [level_counts(column), level_counts(column + 1)]);
    [from, to] = find(pairs > 0); flows = pairs(sub2ind(size(pairs), from, to));
    left = zeros(numel(flows), 1); right = left;
    [~, order] = sortrows([from, to]);
    for level = unique(from)'
        members = order(from(order) == level); base = nodes.Bottom(nodes.Column == column & nodes.Level == level);
        left(members) = base + [0; cumsum(flows(members(1:end - 1)))] * unit;
    end
    [~, order] = sortrows([to, from]);
    for level = unique(to)'
        members = order(to(order) == level); base = nodes.Bottom(nodes.Column == column + 1 & nodes.Level == level);
        right(members) = base + [0; cumsum(flows(members(1:end - 1)))] * unit;
    end
    heights = flows * unit; offset = sum(level_counts(1:column - 1));
    data = [data; repmat(column, numel(flows), 1), from, to, flows, offset + from, left, left + heights, right, right + heights]; %#ok<AGROW>
end
ribbons = ribbonTable(data);
end

function ribbons = ribbonTable(data)
ribbons = array2table(data, 'VariableNames', {'Column', 'FromLevel', 'ToLevel', 'Count', 'Color', ...
    'LeftBottom', 'LeftTop', 'RightBottom', 'RightTop'});
end
