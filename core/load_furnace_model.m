function bundle=load_furnace_model(path)
variables=whos('-file',path);
if numel(variables)~=1 || ~strcmp(variables.name,'Furnace_Model')
    error('furnace:modelVariable','炉内補間のMATにはFurnace_Modelだけが必要です。');
end
contents=load(path,'Furnace_Model'); bundle=contents.Furnace_Model;
required={'Version','Kind','Batch','Target','Model','Slots','Actual','Options','SourceRows'};
if ~isstruct(bundle) || ~isscalar(bundle) || ~all(isfield(bundle,required)) || bundle.Version~=1 || ~strcmp(bundle.Kind,'furnace')
    error('furnace:modelFormat','対応する炉内補間モデルではありません。');
end
constants=furnace_constants();
if ~isstruct(bundle.Model) || ~isscalar(bundle.Model) || ~isfield(bundle.Model,'Method') || ~isfield(bundle.Model,'Fit') || ~ismember(bundle.Model.Method,constants.Methods)
    error('furnace:modelMethod','保存された補間方式が不正です。');
end
validate_numeric_data(bundle.Slots,'学習BoatSlot',mfilename); validate_numeric_data(bundle.Actual,'学習計測値',mfilename);
if numel(bundle.Slots)~=numel(bundle.Actual) || numel(bundle.Slots)~=numel(bundle.SourceRows)
    error('furnace:modelRows','保存モデルの学習データの件数が一致しません。');
end
end
