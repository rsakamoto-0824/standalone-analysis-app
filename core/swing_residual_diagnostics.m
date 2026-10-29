function report = swing_residual_diagnostics(actual, fitted, alpha)
% 近似後の残差を記述する。検定p値は独立標本を仮定した参考値として扱う。
MIN_TABULATED_P = 0.001; MAX_TABULATED_P = 0.5;
if nargin < 3, alpha = 0.05; end
validateattributes(actual, {'numeric'}, {'vector', 'real', 'finite'});
validateattributes(fitted, {'numeric'}, {'vector', 'real', 'finite'});
validateattributes(alpha, {'numeric'}, {'scalar', 'real', 'finite', '>=', MIN_TABULATED_P, '<=', MAX_TABULATED_P});
[actual, fitted] = metric_inputs(actual, fitted, 4, mfilename);
residual = actual - fitted;
if any(~isfinite(residual)), error('swing_residual_diagnostics:scale', '残差の桁が大きすぎます。'); end
report = struct('Count', numel(residual), 'Residual', residual, 'Mean', mean(residual), ...
    'Std', std(residual), 'Alpha', alpha, 'Tested', false, 'Reject', NaN, 'PValue', NaN, ...
    'PRelation', "", 'PText', "p値なし", 'Statistic', NaN, 'CriticalValue', NaN, ...
    'Skewness', NaN, 'Kurtosis', NaN, 'ExcessKurtosis', NaN, ...
    'Standardized', NaN(size(residual)), 'TheoreticalQuantiles', [], 'ObservedQuantiles', []);
% 周期探索の停止精度に近い残差を、測定誤差の分布として検定しない。
RELATIVE_RESOLUTION = 1e-7;
report.ResidualTolerance = max(RELATIVE_RESOLUTION * std(actual), 100 * eps(max(abs([actual; fitted]))));
report.Caveat = "近似後の残差は独立とは限らず、検定は参考診断です。棄却されなくても正規分布の証明ではありません。";
if ~isfinite(report.Std) || ~isfinite(report.ResidualTolerance)
    error('swing_residual_diagnostics:scale', '残差のばらつきを計算できません。入力の桁を確認してください。');
elseif report.Std <= report.ResidualTolerance
    report.Decision = "判定対象外：残差のばらつきが数値判定しきい値以下";
else
    report.Standardized = (residual - report.Mean) / report.Std;
    report.Skewness = skewness(report.Standardized, 0);
    report.Kurtosis = kurtosis(report.Standardized, 0);
    report.ExcessKurtosis = report.Kurtosis - 3;
    [report.Reject, report.PValue, report.Statistic, report.CriticalValue] = normalityTest(report.Standardized, alpha);
    report.Tested = true;
    % 表の境界値を正確なp値として表示しない。等号を含む保守的な表示にする。
    if report.PValue <= MIN_TABULATED_P
        report.PRelation = "<=";
    elseif report.PValue >= MAX_TABULATED_P
        report.PRelation = ">=";
    else
        report.PRelation = "=";
    end
    report.PText = sprintf('p %s %.6g', report.PRelation, report.PValue);
    if report.Reject, report.Decision = "正規性を棄却（参考）";
    else, report.Decision = "正規性を棄却できず（参考）"; end
    probabilities = ((1:report.Count)' - 0.5) / report.Count;
    report.TheoreticalQuantiles = norminv(probabilities);
    report.ObservedQuantiles = sort(report.Standardized);
end
report.Summary = sprintf('Lilliefors / α=%.3g / n=%d / %s / %s\n歪度 %.5g（正規0） / 尖度 %.5g（正規3） / 超過尖度 %.5g（正規0）\n%s', ...
    alpha, report.Count, report.PText, report.Decision, report.Skewness, report.Kurtosis, report.ExcessKurtosis, report.Caveat);
items = ["Test"; "Count"; "Alpha"; "RejectNormality"; "PValueBound"; "LillieforsStatistic"; "CriticalValue"; ...
    "ResidualMean"; "ResidualSampleStd"; "Skewness"; "Kurtosis"; "ExcessKurtosis"; "ResidualTolerance"; "Decision"; "Caveat"];
values = [NaN; report.Count; alpha; double(report.Reject); report.PValue; report.Statistic; report.CriticalValue; ...
    report.Mean; report.Std; report.Skewness; report.Kurtosis; report.ExcessKurtosis; report.ResidualTolerance; NaN; NaN];
details = ["Lilliefors（平均・標準偏差を標本から推定）"; "選択範囲の全観測行"; "有意水準"; "1=棄却 / 0=棄却できず / NaN=対象外"; ...
    report.PText; "最大CDF差"; "有意水準αでの臨界値"; "SHAP値−近似値"; "n−1で割る標準偏差"; ...
    "偏り補正あり / 正規分布0"; "偏り補正あり / 正規分布3"; "尖度−3 / 正規分布0"; ...
    "max(1e−7×SHAP標準偏差, 100×eps(最大絶対値))"; report.Decision; report.Caveat];
report.Table = table(items, values, details, 'VariableNames', {'Metric', 'Value', 'Details'});
end

function [reject, p_value, statistic, critical] = normalityTest(standardized, alpha)
% 既知の表外p値の警告だけを抑え、呼出元の警告設定を確実に戻す。
high_id = 'stats:lillietest:OutOfRangePHigh'; low_id = 'stats:lillietest:OutOfRangePLow';
high_state = warning('query', high_id); low_state = warning('query', low_id);
cleanup = onCleanup(@() restoreWarnings(high_state, low_state));
warning('off', high_id); warning('off', low_id);
[reject, p_value, statistic, critical] = lillietest(standardized, 'Alpha', alpha);
end

function restoreWarnings(high_state, low_state)
warning(high_state); warning(low_state);
end
