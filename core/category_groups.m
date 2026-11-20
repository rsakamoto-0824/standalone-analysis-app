function [groups, names] = category_groups(column, max_levels)
% 列を質的変数（グループ）として扱うためのグループ番号と名前。
% 文字の列や、数値でも種類が max_levels 以下の列は、値ごとに1グループにする。
% 種類の多い数値の列は、分位点で max_levels 個の区間に分ける（名前は「下限〜上限」）。
% 空欄は "(欠損)" のグループにする（最後に並べる）。
if nargin < 2, max_levels = 6; end
count = numel(column.Labels); groups = zeros(count, 1); present = ~column.Missing;
if column.IsNumeric
    values = column.Numbers(present); levels = unique(values);
    if numel(levels) <= max_levels
        [~, ~, index] = unique(values); names = string(arrayfun(@(value) sprintf('%.6g', value), levels, 'UniformOutput', false));
    else
        edges = unique(quantile(values, linspace(0, 1, max_levels + 1)));
        edges(1) = min(values); edges(end) = max(values);
        index = discretize(values, edges, 'IncludedEdge', 'right'); index(isnan(index)) = 1;
        names = strings(numel(edges) - 1, 1);
        for bin = 1:numel(names), names(bin) = sprintf('%.4g〜%.4g', edges(bin), edges(bin + 1)); end
        [used, ~, index] = unique(index); names = names(used);
    end
else
    [names, ~, index] = unique(column.Labels(present));
end
groups(present) = index; names = names(:);
if any(~present)
    names(end + 1) = "(欠損)"; groups(~present) = numel(names);
end
end
