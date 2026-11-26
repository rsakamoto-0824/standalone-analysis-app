function conditions=modeling_conditions(kernels,regressors,fit_method,components,trees,parameters,search,categorical,extra)
% 比較する学習条件の一覧。GPRはカーネルごと、それ以外は方式ごとに1条件。
% components は PLS の成分数、trees はランダムフォレスト・バギング木の木の本数。
% parameters（省略可）は方式名ごとのハイパーパラメータ（例：parameters.xgboost.MaxDepth）。
% search（省略可）はハイパーパラメータの探索：Mode（'grid' / 'random'）、Trials、Folds、Seed と、
% 方式名ごとの探索候補 Candidates（例：Candidates.xgboost.MaxDepth = [2 4 6]）。候補のない方式は探索しない。
if nargin<5 || isempty(trees), trees=ProcessRegressionModel.DEFAULT_TREES; end
if nargin<6 || isempty(parameters), parameters=struct(); end
if nargin<7, search=[]; end
% categorical（省略可）：質的変数の情報 struct('Mask', 説明変数ごとの論理値, 'Levels', 水準の一覧)。すべての回帰方式で使う（Pro 版）。
% extra（省略可）：Loss（struct('Type', 'squared' / 'quantile', 'Quantile', τ)。GPR 以外の方式で使う）と
%                  Order（CatBoost の並べ替えに使う、行ごとの値。CatBoost だけで使う）。
if nargin<8, categorical=[]; end
if nargin<9 || isempty(extra), extra=struct(); end
loss=struct('Type','squared','Quantile',NaN); order=[];
if isfield(extra,'Loss') && ~isempty(extra.Loss), loss=extra.Loss; end
if isfield(extra,'Order'), order=extra.Order(:); end
if ~ismember(loss.Type,{'squared','quantile'}), error('modeling:loss','損失関数は二乗誤差または分位点を指定してください。'); end
if strcmp(loss.Type,'squared'), loss.Quantile=NaN; end
available=[{'gpr'},ProcessRegressionModel.METHODS];
if isempty(regressors) || ~all(ismember(regressors,available)), error('modeling:regressors','比較する回帰方式を選択してください。'); end
conditions=struct('Kernel',{},'FitMethod',{},'Regressor',{},'Components',{},'Trees',{},'Parameters',{},'Search',{},'Categorical',{}, ...
    'Loss',{},'Order',{});
for index=1:numel(regressors)
    method=regressors{index}; candidates={method}; fit='-'; values=struct(); method_search=[]; method_trees=trees;
    if strcmp(method,'gpr')
        if isempty(kernels), error('modeling:kernels','GPRのカーネルを選択してください。'); end
        candidates=kernels; fit=fit_method;
    end
    if ismember(method,ProcessRegressionModel.TUNABLE_METHODS)
        if isfield(parameters,method), values=parameters.(method); end
        if ismember(method,{'forest','bagging'})
            if isfield(values,'NumTrees'), method_trees=values.NumTrees; else, values.NumTrees=trees; end
        end
        values=hyperparameter_values(method,values);
        method_search=searchFor(search,method);
    end
    for kernel=1:numel(candidates)
        % 損失関数は GPR 以外、並べ替えは CatBoost だけに持たせる（GPR は常に平均と分散を予測する）。
        method_loss=[]; if ~strcmp(method,'gpr'), method_loss=loss; end
        method_order=[]; if strcmp(method,'catboost'), method_order=order; end
        conditions(end+1)=struct('Kernel',candidates{kernel},'FitMethod',fit,'Regressor',method,'Components',components, ...
            'Trees',method_trees,'Parameters',values,'Search',method_search,'Categorical',categoricalFor(categorical), ...
            'Loss',method_loss,'Order',method_order); %#ok<AGROW>
    end
end
end

function info=categoricalFor(categorical)
info=[];
if ~isempty(categorical) && any(categorical.Mask), info=categorical; end
end

function method_search=searchFor(search,method)
method_search=[];
if isempty(search) || ~isfield(search,'Candidates') || ~isfield(search.Candidates,method), return; end
candidates=search.Candidates.(method);
if isempty(fieldnames(candidates)), return; end
method_search=struct('Mode',search.Mode,'Trials',search.Trials,'Folds',search.Folds,'Seed',search.Seed,'Candidates',candidates);
end
