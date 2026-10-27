function Train_Model = load_train_model(fullName)
require_r2025b();
S = load(fullName, "Train_Model");
if ~isfield(S, 'Train_Model')
    error('load_train_model:missingModel', '学習済みモデル（Train_Model）が見つかりません');
end
if ~strcmp(class(S.Train_Model), 'RegressionGP')
    error('load_train_model:invalidClass', '学習済みモデルは RegressionGP である必要があります。');
end
Train_Model = S.Train_Model;
end
