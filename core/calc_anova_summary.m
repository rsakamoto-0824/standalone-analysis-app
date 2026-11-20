function result = calc_anova_summary(response, factors, factor_names)
% 分散分析（主効果のみ）。response は数値、factors は要因ごとのグループ名（string の列ベクトル）の cell。
% 要因が1つなら一元配置、2つ以上なら主効果の多元配置（交互作用は含めない）。
% 空欄（NaN・"(欠損)"）を含む行は除く。
%   result.Table   要因ごとの平方和・自由度・平均平方・F値・p値・寄与率（η²＝要因の平方和／全体の平方和）
%   result.Groups  要因の水準ごとの件数・平均・標準偏差
MAX_LEVELS = 50;
response = double(response(:)); valid = isfinite(response);
for index = 1:numel(factors), valid = valid & factors{index}(:) ~= "(欠損)"; end
if sum(valid) < 3, error('anova:rows', '分散分析には、空欄のない行が3行以上必要です。'); end
groups = cellfun(@(factor) cellstr(factor(valid)), factors, 'UniformOutput', false);
for index = 1:numel(groups)
    levels = numel(unique(groups{index}));
    if levels < 2, error('anova:levels', '要因「%s」の水準が1つだけです。2つ以上の水準がある列を選んでください。', factor_names{index}); end
    if levels > MAX_LEVELS, error('anova:levels', '要因「%s」の水準が%d個あります。%d個以下の列を選んでください（数値の列は区間に分けてから使います）。', factor_names{index}, levels, MAX_LEVELS); end
end
[~, raw] = anovan(response(valid), groups, 'varnames', cellstr(string(factor_names)), 'display', 'off', 'model', 'linear');
header = raw(1, :); body = raw(2:end, :);
column = @(name) find(strcmp(header, name), 1);
total_row = strcmp(body(:, 1), 'Total'); total_ss = body{total_row, column('Sum Sq.')};
sources = string(body(:, 1)); sources(sources == "Error") = "誤差"; sources(sources == "Total") = "全体";
numberOf = @(name) cellfun(@(value) toDouble(value), body(:, column(name)));
ss = numberOf('Sum Sq.'); df = numberOf('d.f.'); ms = numberOf('Mean Sq.'); f = numberOf('F'); p = numberOf('Prob>F');
share = ss / total_ss; share(sources == "全体") = 1;
result.Table = table(sources, ss, df, ms, f, p, share, 'VariableNames', {'要因', '平方和', '自由度', '平均平方', 'F値', 'p値', '寄与率'});
group_table = table();
for index = 1:numel(groups)
    [levels, ~, member] = unique(groups{index});
    values = response(valid);
    counts = accumarray(member, 1); means = accumarray(member, values, [], @mean); deviations = accumarray(member, values, [], @std);
    group_table = [group_table; table(repmat(string(factor_names{index}), numel(levels), 1), string(levels), counts, means, deviations, ...
        'VariableNames', {'要因', '水準', '件数', '平均', '標準偏差'})]; %#ok<AGROW>
end
result.Groups = group_table; result.Rows = sum(valid);
end

function value = toDouble(value)
if isempty(value) || ~isnumeric(value), value = NaN; else, value = double(value); end
end
