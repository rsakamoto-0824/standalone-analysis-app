function report = compare_gpr_kernels(kind, X, y, kernels, fit_method, folds, seed, bins, progress, context)
if nargin < 9, progress = []; end
if nargin < 10, context = struct(); end
constants = model_constants();
if ~any(strcmp(kind, {'apc', 'swing', 'generic'}))
    error('compare_gpr_kernels:kind', 'APC・Swing Curve・汎用GPRの学習だけが比較対象です。');
end
if ~(iscellstr(kernels) || isstring(kernels)) || ~isvector(kernels)
    error('compare_gpr_kernels:kernels', 'カーネル名の一覧を渡してください。');
end
kernels = cellstr(lower(string(kernels(:))));
for index = 1:numel(kernels)
    validate_model_parameters(kernels{index}, fit_method, mfilename, strcmp(kind, 'swing'));
end
validateattributes(folds, {'numeric'}, {'scalar', 'integer', '>=', 2, '<=', min(10, size(X, 1))}, mfilename, 'folds');
if strcmp(kind, 'apc') && size(X, 1) - ceil(size(X, 1) / folds) < constants.MIN_TRAIN_ROWS
    error('compare_gpr_kernels:apcRows', 'APCは各分割の学習に25行以上必要です。行数を増やすか、分割数を増やしてください。');
end
if strcmp(kind, 'apc') && size(X, 2) ~= 4
    error('compare_gpr_kernels:columns', 'APCの説明変数は指定順の4列が必要です。');
end
require_r2025b();
report = evaluate_kernel_candidates(X, y, kernels, folds, seed, bins, @train, @predictNumeric, progress);
report.Kind = kind; report.FitMethod = fit_method;
report.Summary.FitMethod = repmat(string(fit_method), height(report.Summary), 1);

    function [model, warnings, details] = train(inputs, response, kernel, periodic_progress)
        details = [];
        switch kind
            case 'apc', [model, warnings] = train_apc_model(inputs, response, false, kernel, fit_method);
            case 'swing'
                names = constants.PREDICTOR_NAMES; options = swing_period_options();
                if isfield(context, 'PredictorNames'), names = context.PredictorNames; end
                if isfield(context, 'PeriodOptions'), options = context.PeriodOptions; end
                [model, warnings, details] = train_swing_gpr_model(inputs, response, names, kernel, fit_method, periodic_progress, options);
            case 'generic', [model, warnings] = train_generic_gpr_model(inputs, response, kernel, fit_method);
        end
    end
end

function prediction = predictNumeric(model, inputs)
prediction = predict(model, format_model_input(model, inputs));
end
