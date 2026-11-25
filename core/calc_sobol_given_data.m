function first_order = calc_sobol_given_data(inputs, response)
% モデルを使わずに、データから直接 1次の Sobol 指数を推定する（区間分割の相関比）。
% 各説明変数を分位点で区間に分け、区間ごとの目的変数の平均のばらつき ÷ 目的変数全体のばらつき（η²）。
% 区間の数は √行数（5〜30）。行数が少ないと大きめに出るため、区間の数から見込まれる分（(区間数−1)/(行数−1)）を差し引く。
% 全効果の指数（ST）と交互作用は、この方法では求めない。説明変数どうしに相関があると、ほかの変数の効果も含んだ値になる。
MIN_BINS = 5; MAX_BINS = 30;
validate_numeric_data(inputs, '説明変数', mfilename); validate_numeric_data(response, '目的変数', mfilename);
response = double(response(:)); rows = numel(response);
if size(inputs, 1) ~= rows, error('sobol:shape', '説明変数と目的変数の行数を一致させてください。'); end
if rows < 2 * MIN_BINS, error('sobol:rows', 'データから直接の推定には %d 行以上が必要です。', 2 * MIN_BINS); end
total = sum((response - mean(response)).^2);
if total == 0, error('sobol:constant', '目的変数の値が一定です。'); end
bins = min(MAX_BINS, max(MIN_BINS, round(sqrt(rows))));
first_order = zeros(1, size(inputs, 2));
for column = 1:size(inputs, 2)
    x = inputs(:, column); levels = unique(x);
    if numel(levels) <= bins
        [~, ~, group] = unique(x);
    else
        edges = unique(quantile(x, linspace(0, 1, bins + 1))); edges(1) = -Inf; edges(end) = Inf;
        group = discretize(x, edges);
    end
    counts = accumarray(group, 1); means = accumarray(group, response) ./ counts; used = counts > 0;
    eta = sum(counts(used) .* (means(used) - mean(response)).^2) / total;
    first_order(column) = max(0, eta - (sum(used) - 1) / (rows - 1));
end
end
