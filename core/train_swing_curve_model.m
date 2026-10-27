function [Train_Model, warnings] = train_swing_curve_model(X, RESIST_TH, y, kernel, fit_method)
constants = model_constants();
if nargin < 4 || isempty(kernel), kernel = constants.DEFAULT_KERNEL; end
if nargin < 5 || isempty(fit_method), fit_method = constants.DEFAULT_FIT_METHOD; end
if ~isnumeric(RESIST_TH) || isempty(RESIST_TH)
    error('train_swing_curve_model:invalidResist', 'RESIST_TH は空でない数値ベクトルで渡してください。');
end
if ~ismatrix(RESIST_TH) || size(RESIST_TH, 2) ~= 1
    error('train_swing_curve_model:resistColumnCount', ...
        'RESIST_TH は列ベクトル [N x 1] で渡してください。現在のサイズ: [%d x %d]', ...
        size(RESIST_TH, 1), size(RESIST_TH, 2));
end
if ~isnumeric(y) || isempty(y) || ~isvector(y)
    error('train_swing_curve_model:invalidY', 'y は空でない数値ベクトルで渡してください。');
end
if numel(y) ~= numel(RESIST_TH)
    error('train_swing_curve_model:responseRowCount', ...
        'y の要素数 (%d) が RESIST_TH の行数 (%d) と一致しません。', numel(y), size(RESIST_TH, 1));
end
if ~isnumeric(X) || isempty(X)
    error('train_swing_curve_model:invalidX', '第一引数は空でない数値を渡してください。');
end
if size(X, 1) ~= size(RESIST_TH, 1)
    error('train_swing_curve_model:rowCount', ...
        'X の行数 (%d) が RESIST_TH の行数 (%d) と一致しません。', size(X, 1), size(RESIST_TH, 1));
end
if ~ismatrix(X) || size(X, 2) ~= 3
    error('train_swing_curve_model:columnCount', 'X は3列（SIN_TH, SIN_RN, NSG_TH）で渡してください。');
end
validate_model_parameters(kernel, fit_method, 'train_swing_curve_model');
validate_numeric_data(X, 'X', 'train_swing_curve_model');
validate_numeric_data(RESIST_TH, 'RESIST_TH', 'train_swing_curve_model');
validate_numeric_data(y(:), 'y', 'train_swing_curve_model');
require_r2025b();
X_table = array2table(X);
RESIST_TH_col = array2table(RESIST_TH);
y_col = double(y(:));

X_all = [X_table, RESIST_TH_col];
X_all.Properties.VariableNames = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'};

Train_Model = fitrgp(X_all, y_col(:), ...
    'KernelFunction', kernel, ...
    'FitMethod',      fit_method, ...
    'Standardize',    true);
warnings = strings(0, 1);
end
