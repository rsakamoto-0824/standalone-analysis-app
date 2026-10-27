function [Train_Model, warnings] = train_in_plane_model(X, y, kernel, fit_method)
constants = model_constants();
if nargin < 3 || isempty(kernel), kernel = constants.DEFAULT_KERNEL; end
if nargin < 4 || isempty(fit_method), fit_method = constants.DEFAULT_FIT_METHOD; end
if size(X, 2) ~= 2 || ~ismatrix(X)
    error('train_in_plane_model:columnCount', ...
        '第一引数（学習データの座標情報） は2列（X座標, Y座標）としてください。');
end
if size(X, 1) ~= numel(y)
    error('train_in_plane_model:rowCount', ...
        '第一引数（学習データの座標情報）の行数 と 第二引数（目的変数） の行数が一致しません。');
end
validate_model_parameters(kernel, fit_method, 'train_in_plane_model');
validate_numeric_data(X, 'X', 'train_in_plane_model');
validate_numeric_data(y(:), 'y', 'train_in_plane_model');
if ~isvector(y)
    error('train_in_plane_model:invalidY', 'y は数値ベクトルで渡してください。');
end
require_r2025b();
% TODO(要確認 Q-11) 半径 150 mm 以上の点も除外しない。
radius = sqrt(X(:,1).^2 + X(:,2).^2);
X_aug  = [X, radius];

Train_Model = fitrgp(X_aug, y(:), ...
    'KernelFunction', kernel, ...
    'FitMethod',      fit_method, ...
    'Standardize',    true);
warnings = strings(0, 1);
end
