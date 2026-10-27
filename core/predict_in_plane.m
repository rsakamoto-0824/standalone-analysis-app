function [y_pred, outside_rows, warnings] = predict_in_plane(Train_Model, X)
if ~ismatrix(X) || size(X, 2) ~= 2
    error('predict_in_plane:columnCount', '推定対象データは2列（X座標, Y座標）としてください。');
end
validate_numeric_data(X, '推定対象データ', 'predict_in_plane');
radius = sqrt(X(:,1).^2 + X(:,2).^2);
X_test_aug = [X, radius];
Xnew = format_model_input(Train_Model, X_test_aug);
[outside, outside_rows] = isExtrapolationDetected(Train_Model.X, X_test_aug);
warnings = strings(0, 1);
if outside
    warnings(end + 1, 1) = "警告：推定対象座標に学習データの範囲外が含まれます";
end
y_pred = predict(Train_Model, Xnew);
end
