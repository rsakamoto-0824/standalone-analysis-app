function name = default_model_filename(kind, target)
switch kind
    case 'apc', name = 'Train_Model.mat';
    case 'swing', name = 'SwingCurve_Model.mat';
    case 'generic', name = 'GenericGPR_Model.mat';
    case 'furnace', name = 'FurnaceInterpolation_Model.mat';
    otherwise, error('default_model_filename:kind', '保存対象の学習機能を指定してください。');
end
if nargin > 1 && ~isempty(target)
    [~, stem] = fileparts(name); name = [stem '_' matlab.lang.makeValidName(char(target)) '.mat'];
end
end
