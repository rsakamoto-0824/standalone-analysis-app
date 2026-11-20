function model=load_analysis_model(path)
variables=whos('-file',path);
if numel(variables)==1 && strcmp(variables.name,'Regression_Model')
    contents=load(path,'Regression_Model'); model=contents.Regression_Model;
    if ~isa(model,'ProcessRegressionModel') || model.Version~=1 || ~ismember(model.Method,ProcessRegressionModel.METHODS)
        error('regression:modelFormat','対応する重回帰・PLS・ランダムフォレスト・バギング木のモデルではありません。');
    end
    predict(model,model.X);
else
    model=load_train_model(path);
end
end
