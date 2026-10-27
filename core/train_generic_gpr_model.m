function [Train_Model, warnings] = train_generic_gpr_model(X, y, kernel, fit_method)
% TODO(要確認 Q-07) 汎用 GPR 学習を独立機能として残す。
constants = model_constants();
if nargin < 3 || isempty(kernel), kernel = constants.DEFAULT_KERNEL; end
if nargin < 4 || isempty(fit_method), fit_method = constants.DEFAULT_FIT_METHOD; end
validate_model_parameters(kernel, fit_method, 'train_generic_gpr_model');
validate_numeric_data(X, 'X', 'train_generic_gpr_model');
validate_numeric_data(y(:), 'y', 'train_generic_gpr_model');
if ~isvector(y) || size(X, 1) ~= numel(y)
    error('train_generic_gpr_model:rowCount', 'X の行数と y の要素数を一致させてください。');
end
require_r2025b();
Train_Model = fitrgp(X, y(:), ...
    'KernelFunction', kernel, ...
    'FitMethod',      fit_method, ...
    'Standardize',    true);
warnings = strings(0, 1);
end
