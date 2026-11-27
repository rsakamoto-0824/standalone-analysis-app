function result = hierarchical_bayes(response, predictors, groups, names, group_names, options)
% 階層ベイズ回帰（Pro 版）。グループ（ロット・装置など）ごとに回帰係数を持たせ、それらが全体の分布 N(μ, Σ) から
% 出ていると考えて、データの少ないグループの係数を全体の傾向へ引き寄せて（縮小して）推定する。
%   y = 切片_g + Σ 傾き_gk × x_k + 誤差（誤差 ~ N(0, σ²)）
%   options.Varying：'intercept'（切片だけグループごと、傾きは共通）または 'all'（切片と傾きをグループごと）
% 計算はギブスサンプリング（MCMC）。目的変数・説明変数を標準化して計算し、結果は元の単位へ戻す。
% 事前分布は標準化した単位で弱い情報のもの：μ・共通の係数 ~ N(0, 10²)、Σ ~ 逆ウィシャート(項数+2, 単位行列)、σ² ~ 逆ガンマ(1, 1)。
% options：Iterations（既定 2000）、BurnIn（既定 1000）、Chains（既定 2）、Seed（既定 0）、
%          Progress（省略可。進捗の関数 Progress(done, total, stage)。PROGRESS_EVERY 回ごとに呼ぶ）。
% 収束の目安として、各量の R-hat（Gelman–Rubin。1.1 未満が目安）を出す。
defaults = struct('Varying', 'all', 'Iterations', 2000, 'BurnIn', 1000, 'Chains', 2, 'Seed', 0, 'Progress', []);
PROGRESS_EVERY = 25;
given = fieldnames(options);
for index = 1:numel(given), defaults.(given{index}) = options.(given{index}); end
options = defaults;
validate_numeric_data(response, '目的変数', mfilename); if ~isempty(predictors), validate_numeric_data(predictors, '説明変数', mfilename); end
response = double(response(:)); [rows, count] = size(predictors); groups = double(groups(:));
group_count = numel(group_names);
if rows ~= numel(response) || numel(groups) ~= rows, error('bayes:shape', '目的変数・説明変数・グループの行数を一致させてください。'); end
if group_count < 2, error('bayes:groups', 'グループの列には2つ以上の値が必要です。'); end
if options.BurnIn >= options.Iterations, error('bayes:iterations', '捨てる回数（バーンイン）は繰り返し回数より小さくしてください。'); end
if rows < count + 3, error('bayes:rows', '行数が少なすぎます（説明変数の数＋3行以上が必要です）。'); end
y_mean = mean(response); y_scale = std(response); if y_scale == 0, error('bayes:constant', '目的変数の値が一定です。'); end
x_mean = mean(predictors, 1); x_scale = std(predictors, 0, 1);
if any(x_scale == 0), error('bayes:constantPredictor', '値が一定の説明変数は使えません: %s', strjoin(cellstr(string(names(x_scale == 0))), ', ')); end
y = (response - y_mean) / y_scale; X = [ones(rows, 1), (predictors - x_mean) ./ x_scale];
terms = count + 1; varying = 1:terms; if strcmp(options.Varying, 'intercept'), varying = 1; end
fixed = setdiff(1:terms, varying); Z = X(:, varying); W = X(:, fixed); q = numel(varying); f = numel(fixed);
PRIOR_SD = 10; prior_df = q + 2; prior_scale = eye(q); A0 = 1; B0 = 1;
kept = options.Iterations - options.BurnIn; chains = options.Chains;
draws_b = zeros(kept, q, group_count, chains); draws_mu = zeros(kept, q, chains); draws_gamma = zeros(kept, f, chains);
draws_sigma = zeros(kept, chains); draws_tau = zeros(kept, q, chains);
members = arrayfun(@(g) find(groups == g), 1:group_count, 'UniformOutput', false);
previous = rng; restore = onCleanup(@() rng(previous));
for chain = 1:chains
    rng(options.Seed + chain - 1, 'twister');
    b = 0.5 * randn(q, group_count); mu = zeros(q, 1); Sigma = eye(q); gamma = zeros(f, 1); sigma2 = 1;
    for iteration = 1:options.Iterations
        if ~isempty(options.Progress) && mod(iteration - 1, PROGRESS_EVERY) == 0
            options.Progress((chain - 1) * options.Iterations + iteration - 1, chains * options.Iterations, ...
                sprintf('鎖 %d / %d・繰り返し %d / %d 回', chain, chains, iteration - 1, options.Iterations));
        end
        offset = W * gamma; Sigma_inv = inv(Sigma);
        for g = 1:group_count
            index = members{g}; Zg = Z(index, :);
            precision = Zg' * Zg / sigma2 + Sigma_inv; covariance = inv((precision + precision') / 2);
            centre = covariance * (Zg' * (y(index) - offset(index)) / sigma2 + Sigma_inv * mu); %#ok<MINV> 抽出に共分散行列そのものも使う
            b(:, g) = centre + chol(covariance, 'lower') * randn(q, 1);
        end
        varying_part = sum(Z .* b(:, groups)', 2);
        if f > 0
            precision = W' * W / sigma2 + eye(f) / PRIOR_SD^2; covariance = inv((precision + precision') / 2);
            centre = covariance * (W' * (y - varying_part) / sigma2); %#ok<MINV> 抽出に共分散行列そのものも使う
            gamma = centre + chol(covariance, 'lower') * randn(f, 1);
        end
        precision = group_count * Sigma_inv + eye(q) / PRIOR_SD^2; covariance = inv((precision + precision') / 2); %#ok<MINV> 抽出に共分散行列そのものも使う
        centre = covariance * (Sigma_inv * sum(b, 2)); mu = centre + chol(covariance, 'lower') * randn(q, 1); %#ok<MINV> 抽出に共分散行列そのものも使う
        deviation = b - mu; Sigma = iwishrnd(prior_scale + deviation * deviation', prior_df + group_count);
        residual = y - varying_part - W * gamma;
        sigma2 = 1 / gamrnd(A0 + rows / 2, 1 / (B0 + residual' * residual / 2));
        if iteration > options.BurnIn
            k = iteration - options.BurnIn;
            draws_b(k, :, :, chain) = b; draws_mu(k, :, chain) = mu; draws_gamma(k, :, chain) = gamma;
            draws_sigma(k, chain) = sqrt(sigma2); draws_tau(k, :, chain) = sqrt(diag(Sigma));
        end
    end
end
clear restore;
% ---- 元の単位へ戻す：傾き = σy/σx × β、切片 = 平均y + σy × (β0 − Σ β_k 平均x_k/σx_k)。
term_names = ["切片", string(names(:)')];
toOriginal = @(beta) originalUnits(beta, y_mean, y_scale, x_mean, x_scale);
full = @(v, fixed_values) assemble(v, fixed_values, varying, fixed, terms);
overall = zeros(kept * chains, terms); group_coefficients = zeros(kept * chains, terms, group_count);
sample = 0;
for chain = 1:chains
    for k = 1:kept
        sample = sample + 1; fixed_values = draws_gamma(k, :, chain)';
        overall(sample, :) = toOriginal(full(draws_mu(k, :, chain)', fixed_values));
        for g = 1:group_count, group_coefficients(sample, :, g) = toOriginal(full(draws_b(k, :, g, chain)', fixed_values)); end
    end
end
kind = repmat("共通", terms, 1); kind(varying) = "グループごと（全体の平均 μ）";
rhat_overall = zeros(terms, 1);
for t = 1:terms
    per_chain = reshape(overall(:, t), kept, chains); rhat_overall(t) = gelmanRubin(per_chain);
end
result.Overall = [table(term_names', kind, 'VariableNames', {'項', '種類'}), summaryTable(overall), table(rhat_overall, 'VariableNames', {'R_hat'})];
rows_table = table(); ols = noPooling(response, predictors, groups, group_count);
for g = 1:group_count
    for t = 1:terms
        values = squeeze(group_coefficients(:, t, g)); rhat = gelmanRubin(reshape(values, kept, chains));
        rows_table = [rows_table; table(string(group_names(g)), term_names(t), sum(groups == g), mean(values), prctile(values, 2.5), prctile(values, 97.5), ...
            ols(g, t), rhat, 'VariableNames', {'グループ', '項', '件数', '事後平均', '下限_2_5', '上限_97_5', 'グループ単独の最小二乗', 'R_hat'})]; %#ok<AGROW>
    end
end
result.Groups = rows_table;
sigma_original = draws_sigma(:) * y_scale; tau_original = reshape(permute(draws_tau, [1, 3, 2]), [], q) .* (y_scale ./ [1, x_scale(varying(varying > 1) - 1)]);
spread_names = ["残差の標準偏差 σ"; "グループ間の標準偏差：" + term_names(varying)'];
spread_values = [sigma_original, tau_original];
spread_rhat = [gelmanRubin(draws_sigma); arrayfun(@(t) gelmanRubin(squeeze(draws_tau(:, t, :))), (1:q)')];
result.Spread = [table(spread_names, 'VariableNames', {'項目'}), summaryTable(spread_values), table(spread_rhat, 'VariableNames', {'R_hat'})];
fitted = zeros(rows, 1);
for g = 1:group_count
    index = members{g}; beta = mean(squeeze(group_coefficients(:, :, g)), 1)';
    fitted(index) = beta(1) + predictors(index, :) * beta(2:end);
end
result.Fitted = fitted; result.Residual = response - fitted;
result.TraceMu = draws_mu; result.TraceSigma = draws_sigma * y_scale; result.TermNames = term_names; result.Varying = varying;
result.GroupCoefficients = group_coefficients; result.OverallDraws = overall; result.MaxRhat = max([rhat_overall; result.Groups.R_hat; spread_rhat]);
end

function beta = assemble(varying_values, fixed_values, varying, fixed, terms)
beta = zeros(terms, 1); beta(varying) = varying_values; beta(fixed) = fixed_values;
end

function beta = originalUnits(beta, y_mean, y_scale, x_mean, x_scale)
slopes = y_scale * beta(2:end)' ./ x_scale;
beta = [y_mean + y_scale * beta(1) - sum(slopes .* x_mean), slopes];
end

function summary = summaryTable(values)
summary = table(mean(values, 1)', std(values, 0, 1)', prctile(values, 2.5, 1)', prctile(values, 97.5, 1)', ...
    'VariableNames', {'事後平均', '事後標準偏差', '下限_2_5', '上限_97_5'});
end

function rhat = gelmanRubin(per_chain)
% 列が鎖（チェーン）。鎖が1本のときは NaN。
[n, m] = size(per_chain);
if m < 2, rhat = NaN; return; end
between = n * var(mean(per_chain, 1)); within = mean(var(per_chain, 0, 1));
if within == 0, rhat = 1; return; end
rhat = sqrt(((n - 1) / n * within + between / n) / within);
end

function coefficients = noPooling(response, predictors, groups, group_count)
% 比べるための、グループごとに別々に当てはめた最小二乗の係数（行が足りないグループは NaN）。
coefficients = NaN(group_count, size(predictors, 2) + 1);
for g = 1:group_count
    index = groups == g; design = [ones(sum(index), 1), predictors(index, :)];
    if sum(index) > size(design, 2) && rank(design) == size(design, 2), coefficients(g, :) = (design \ response(index))'; end
end
end
