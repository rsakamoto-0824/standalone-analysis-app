function conditions=modeling_conditions(kernels,regressors,fit_method,components,trees)
% 比較する学習条件の一覧。GPRはカーネルごと、それ以外は方式ごとに1条件。
% components は PLS の成分数、trees はランダムフォレスト・バギング木の木の本数。
if nargin<5, trees=ProcessRegressionModel.DEFAULT_TREES; end
available=[{'gpr'},ProcessRegressionModel.METHODS];
if isempty(regressors) || ~all(ismember(regressors,available)), error('modeling:regressors','比較する回帰方式を選択してください。'); end
conditions=struct('Kernel',{},'FitMethod',{},'Regressor',{},'Components',{},'Trees',{});
for index=1:numel(regressors)
    method=regressors{index}; candidates={method}; fit='-';
    if strcmp(method,'gpr')
        if isempty(kernels), error('modeling:kernels','GPRのカーネルを選択してください。'); end
        candidates=kernels; fit=fit_method;
    end
    for kernel=1:numel(candidates)
        conditions(end+1)=struct('Kernel',candidates{kernel},'FitMethod',fit,'Regressor',method,'Components',components,'Trees',trees); %#ok<AGROW>
    end
end
end
