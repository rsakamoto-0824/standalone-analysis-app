function report=save_regression_model(model,path)
if ~isa(model,'ProcessRegressionModel'), error('regression:modelClass','汎用回帰（重回帰・PLS・木・ブースティング・Pro版のGPR）のモデルを選択してください。'); end
Regression_Model=model; save(path,'Regression_Model'); loaded=load_analysis_model(path);
variables=whos('-file',path);
checks={'変数名','Regression_Model',variables.name,strcmp(variables.name,'Regression_Model'); ...
    'モデル方式',model.Method,loaded.Method,strcmp(model.Method,loaded.Method); ...
    'PredictorNames',strjoin(model.PredictorNames,', '),strjoin(loaded.PredictorNames,', '),isequal(model.PredictorNames,loaded.PredictorNames); ...
    '保存前後の属性','一致','一致',isequaln(comparable(model),comparable(loaded)); ...
    '学習データの予測','完全一致','完全一致',isequal(predict(model,model.X),predict(loaded,model.X))};
report=struct('Success',all([checks{:,4}]),'Checks',cell2table(checks,'VariableNames',{'Item','Expected','Actual','Passed'}), ...
    'Message','保存後の自動検証に成功しました。');
if ~report.Success, report.Message='保存後の検証に失敗しました。このモデルを使用しないでください。'; end
end

function values=comparable(model)
% 保存前後で比べる属性。Pro 版の GPR はカーネルを関数ハンドルで持ち、読み直すと別のハンドルになるため、
% GP は学習した値（カーネルのパラメータ・基底の係数・ノイズ）で比べる。
values=struct();
for name=properties(model)'
    values.(name{1})=model.(name{1});
end
if ~isempty(model.GP)
    values.GP=struct('KernelParameters',model.GP.KernelInformation.KernelParameters,'Beta',model.GP.Beta,'Sigma',model.GP.Sigma);
end
end
