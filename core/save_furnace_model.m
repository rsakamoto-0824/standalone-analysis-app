function report=save_furnace_model(item,options,path)
% 制御用Train_Modelとは別の、1Run・1目的変数・1方式の補間モデル。
if ~isfield(item,'Model') || isempty(item.Model), error('furnace:noModel','評価済みの補間モデルを選択してください。'); end
Furnace_Model=struct('Version',1,'Kind','furnace','Batch',item.Batch,'Target',item.Target,'Model',item.Model, ...
    'Slots',item.Slots,'Actual',item.Actual,'SourceRows',item.SourceRows,'Options',options);
probe=unique([item.Slots;(item.Slots(1:end-1)+item.Slots(2:end))/2]);
[before,deviation_before,interval_before]=predict_furnace_model(item.Model,probe);
save(path,'Furnace_Model'); loaded=load_furnace_model(path);
[after,deviation_after,interval_after]=predict_furnace_model(loaded.Model,probe);
metadata=isequaln(rmfield(Furnace_Model,'Model'),rmfield(loaded,'Model'));
report=struct('Success',metadata && isequal(before,after) && isequaln(deviation_before,deviation_after) && isequaln(interval_before,interval_after), ...
    'ProbeSlots',probe,'PredictionEqual',isequal(before,after),'IntervalEqual',isequaln(interval_before,interval_after));
if ~report.Success, error('furnace:saveVerification','保存前後の予測・区間・属性が一致しません。このモデルを使用しないでください。'); end
end
