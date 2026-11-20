function result = boosting_bins(action, x, option)
% ブースティング系の回帰で使う、説明変数の区間分け（ヒストグラム）。
%   edges = boosting_bins('edges', x, max_bins)   列ごとの区切り値（分位点）を求める
%   bins  = boosting_bins('index', x, edges)      区切り値で各値の区間番号（1始まり）を求める
% 学習と予測で同じ区切り値を使うため、予測時も 'index' に学習時の edges を渡す。
switch action
    case 'edges'
        max_bins = option; result = cell(1, size(x, 2));
        for column = 1:size(x, 2)
            values = x(:, column); values = values(isfinite(values));
            levels = unique(values);
            if numel(levels) <= max_bins
                % 値の種類が少ない列は、隣り合う値の中点で区切る（すべての値を別の区間にする）。
                edges = (levels(1:end - 1) + levels(2:end)) / 2;
            else
                edges = unique(quantile(values, (1:max_bins - 1) / max_bins));
            end
            result{column} = edges(:)';
        end
    case 'index'
        edges = option; result = zeros(size(x));
        for column = 1:size(x, 2)
            % 区切り値より大きい数を数える（区切り値と等しい値は左の区間に入る）。
            result(:, column) = 1 + sum(x(:, column) > edges{column}, 2);
        end
    otherwise
        error('boosting_bins:action', 'edges または index を指定してください。');
end
end
