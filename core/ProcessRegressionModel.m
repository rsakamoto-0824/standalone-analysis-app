classdef ProcessRegressionModel
    % 汎用回帰の GPR 以外の方式（重回帰・PLS・ランダムフォレスト・バギング木、Pro 版の EBM・XGBoost・LightGBM・CatBoost）。
    % 重回帰・PLS は係数、ランダムフォレスト・バギング木は決定木のアンサンブル（Ensemble）、
    % ブースティング系は自前の学習器（Booster：GradientBoostedTrees または ExplainableBoostingModel）で予測する。
    properties (SetAccess = private)
        Version = 1
        Method
        Components = 0
        PredictorNames
        ResponseName = 'y'
        X
        Y
        NumObservations
        Coefficients
        Intercept
        KernelFunction
        FitMethod = '-'
        Ensemble = []
        Trees = 0
        MinLeafSize = 0
        VariablesPerSplit = 0
        Hyperparameters = struct()
        Booster = []
        % PLS の VIP（Variable Importance in Projection）。説明変数ごとの値で、1を超える変数が重要とされる目安。
        Vip = []
        % Pro 版の GPR（加法カーネル・質的変数）。GP は学習済みの CompactRegressionGP、GPOptions は Additive・Categorical・Levels・FitMethod。
        GP = []
        GPOptions = struct()
    end
    properties (Constant)
        METHODS = {'linear', 'pls', 'forest', 'bagging', 'ebm', 'xgboost', 'lightgbm', 'catboost', 'gpr_pro'}
        % Pro 版だけの方式。gpr_pro は加法カーネル・質的変数に対応した GPR（回帰方式の「GPR」から使う）。
        PRO_METHODS = {'ebm', 'xgboost', 'lightgbm', 'catboost', 'gpr_pro'}
        BOOSTING_METHODS = {'ebm', 'xgboost', 'lightgbm', 'catboost'}
        % ハイパーパラメータを持つ方式（Pro 版では画面で調整・探索できる）。
        TUNABLE_METHODS = {'forest', 'bagging', 'ebm', 'xgboost', 'lightgbm', 'catboost'}
        DEFAULT_TREES = 100
        TREE_LIMITS = [10, 1000]
        % 回帰木のアンサンブルで一般的な既定値（TreeBagger の回帰と同じ）。
        MIN_LEAF_SIZE = 5
        FOREST_VARIABLE_FRACTION = 1 / 3
    end
    methods
        function model=ProcessRegressionModel(x,y,names,method,components,trees,parameters)
            % components は PLS の成分数、trees はランダムフォレスト・バギング木の木の本数。
            % parameters はハイパーパラメータ（hyperparameter_specs の名前を持つ構造体。省略した項目は既定値）。
            % ランダムフォレスト・バギング木で parameters に NumTrees があれば、trees より優先する。
            if nargin==0, return; end
            if nargin<5, components=2; end
            if nargin<6 || isempty(trees), trees=ProcessRegressionModel.DEFAULT_TREES; end
            if nargin<7, parameters=struct(); end
            validate_numeric_data(x,'説明変数',mfilename); validate_numeric_data(y,'目的変数',mfilename);
            names=cellstr(string(names(:)'));
            if ~isvector(y) || size(x,1)~=numel(y) || size(x,2)~=numel(names) || numel(unique(names))~=numel(names) || size(x,1)<2
                error('regression:shape','2行以上の説明変数・目的変数と、重複しない列名を指定してください。');
            end
            if ~ismember(method,ProcessRegressionModel.METHODS), error('regression:method','重回帰・PLS・ランダムフォレスト・バギング木・EBM・XGBoost・LightGBM・CatBoost・GPR（Pro版）のどれかを指定してください。'); end
            if ismember(method,ProcessRegressionModel.PRO_METHODS), require_pro_feature('EBM・XGBoost・LightGBM・CatBoost・加法カーネル／質的変数のGPR'); end
            x=double(x); y=double(y(:));
            model.Method=method; model.KernelFunction=method; model.PredictorNames=names;
            model.X=x; model.Y=y; model.NumObservations=size(x,1);
            if ismember(method,{'forest','bagging'})
                if ~isfield(parameters,'NumTrees')
                    limits=model.TREE_LIMITS;
                    if ~isnumeric(trees) || ~isscalar(trees) || trees~=round(trees) || trees<limits(1) || trees>limits(2)
                        error('regression:trees','木の本数は%d〜%dの整数で指定してください。',limits(1),limits(2));
                    end
                    parameters.NumTrees=trees;
                end
                model=model.fitEnsemble(hyperparameter_values(method,parameters)); return;
            end
            if strcmp(method,'gpr_pro')
                model=model.fitProGpr(parameters); return;
            end
            if ismember(method,ProcessRegressionModel.BOOSTING_METHODS)
                values=hyperparameter_values(method,parameters); model.Hyperparameters=values;
                if strcmp(method,'ebm'), model.Booster=ExplainableBoostingModel(x,y,values);
                else, model.Booster=GradientBoostedTrees(x,y,method,values); end
                return;
            end
            center=mean(x,1); scale=std(x,0,1); scale(scale==0)=1;
            z=(x-center)./scale; response_center=mean(y); response_scale=std(y);
            if response_scale==0, response_scale=1; end
            response=(y-response_center)/response_scale;
            if strcmp(method,'linear')
                design=[ones(size(z,1),1),z];
                if rank(design)<size(design,2), error('regression:rank','重回帰の説明変数が独立でありません。定数列・重複列と行数を確認してください。'); end
                beta=design\response;
            else
                validateattributes(components,{'numeric'},{'scalar','integer','>=',1,'<=',size(x,2)});
                if components>rank(z), error('regression:components','PLS成分数は学習データの独立な説明変数数（%d）以下にしてください。',rank(z)); end
                if all(response==0), beta=zeros(size(x,2)+1,1);
                else
                    [~,loadings,scores,~,beta,~,~,stats]=plsregress(z,response,components); model.Components=components;
                    model.Vip=ProcessRegressionModel.vipScores(stats.W,loadings,scores);
                end
            end
            coefficients=response_scale*beta(2:end)./scale';
            intercept=response_center+response_scale*beta(1)-center*coefficients;
            validate_numeric_data([intercept;coefficients],'回帰係数',mfilename);
            model.Coefficients=coefficients; model.Intercept=intercept;
        end
        function values=predict(model,x)
            if istable(x)
                if ~isequal(x.Properties.VariableNames,model.PredictorNames), error('regression:columnNames','保存モデルと同じ説明変数名・順序を指定してください。'); end
                x=table2array(x);
            end
            validate_numeric_data(x,'推定対象データ',mfilename);
            if size(x,2)~=numel(model.PredictorNames), error('regression:columnCount','モデルと同じ説明変数数を指定してください。'); end
            if ~isempty(model.GP)
                model.checkLevels(double(x)); values=predict(model.GP,double(x));
            elseif ~isempty(model.Booster)
                values=model.Booster.predict(double(x));
            elseif ~isempty(model.Ensemble)
                values=predict(model.Ensemble,double(x)); values=values(:);
            else
                values=double(x)*model.Coefficients+model.Intercept;
            end
            validate_numeric_data(values,'予測値',mfilename);
        end
        function text=methodLabel(model)
            % 画面に表示する方式名（学習条件の表示と同じ言い方）。
            if strcmp(model.Method,'gpr_pro')
                text=ProcessRegressionModel.proGprLabel(model.GPOptions.Additive,any(model.GPOptions.Categorical)); return;
            end
            text=modeling_condition_label(struct('Kernel',model.Method,'Regressor',model.Method, ...
                'Components',model.Components,'Trees',model.Trees,'Parameters',model.Hyperparameters,'Search',[]));
        end
    end
    methods (Static)
        function text=proGprLabel(additive,categorical)
            % 加法カーネル・質的変数の GPR の名前。質的変数があり加法でないときは、連続の列に ARD の二乗指数を使う。
            if additive && categorical
                text='GPR（加法カーネル・質的変数）';
            elseif additive
                text='GPR（加法カーネル）';
            else
                text='GPR（ARD二乗指数×質的変数）';
            end
        end
        function vip=vipScores(weights,response_loadings,scores)
            % VIP_j = sqrt( p × Σ_a SS_a (w_ja/||w_a||)² / Σ_a SS_a )、SS_a は成分 a が説明する目的変数の平方和。
            explained=sum(response_loadings.^2,1).*sum(scores.^2,1);
            normalized=weights./vecnorm(weights);
            vip=sqrt(size(weights,1)*(normalized.^2*explained')/sum(explained)); vip=vip(:)';
        end
    end
    methods (Access = private)
        function model=fitProGpr(model,options)
            % 加法カーネル・質的変数の GPR（Pro 版）。カーネルは mixed_gpr_kernel。初期値は列の標準偏差から決める。
            x=model.X; y=model.Y; predictors=size(x,2);
            categorical=false(1,predictors); levels=cell(1,predictors); additive=false; fit_method='exact';
            if isfield(options,'Categorical') && ~isempty(options.Categorical), categorical=logical(options.Categorical(:)'); end
            if isfield(options,'Levels') && ~isempty(options.Levels), levels=options.Levels; end
            if isfield(options,'Additive'), additive=logical(options.Additive); end
            if isfield(options,'FitMethod') && ~isempty(options.FitMethod), fit_method=options.FitMethod; end
            if numel(categorical)~=predictors, error('regression:categorical','質的変数の指定が説明変数の数と一致しません。'); end
            for column=find(categorical)
                if isempty(levels{column}), levels{column}=string(unique(x(:,column))); end
                codes=x(:,column);
                if any(codes~=round(codes) | codes<1 | codes>numel(levels{column}))
                    error('regression:categoricalCodes','質的変数の列「%s」の値は水準の番号（1〜%d）にしてください。',model.PredictorNames{column},numel(levels{column}));
                end
            end
            require_r2025b();
            scale=std(x(:,~categorical),0,1); scale(~isfinite(scale) | scale==0)=1;
            response_scale=std(y); if ~isfinite(response_scale) || response_scale==0, response_scale=1; end
            C=sum(~categorical); Q=sum(categorical);
            if additive
                share=response_scale/sqrt(max(C+Q,1));
                theta=[log(scale), repmat(log(share),1,C), repmat(log(share),1,Q), zeros(1,Q)];
            else
                theta=[log(scale), log(response_scale), zeros(1,Q)];
            end
            kernel=@(XN,XM,parameters) mixed_gpr_kernel(XN,XM,parameters,categorical,additive);
            gp=fitrgp(x,y,'KernelFunction',kernel,'KernelParameters',theta(:),'BasisFunction','constant', ...
                'FitMethod',fit_method,'Standardize',false,'Sigma',max(response_scale/10,1e-6));
            model.GP=compact(gp); model.KernelFunction='gpr_pro'; model.FitMethod=fit_method;
            model.GPOptions=struct('Additive',additive,'Categorical',categorical,'Levels',{levels},'FitMethod',fit_method);
        end
        function checkLevels(model,x)
            categorical=model.GPOptions.Categorical;
            for column=find(categorical)
                codes=x(:,column); count=numel(model.GPOptions.Levels{column});
                if any(codes~=round(codes) | codes<1 | codes>count)
                    error('regression:categoricalCodes','質的変数の列「%s」の値は、学習時の水準の番号（1〜%d）にしてください。',model.PredictorNames{column},count);
                end
            end
        end
        function model=fitEnsemble(model,values)
            % ランダムフォレストは分岐ごとに説明変数の一部（既定は約1/3）だけを候補にし、バギング木は全変数を候補にする。
            predictors=size(model.X,2); variables=predictors;
            if strcmp(model.Method,'forest'), variables=min(predictors,max(1,ceil(predictors*values.VariableFraction))); end
            template=templateTree('MinLeafSize',values.MinLeafSize,'NumVariablesToSample',variables,'Reproducible',true);
            ensemble=fitrensemble(model.X,model.Y,'Method','Bag','NumLearningCycles',values.NumTrees,'Learners',template);
            model.Ensemble=compact(ensemble); model.Trees=values.NumTrees; model.Hyperparameters=values;
            model.MinLeafSize=values.MinLeafSize; model.VariablesPerSplit=variables;
        end
    end
end
