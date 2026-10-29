function details = optimize_swing_period(log_likelihood, thickness, seed_period, progress)
% 固定周期ごとの周辺対数尤度を比較する。周期はGPRのthetaとは別に探索する。
if nargin < 3, seed_period = []; end
if nargin < 4, progress = []; end
validateattributes(thickness, {'numeric'}, {'vector', 'real', 'finite'});
if ~isa(log_likelihood, 'function_handle'), error('swing_period:objective', '尤度計算関数が必要です。'); end
distinct = unique(double(thickness(:)));
if numel(distinct) < 8, error('swing_period:distinct', '周期の推定には異なる膜厚が8点以上必要です。'); end
span = max(distinct) - min(distinct);
bounds = [max(4*median(diff(distinct)), span/20), span];
if ~all(isfinite(bounds)) || bounds(1) >= bounds(2)
    error('swing_period:bounds', '膜厚から周期の探索範囲を設定できません。');
end
GRID_COUNT = 9; LOCAL_SEARCHES = 3; LOCAL_EVALUATIONS = 12;
MAX_EVALUATIONS = GRID_COUNT + 3 + LOCAL_SEARCHES*LOCAL_EVALUATIONS;
frequency = linspace(span/bounds(2), span/bounds(1), GRID_COUNT);
if ~isempty(seed_period)
    validateattributes(seed_period, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    seeds = span ./ (seed_period * [0.5, 1, 2]);
    frequency = [frequency, seeds(seeds >= min(frequency) & seeds <= max(frequency))];
end
frequency = unique(frequency); scores = NaN(size(frequency));
tested_frequency = zeros(0, 1); tested_scores = zeros(0, 1); messages = strings(0, 1);
for index = 1:numel(frequency), scores(index) = evaluate(frequency(index)); end
[~, order] = sort(scores);
valid_order = order(isfinite(scores(order)));
if isempty(valid_order)
    error('swing_period:allFailed', 'すべての周期候補で学習に失敗しました。最初の理由: %s', messages(1));
end
refined = true;
for index = valid_order(1:min(LOCAL_SEARCHES, numel(valid_order)))
    lower = frequency(max(1, index - 1)); upper = frequency(min(numel(frequency), index + 1));
    if lower == upper, continue; end
    options = optimset('Display', 'off', 'TolX', 1e-4, 'MaxFunEvals', LOCAL_EVALUATIONS);
    [~, ~, flag] = fminbnd(@evaluate, lower, upper, options);
    refined = refined && flag > 0;
end
[negative_score, best] = min(tested_scores); period = span / tested_frequency(best);
trace = table((1:numel(tested_scores))', span ./ tested_frequency, -tested_scores, isfinite(tested_scores), messages, ...
    'VariableNames', {'Evaluation', 'Period', 'LogLikelihood', 'Succeeded', 'Message'});
details = struct('Period', period, 'LogLikelihood', -negative_score, 'SearchBounds', bounds, ...
    'Evaluations', height(trace), 'MaximumEvaluations', MAX_EVALUATIONS, 'Trace', trace, ...
    'RefinementConverged', refined, 'Warnings', strings(0, 1));
if ~refined, details.Warnings(end + 1) = "周期探索は評価回数の上限内で選んだ結果です。厳密な収束を保証しません。"; end
if any(abs(period - bounds) < 1e-3 * span)
    details.Warnings(end + 1) = "周期が自動探索範囲の端にあります。より広い膜厚データでも確認してください。";
end
if any(~trace.Succeeded), details.Warnings(end + 1) = "一部の周期候補で学習が失敗しました。探索履歴の理由を確認してください。"; end
if range(trace.LogLikelihood(trace.Succeeded)) < 1e-3
    details.Warnings(end + 1) = "周期による尤度の差が小さく、周期を十分に識別できていない可能性があります。";
end

    function score = evaluate(value)
        cached = find(abs(tested_frequency - value) <= 1e-10, 1);
        if ~isempty(cached), score = tested_scores(cached); return; end
        if numel(tested_scores) >= MAX_EVALUATIONS, score = Inf; return; end
        candidate = span / value; score = Inf; message = "";
        if ~isempty(progress), progress(numel(tested_scores) + 1, MAX_EVALUATIONS, candidate); end
        try
            likelihood = log_likelihood(candidate, bounds);
            if ~isscalar(likelihood) || ~isreal(likelihood) || ~isfinite(likelihood)
                error('swing_period:likelihood', '有限な周辺対数尤度を取得できません。');
            end
            score = -likelihood;
        catch err
            message = string(err.identifier) + ": " + string(err.message);
        end
        tested_frequency(end + 1, 1) = value; tested_scores(end + 1, 1) = score; messages(end + 1, 1) = message;
    end
end
