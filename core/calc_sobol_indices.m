function result = calc_sobol_indices(predictor, lower, upper, names, options)
% Sobol 感度解析（Pro 版）。各説明変数を範囲 [lower, upper] の一様分布で互いに独立に動かしたとき、
% 予測値のばらつき（分散）のうち、その変数で説明できる割合を求める。
%   1次の指数 S1：その変数だけで説明できる割合（Saltelli 2010 の推定式）
%   全効果の指数 ST：ほかの変数との組み合わせ（交互作用）も含めた割合（Jansen の推定式）
% 標本は準乱数（スクランブルした Sobol 列）で作り、信頼区間はブートストラップ（行の復元抽出）の 2.5〜97.5% 点。
% options：SampleSize（基本の標本数 N、予測の回数は N×(説明変数の数+2)）、Bootstrap（回数）、Seed、
%          Categorical（質的変数の列。論理ベクトル）と LevelCounts（各列の水準数。質的変数は 1〜水準数 の整数から一様に選ぶ）、
%          Marginals（省略可。列ごとのデータの値の cell。空でない列は一様分布の代わりにデータの分布〈経験分布の分位点〉から取る）。
count = numel(lower);
defaults = struct('SampleSize', 1024, 'Bootstrap', 200, 'Seed', 0, 'Categorical', false(1, count), 'LevelCounts', zeros(1, count), ...
    'Marginals', {cell(1, count)});
names_given = fieldnames(options);
for index = 1:numel(names_given), defaults.(names_given{index}) = options.(names_given{index}); end
options = defaults; lower = double(lower(:)'); upper = double(upper(:)');
if count < 1 || numel(upper) ~= count || numel(names) ~= count, error('sobol:shape', '説明変数・下限・上限の数を一致させてください。'); end
if any(~isfinite([lower, upper])) || any(upper < lower), error('sobol:range', '各説明変数の上限は下限以上の数値にしてください。'); end
if all(upper == lower), error('sobol:range', 'すべての説明変数の範囲が1点です。少なくとも1つは幅のある範囲にしてください。'); end
validateattributes(options.SampleSize, {'numeric'}, {'scalar', 'integer', '>=', 16});
N = options.SampleSize; categorical = logical(options.Categorical(:)');
% 準乱数は乱数の初期値に依存するため、この計算の間だけ乱数を固定し、終わったら元に戻す。
previous = rng; restore = onCleanup(@() rng(previous)); rng(options.Seed, 'twister');
points = scramble(sobolset(2 * count, 'Skip', 1), 'MatousekAffineOwen');
unit = net(points, N);
A = scaleSample(unit(:, 1:count), lower, upper, categorical, options.LevelCounts, options.Marginals);
B = scaleSample(unit(:, count + 1:end), lower, upper, categorical, options.LevelCounts, options.Marginals);
fA = evaluate(A); fB = evaluate(B); fAB = zeros(N, count);
for column = 1:count
    AB = A; AB(:, column) = B(:, column); fAB(:, column) = evaluate(AB);
end
total_variance = var([fA; fB]);
if total_variance <= eps(max(abs([fA; fB]))) * 10
    error('sobol:constant', '範囲の中で予測値がほとんど変わらないため、感度を計算できません。範囲を確認してください。');
end
[first, total] = indices(1:N);
stream = RandStream('twister', 'Seed', options.Seed + 1);
boot_first = zeros(options.Bootstrap, count); boot_total = boot_first;
for repeat = 1:options.Bootstrap
    [boot_first(repeat, :), boot_total(repeat, :)] = indices(randi(stream, N, N, 1));
end
first_ci = prctile(boot_first, [2.5, 97.5], 1); total_ci = prctile(boot_total, [2.5, 97.5], 1);
result.Table = table(string(names(:)), first(:), first_ci(1, :)', first_ci(2, :)', total(:), total_ci(1, :)', total_ci(2, :)', total(:) - first(:), ...
    'VariableNames', {'説明変数', 'S1', 'S1_下限', 'S1_上限', 'ST', 'ST_下限', 'ST_上限', 'ST_minus_S1'});
result.Predictions = fA; result.Evaluations = N * (count + 2); result.Variance = total_variance; result.SampleSize = N;
clear restore;

    function values = evaluate(inputs)
        values = predictor(inputs); values = double(values(:));
        if numel(values) ~= size(inputs, 1) || any(~isfinite(values)), error('sobol:prediction', 'モデルの予測値に数値でない値が含まれます。範囲を確認してください。'); end
    end
    function [s1, st] = indices(rows)
        % 予測値の平均を引いてから計算する（平均が大きいと S1 の推定がばらつくため）。
        centre = mean([fA(rows); fB(rows)]); a = fA(rows) - centre; b = fB(rows) - centre; ab = fAB(rows, :) - centre;
        variance = var([a; b]);
        s1 = mean(b .* (ab - a), 1) / variance;
        st = 0.5 * mean((a - ab).^2, 1) / variance;
    end
end

function sample = scaleSample(unit, lower, upper, categorical, level_counts, marginals)
sample = lower + unit .* (upper - lower);
for column = find(~cellfun(@isempty, marginals))
    % データの分布：その列の値の分位点を使う（範囲は [下限, 上限] に収める）。
    values = sort(marginals{column}(isfinite(marginals{column}))); values = values(:);
    sample(:, column) = min(max(interp1(linspace(0, 1, numel(values))', values, unit(:, column)), lower(column)), upper(column));
end
for column = find(categorical)
    % 質的変数は水準の番号（1〜水準数）から一様に選ぶ。
    sample(:, column) = min(level_counts(column), floor(unit(:, column) * level_counts(column)) + 1);
end
end
