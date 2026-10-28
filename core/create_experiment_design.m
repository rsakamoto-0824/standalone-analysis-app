function [design, details] = create_experiment_design(method, factors, runs, seed, model, levels, existing)
% D/I は座標交換による局所探索。I 基準は [-1,1]^k 一様分布の厳密な積分モーメント。
if nargin < 7, existing = zeros(0, factors); end
validateattributes(factors, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 8});
validateattributes(runs, {'numeric'}, {'scalar', 'integer', '>=', 1, '<=', 300});
validateattributes(seed, {'numeric'}, {'scalar', 'integer', '>=', 0, '<=', 2^32 - 1});
validateattributes(levels, {'numeric'}, {'scalar', 'integer', '>=', 2, '<=', 3});
validateattributes(existing, {'numeric'}, {'2d', 'real', 'finite', '>=', -1, '<=', 1});
if size(existing, 2) ~= factors, error('doe:columns', '既存計画の列数を因子数と一致させてください。'); end
if ~any(strcmp(method, {'D', 'I', 'orthogonal'})), error('doe:method', '計画方式が不正です。'); end
previous_rng = rng; restore_rng = onCleanup(@() rng(previous_rng));
rng(seed, 'twister');
if strcmp(method, 'orthogonal')
    if ~isempty(existing), error('doe:augmentation', '直交表に既存点を固定した追加はできません。D/I を選択してください。'); end
    design = orthogonalArray(factors, levels);
    details = struct('Method', method, 'Criterion', NaN, 'FixedRows', 0, 'AddedRows', size(design, 1), 'Seed', seed);
    return;
end
[~, ~, powers] = doe_model_matrix(zeros(1, factors), model);
term_count = size(powers, 1);
fixed_count = size(existing, 1);
if fixed_count + runs < term_count
    error('doe:tooFewRuns', '選択モデルの項は%d個です。既存＋追加の実験数を%d以上にしてください。', term_count, term_count);
end
if fixed_count + runs > 500, error('doe:tooManyRuns', '既存＋追加は500行以下にしてください。'); end
% 奇数次数の積分は0、偶数次数は 1/(次数+1)。数値積分誤差を持ち込まない。
moments = zeros(term_count);
for row = 1:term_count
    combined = powers(row, :) + powers;
    moments(row, :) = (prod(1 ./ (combined + 1), 2) .* all(mod(combined, 2) == 0, 2))';
end
candidate_levels = [-1, 0, 1];
best_score = Inf; design = [];
STARTS = 4; MAX_PASSES = 12; IMPROVEMENT_TOLERANCE = 1e-9;
for start = 1:STARTS
    for attempt = 1:200
        sampled = reshape(candidate_levels(randi(3, runs, factors)), runs, factors);
        candidate = [existing; sampled];
        matrix = doe_model_matrix(candidate, model);
        if rank(matrix) == term_count, break; end
    end
    if rank(matrix) < term_count, continue; end
    information = matrix' * matrix;
    score = criterion(information, method, moments);
    for pass = 1:MAX_PASSES
        previous_score = score;
        for row = fixed_count + 1:size(candidate, 1)
            for factor = 1:factors
                old_term = matrix(row, :);
                without = information - old_term' * old_term;
                best_point = candidate(row, :); best_term = old_term;
                for value = candidate_levels
                    point = candidate(row, :); point(factor) = value;
                    term = doe_model_matrix(point, model);
                    trial = criterion(without + term' * term, method, moments);
                    if trial < score - IMPROVEMENT_TOLERANCE
                        score = trial; best_point = point; best_term = term;
                    end
                end
                candidate(row, :) = best_point; matrix(row, :) = best_term;
                information = without + best_term' * best_term;
            end
        end
        if previous_score - score < IMPROVEMENT_TOLERANCE, break; end
    end
    if score < best_score, best_score = score; design = candidate; end
end
if isempty(design), error('doe:singular', '独立なモデル項を持つ計画を生成できません。実験数を増やしてください。'); end
details = struct('Method', method, 'Criterion', best_score, 'FixedRows', fixed_count, 'AddedRows', runs, 'Seed', seed);
end

function score = criterion(information, method, moments)
[upper, failure] = chol((information + information') / 2);
if failure || rcond(information) < 1e-12, score = Inf; return; end
if strcmp(method, 'D')
    score = -2 * sum(log(diag(upper)));
else
    score = trace(upper \ (upper' \ moments));
end
end

function design = orthogonalArray(factors, levels)
% 素数水準の射影空間から強さ2の直交表を作る。2水準L4/L8/L16、3水準L9/L27。
dimensions = 2;
while (levels^dimensions - 1) / (levels - 1) < factors, dimensions = dimensions + 1; end
points = dec2base(0:levels^dimensions - 1, levels, dimensions) - '0';
generators = points(2:end, :);
keep = false(size(generators, 1), 1);
for row = 1:size(generators, 1)
    first = find(generators(row, :) ~= 0, 1);
    keep(row) = generators(row, first) == 1;
end
generators = generators(keep, :);
design = mod(points * generators(1:factors, :)', levels);
design = 2 * design / (levels - 1) - 1;
end
