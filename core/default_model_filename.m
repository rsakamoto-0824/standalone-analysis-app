function name = default_model_filename(kind)
switch kind
    case 'apc', name = 'Train_Model.mat';
    case 'swing', name = 'SwingCurve_Model.mat';
    case 'generic', name = 'GenericGPR_Model.mat';
    otherwise, error('default_model_filename:kind', '保存対象の学習機能を指定してください。');
end
end
