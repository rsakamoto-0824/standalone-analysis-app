function Xnew = format_model_input(Train_Model, X)
validate_numeric_data(X, '推定対象データ', 'format_model_input');
if size(X, 2) ~= numel(Train_Model.PredictorNames)
    error('format_model_input:columnCount', ...
        '入力列数 (%d) がモデルの説明変数数 (%d) と一致しません。', ...
        size(X, 2), numel(Train_Model.PredictorNames));
end
% TODO(要確認 Q-01) 読み込んだモデルに合わせてアプリ内の入力形式だけを整える。
if istable(Train_Model.X)
    Xnew = array2table(X);
    Xnew.Properties.VariableNames = Train_Model.PredictorNames;
else
    Xnew = X;
end
end
