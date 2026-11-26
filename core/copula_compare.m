function report = copula_compare(model, samples)
% 生成した乱数が、元のデータ（または指定した値）の関係と分布をどれだけ保っているかを表にする。
%   report.Dependence：列の組ごとの Kendall τ と Spearman ρ（元・指定と生成）
%   report.Summary   ：列ごとの平均・標準偏差・最小・最大（元と生成）
% Kendall τ の計算は行数の2乗に比例するため、生成した乱数・元のデータとも先頭 MAX_ROWS 行で計算する。
MAX_ROWS = 5000;
names = model.Names; count = numel(names); pairs = nchoosek(1:count, 2);
part = samples(1:min(end, MAX_ROWS), :);
generated_kendall = corr(part, 'type', 'Kendall'); generated_spearman = corr(part, 'type', 'Spearman');
first = strings(size(pairs, 1), 1); second = first; reference_kendall = NaN(size(pairs, 1), 1); reference_spearman = reference_kendall;
if strcmp(model.Source, 'data')
    original = model.Original(1:min(end, MAX_ROWS), :);
    original_kendall = corr(original, 'type', 'Kendall'); original_spearman = corr(original, 'type', 'Spearman');
end
for index = 1:size(pairs, 1)
    i = pairs(index, 1); j = pairs(index, 2); first(index) = names{i}; second(index) = names{j};
    if strcmp(model.Source, 'data')
        reference_kendall(index) = original_kendall(i, j); reference_spearman(index) = original_spearman(i, j);
    elseif strcmp(model.Measure, 'kendall')
        reference_kendall(index) = model.Target(i, j);
    else
        reference_spearman(index) = model.Target(i, j);
    end
end
label = '元のデータ'; if strcmp(model.Source, 'spec'), label = '指定'; end
report.Dependence = table(first, second, reference_kendall, generated_kendall(sub2ind([count, count], pairs(:, 1), pairs(:, 2))), ...
    reference_spearman, generated_spearman(sub2ind([count, count], pairs(:, 1), pairs(:, 2))), ...
    'VariableNames', {'列1', '列2', ['Kendall_tau_' label], 'Kendall_tau_生成', ['Spearman_rho_' label], 'Spearman_rho_生成'});
statistics = @(x) [mean(x, 1); std(x, 0, 1); min(x, [], 1); max(x, [], 1)];
generated = statistics(samples)';
summary = table(string(names(:)), generated(:, 1), generated(:, 2), generated(:, 3), generated(:, 4), ...
    'VariableNames', {'列', '平均_生成', '標準偏差_生成', '最小_生成', '最大_生成'});
if strcmp(model.Source, 'data')
    original = statistics(model.Original)';
    summary = [summary, table(original(:, 1), original(:, 2), original(:, 3), original(:, 4), ...
        'VariableNames', {'平均_元', '標準偏差_元', '最小_元', '最大_元'})];
end
report.Summary = summary;
end
