function [Train_Model, warnings, details] = train_swing_periodic_model(X, RESIST_TH, y, fit_method, progress)
if nargin < 4 || isempty(fit_method), fit_method = 'exact'; end
if nargin < 5, progress = []; end
validate_model_parameters('swingperiodic', fit_method, mfilename, true);
validate_numeric_data(X, 'X', mfilename); validate_numeric_data(RESIST_TH, 'RESIST_TH', mfilename);
validate_numeric_data(y, 'y', mfilename);
if size(X, 2) ~= 3 || size(RESIST_TH, 2) ~= 1 || ~isvector(y) || ...
        size(X, 1) ~= numel(RESIST_TH) || numel(y) ~= numel(RESIST_TH)
    error('train_swing_periodic_model:shape', 'XはN×3、RESIST_THとyは同じ行数のベクトルにしてください。');
end
require_r2025b();
inputs = double([X, RESIST_TH]); y = double(y(:));
response_scale = std(y);
if ~isfinite(response_scale) || response_scale <= 0
    error('train_swing_periodic_model:response', '周期推定にはばらつきのある有限な応答値が必要です。');
end
resist_scale = std(inputs(:, 4));
if resist_scale < sqrt(eps), resist_scale = 1; end
constants = model_constants(); input_table = array2table(inputs, 'VariableNames', constants.PREDICTOR_NAMES);
theta0 = [zeros(4, 1); repmat(log(response_scale / sqrt(3)), 3, 1)];
seed_period = [];
try
    seed = fit_swing_curve(RESIST_TH, y); seed_period = seed.Period;
catch
    % 正弦波近似は候補の追加だけに使い、最終判断はGPRの尤度で行う。
end
MAX_ACTIVE_POINTS = 1000;
active = unique(round(linspace(1, size(inputs, 1), min(MAX_ACTIVE_POINTS, size(inputs, 1)))));
random_state = rng; random_cleanup = onCleanup(@() rng(random_state));
Train_Model = []; best_likelihood = -Inf;
details = optimize_swing_period(@fitCandidate, RESIST_TH, seed_period, progress);
if ~isempty(progress), progress(details.Evaluations, details.MaximumEvaluations, details.Period); end
details.FitMethod = fit_method;
if strcmpi(fit_method, 'exact'), details.Criterion = '周辺対数尤度';
else, details.Criterion = '近似周辺対数尤度'; end
info = swing_kernel_info(Train_Model.KernelFunction);
if ~isequal(info.Period, details.Period) || ~isequal(Train_Model.PredictorScale(4), resist_scale)
    error('train_swing_periodic_model:scale', '周期または膜厚の標準化尺度がモデルと一致しません。');
end
warnings = details.Warnings;

    function likelihood = fitCandidate(period, bounds)
        rng(random_state);
        kernel = make_swing_periodic_kernel(period, resist_scale, bounds);
        options = {'KernelFunction', kernel, 'KernelParameters', theta0, ...
            'FitMethod', fit_method, 'PredictMethod', fit_method, 'Standardize', true};
        % 近似法でも全周期で同じ部分集合を使い、候補間の基準をそろえる。
        if ~strcmpi(fit_method, 'exact'), options = [options, {'ActiveSet', active}]; end
        candidate = fitrgp(input_table, y, options{:});
        likelihood = candidate.LogLikelihood;
        if isfinite(likelihood) && likelihood > best_likelihood
            best_likelihood = likelihood; Train_Model = candidate;
        end
    end
end
