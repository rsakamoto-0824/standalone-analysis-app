function [Train_Model, warnings] = train_apc_model(X, y, IsPlot, kernel, fit_method)
constants = model_constants();
if nargin < 3 || isempty(IsPlot), IsPlot = 0; end
if nargin < 4 || isempty(kernel), kernel = constants.DEFAULT_KERNEL; end
if nargin < 5 || isempty(fit_method), fit_method = constants.DEFAULT_FIT_METHOD; end
if ~isnumeric(X) || ~ismatrix(X)
    error('train_apc_model:invalidX', 'X は数値行列で渡してください。');
end
if size(X, 2) ~= 4
    error('train_apc_model:columnCount', ...
        'X の列数は 4 である必要があります（現在: %d）。', size(X, 2));
end
if size(X, 1) == 0
    error('train_apc_model:emptyX', 'X にデータが含まれていません。');
end
if ~isnumeric(y) || isempty(y) || ~isvector(y)
    error('train_apc_model:invalidY', 'y は空でない数値ベクトルで渡してください。');
end
if numel(y) ~= size(X, 1)
    error('train_apc_model:rowCount', ...
        'y の要素数 (%d) が X の行数 (%d) と一致しません。', numel(y), size(X, 1));
end
validate_model_parameters(kernel, fit_method, 'train_apc_model');
if size(X, 1) < constants.MIN_TRAIN_ROWS
    error('train_apc_model:tooFewRows', 'データが少ないため処理を中止します');
end
if ~isscalar(IsPlot) || ~any(IsPlot == [0, 1])
    error('train_apc_model:invalidIsPlot', 'IsPlot は 0 または 1 としてください。');
end
validate_numeric_data(X, 'X', 'train_apc_model');
validate_numeric_data(y(:), 'y', 'train_apc_model');
require_r2025b();
% TODO(要確認 Q-02) ResponseName は指定せず、保存前後の一致を検証する。
% TODO(要確認 Q-05) 学習時の乱数シードは固定しない。
X_table = array2table(X);
X_table.Properties.VariableNames = {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'};
y_col = double(y(:));

Train_Model = fitrgp(X_table,y_col,"FitMethod",fit_method, ...
    "KernelFunction",kernel,"Standardize",true,"BasisFunction",'constant');

warnings = strings(0, 1);
if size(X, 1) < constants.CAUTION_TRAIN_ROWS
    warnings(end + 1, 1) = "データが少ないためモデルの扱いに注意してください";
end
end
