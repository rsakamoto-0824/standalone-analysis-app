function label=modeling_condition_label(condition)
label=condition.Kernel;
if ~isfield(condition,'Regressor'), return; end
if strcmp(condition.Regressor,'linear'), label='重回帰';
elseif strcmp(condition.Regressor,'pls'), label=sprintf('PLS（%d成分）',condition.Components); end
end
