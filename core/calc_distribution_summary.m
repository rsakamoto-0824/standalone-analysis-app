function summary = calc_distribution_summary(values, sigma_multiple)
% 値の分布の要約：平均・標準偏差・中央値・最頻値・95%区間と、平均 ± kσ（k = 1〜sigma_multiple）の範囲に入る割合。
% 最頻値は、カーネル密度推定（ksdensity）の山の頂点の値（連続な値ではヒストグラムの区切り方に左右されないため）。
if nargin < 2, sigma_multiple = 3; end
values = double(values(:)); values = values(isfinite(values));
if numel(values) < 2, error('distribution:rows', '分布の要約には2件以上の値が必要です。'); end
average = mean(values); deviation = std(values);
if deviation > 0
    [density, points] = ksdensity(values, 'NumPoints', 512); [~, peak] = max(density); mode_value = points(peak);
else
    mode_value = average;
end
interval = prctile(values, [2.5, 97.5]);
k = (1:sigma_multiple)'; lower = average - k * deviation; upper = average + k * deviation;
coverage = arrayfun(@(index) 100 * mean(values >= lower(index) & values <= upper(index)), 1:numel(k))';
% 正規分布なら入る割合（比べる目安）。
normal = 100 * (normcdf(k) - normcdf(-k));
summary.Average = average; summary.Deviation = deviation; summary.Median = median(values); summary.Mode = mode_value;
summary.Interval = interval; summary.SigmaMultiple = sigma_multiple; summary.SigmaLower = lower; summary.SigmaUpper = upper;
names = ["平均"; "標準偏差 σ"; "中央値"; "最頻値（密度の山の頂点）"; "95%区間の下限（2.5%点）"; "95%区間の上限（97.5%点）"];
numbers = [average; deviation; summary.Median; mode_value; interval(:)];
summary.Table = [table(names, numbers, NaN(numel(names), 1), NaN(numel(names), 1), 'VariableNames', {'項目', '値', '入る割合_percent', '正規分布なら_percent'}); ...
    table("平均 ± " + string(k) + "σ", lower, coverage, normal, 'VariableNames', {'項目', '値', '入る割合_percent', '正規分布なら_percent'})];
summary.Table.("上限") = [NaN(numel(names), 1); upper];
summary.Table = movevars(summary.Table, "上限", 'After', "値");
summary.Table.Properties.VariableNames{2} = '値（範囲は下限）';
end
