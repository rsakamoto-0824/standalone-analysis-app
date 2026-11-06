function points = color_scatter(ax, x, y, source, column)
if strcmp(column, '(単色)')
    points = scatter(ax, x, y, 20, 'filled'); return;
end
position = find(strcmp(source.Headers, column), 1);
if isempty(position) || size(source.Cells, 1) ~= numel(x)
    error('color_scatter:rows', '色の列と散布図の行が一致しません。');
end
cells = source.Cells(:, position); numbers = NaN(numel(cells), 1); labels = strings(numel(cells), 1);
numeric = true;
for index = 1:numel(cells)
    value = cells{index};
    if isempty(value) || (isscalar(value) && ismissing(value))
        labels(index) = '(欠損)'; continue;
    end
    labels(index) = string(value);
    if isnumeric(value) || islogical(value), numbers(index) = double(value);
    else, numbers(index) = str2double(labels(index)); end
    if ~isscalar(numbers(index)) || ~isreal(numbers(index)) || ~isfinite(numbers(index)), numeric = false; end
end
palette = parula(256); colormap(ax, palette);
if numeric && any(isfinite(numbers))
    finite = numbers(isfinite(numbers)); limits = [min(finite), max(finite)];
    if limits(1) == limits(2), limits = limits + [-0.5, 0.5]; end
    fractions = (numbers - limits(1)) / diff(limits);
    colors = repmat([0.65, 0.65, 0.65], numel(x), 1); valid = isfinite(numbers);
    indices = 1 + round(255 * max(0, min(1, fractions(valid)))); colors(valid, :) = palette(indices, :);
    points = scatter(ax, x, y, 20, colors, 'filled'); clim(ax, limits);
    scale = colorbar(ax);
else
    [categories, ~, groups] = unique(labels, 'stable');
    count = numel(categories); colors = lines(max(1, count)); colormap(ax, colors);
    points = scatter(ax, x, y, 20, groups, 'filled'); clim(ax, [0.5, count + 0.5]);
    scale = colorbar(ax); ticks = unique(round(linspace(1, count, min(12, count))));
    scale.Ticks = ticks; scale.TickLabels = categories(ticks);
end
points.DataTipTemplate.DataTipRows(end+1) = dataTipTextRow(column, labels);
scale.Color = ax.XColor; scale.Label.String = column; scale.Label.Interpreter = 'none'; scale.TickLabelInterpreter = 'none';
end
