function model = fit_furnace_model(slots, response, method, options)
constants = furnace_constants();
if nargin < 4, options = struct(); end
if ~isfield(options, 'RBFWidth'), options.RBFWidth = constants.DefaultRBFWidth; end
if ~isfield(options, 'RBFRidge'), options.RBFRidge = constants.DefaultRBFRidge; end
if ~isvector(slots) || ~isvector(response), error('furnace:trainingShape', 'Slotと目的変数はベクトルにしてください。'); end
[slots, response] = metric_inputs(slots, response, 4, mfilename);
if numel(unique(slots)) ~= numel(slots), error('furnace:duplicateSlots', '学習するBoatSlotは重複できません。'); end
[slots, order] = sort(slots); response = response(order);
if ~any(strcmp(method, constants.Methods)), error('furnace:method', '炉内補間の方式が不正です。'); end
model = struct('Method', method, 'Fit', []);
switch method
    case 'spline'
        model.Fit = spline(slots, response);
    case 'rbf'
        validateattributes(options.RBFWidth, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
        validateattributes(options.RBFRidge, {'numeric'}, {'scalar', 'real', 'finite', '>=', constants.MinimumRBFRidge, '<=', constants.MaximumRBFRidge});
        width = options.RBFWidth;
        if width == 0, width = constants.AutomaticRBFGapMultiplier * median(diff(slots)); end
        center = mean(slots); scale = max(slots) - min(slots); z = (slots - center) / scale;
        response_center = mean(response); response_scale = std(response);
        if response_scale == 0, response_scale = 1; end
        gram = exp(-0.5 * ((z - z') / (width / scale)).^2);
        polynomial = [ones(size(z)), z];
        system = [gram + options.RBFRidge * eye(numel(z)), polynomial; polynomial', zeros(2)];
        if rcond(system) < constants.MinimumReciprocalCondition
            error('furnace:illConditioned', 'RBFの計算が不安定です。幅または正則化を変更してください。');
        end
        coefficients = system \ [(response - response_center) / response_scale; 0; 0];
        model.Fit = struct('Slots', z, 'Center', center, 'Scale', scale, 'Width', width / scale, ...
            'ResponseCenter', response_center, 'ResponseScale', response_scale, 'Coefficients', coefficients);
    otherwise
        require_r2025b();
        kernel = extractAfter(string(method), 'gpr_');
        % 屈折率の小さな変動に対しても、ノイズ初期値の絶対許容差を十分小さくする。
        model.ResponseCenter = mean(response); model.ResponseScale = std(response);
        if model.ResponseScale == 0, model.ResponseScale = 1; end
        standardized_response = (response - model.ResponseCenter) / model.ResponseScale;
        initial_parameters = [1; 1]; if strcmp(kernel, 'rationalquadratic'), initial_parameters = [1; 1; 1]; end
        model.Fit = fitrgp(slots, standardized_response, 'KernelFunction', char(kernel), 'FitMethod', 'exact', ...
            'PredictMethod', 'exact', 'Standardize', true, 'BasisFunction', 'linear', ...
            'KernelParameters', initial_parameters, 'Sigma', constants.GPRInitialSigma, 'SigmaLowerBound', constants.GPRMinimumSigma);
end
end
