function result = calc_permutation_importance(predictor, inputs, actual, names, repeats, seed)
% Permutation Importance：1つの説明変数の値だけを行の間で並べ替えたとき、予測の RMSE がどれだけ悪くなるか。
% 並べ替えは repeats 回繰り返して平均と標準偏差を出す。乱数はこの計算専用（seed）で、他の処理の乱数を変えない。
%   predictor : @(x) 予測値を返す関数
% 戻り値 result.Table：説明変数・RMSEの増加（平均・標準偏差）・増加の割合（%）、result.BaseRMSE：並べ替え前の RMSE。
% 相関の強い説明変数どうしでは、片方を並べ替えてももう片方が補うため、重要度が小さく出ることがある。
if nargin < 5 || isempty(repeats), repeats = 5; end
if nargin < 6 || isempty(seed), seed = 0; end
validate_numeric_data(inputs, '説明変数', mfilename); validate_numeric_data(actual, '目的変数', mfilename);
actual = double(actual(:)); rows = size(inputs, 1);
if rows ~= numel(actual) || numel(names) ~= size(inputs, 2), error('importance:shape', '説明変数・目的変数・列名の数が一致しません。'); end
if rows < 3, error('importance:rows', 'Permutation Importance には3行以上が必要です。'); end
stream = RandStream('twister', 'Seed', seed);
base = sqrt(mean((actual - predictor(inputs)).^2));
increase = zeros(repeats, size(inputs, 2));
for column = 1:size(inputs, 2)
    for repeat = 1:repeats
        shuffled = inputs; shuffled(:, column) = inputs(randperm(stream, rows), column);
        increase(repeat, column) = sqrt(mean((actual - predictor(shuffled)).^2)) - base;
    end
end
mean_increase = mean(increase, 1)'; spread = std(increase, 0, 1)';
share = 100 * mean_increase / max(base, eps);
result.Table = table(string(names(:)), mean_increase, spread, share, ...
    'VariableNames', {'説明変数', 'RMSEの増加', 'RMSEの増加の標準偏差', '増加の割合_percent'});
result.BaseRMSE = base; result.Repeats = repeats;
end
