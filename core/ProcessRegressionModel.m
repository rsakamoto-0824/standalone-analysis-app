classdef ProcessRegressionModel
    % 汎用回帰の GPR 以外の方式（重回帰・PLS・ランダムフォレスト・バギング木、Pro 版の EBM・XGBoost・LightGBM・CatBoost）。
    % 重回帰・PLS は係数、ランダムフォレスト・バギング木は決定木のアンサンブル（Ensemble）、
    % ブースティング系は自前の学習器（Booster：GradientBoostedTrees または ExplainableBoostingModel）で予測する。
    % options（省略可。8番目の引数）：
    %   Categorical（説明変数ごとの論理値）と Levels（水準の一覧）：質的変数の列（Pro 版）。値は水準の番号 1, 2, …
    %     重回帰・PLS は2番目以降の水準を表す0/1の列（ダミー変数）に置き換え、ランダムフォレスト・バギング木は
    %     木が水準の組で分かれる（fitrensemble の CategoricalPredictors）。ブースティング系の扱いは GradientBoostedTrees を参照。
    %   Loss（'squared' / 'quantile'）と Quantile（τ）：損失関数。'quantile' はピンボール損失で τ 分位点を予測する（分位点回帰）。
    %     重回帰・PLS は重み付き最小二乗の繰り返し（IRLS）、ランダムフォレスト・バギング木は葉に入った学習データの
    %     目的変数の分布から分位点を求める（Quantile Regression Forest）。
    %   Order：CatBoost の並べ替えに使う、学習の行ごとの値（順序付きブースティング・Ordered Target Statistics の順）。
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
        % 質的変数の列（論理値）と水準の一覧（GPR 以外の方式。GPR は GPOptions に持つ）。
        Categorical = []
        Levels = {}
        % 損失関数：'squared'（平均を予測）または 'quantile'（分位点 Quantile を予測）。
        Loss = 'squared'
        Quantile = NaN
        % 分位点回帰のランダムフォレスト・バギング木：木ごとの、学習データの各行が入った葉の番号（行 × 木）。
        ForestLeaves = []
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
        % 分位点 τ の範囲（両端は学習データの最小・最大に近づき不安定になるため除く）。
        QUANTILE_LIMITS = [0.01, 0.99]
        % 分位点回帰の重み付き最小二乗の繰り返し（IRLS）の上限と、残差の下限（目的変数の標準偏差に対する比）。
        IRLS_MAX_ITERATIONS = 500
        IRLS_RESIDUAL_FLOOR = 1e-6
        % 分位点回帰のランダムフォレストで、一度に重みを計算する推定対象の行数（メモリを抑えるため）。
        FOREST_CHUNK_ROWS = 500
    end
    methods
        function model=ProcessRegressionModel(x,y,names,method,components,trees,parameters,options)
            % components は PLS の成分数、trees はランダムフォレスト・バギング木の木の本数。
            % parameters はハイパーパラメータ（hyperparameter_specs の名前を持つ構造体。省略した項目は既定値）。
            % ランダムフォレスト・バギング木で parameters に NumTrees があれば、trees より優先する。
            % options は質的変数・損失関数・CatBoost の並べ替え（上の説明を参照）。gpr_pro は parameters に持つ。
            if nargin==0, return; end
            if nargin<5, components=2; end
            if nargin<6 || isempty(trees), trees=ProcessRegressionModel.DEFAULT_TREES; end
            if nargin<7, parameters=struct(); end
            if nargin<8, options=struct(); end
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
            if ~strcmp(method,'gpr_pro'), [model,options]=model.applyOptions(options); end
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
                booster_options=struct('Categorical',model.categoricalMask(),'LevelCounts',model.levelCounts(), ...
                    'Loss',model.Loss,'Quantile',model.Quantile,'Order',options.Order);
                if strcmp(method,'ebm'), model.Booster=ExplainableBoostingModel(x,y,values,booster_options);
                else, model.Booster=GradientBoostedTrees(x,y,method,values,booster_options); end
                return;
            end
            % 重回帰・PLS：質的変数はダミー変数（2番目以降の水準を表す0/1の列）に置き換える。
            x=model.designInputs(x);
            center=mean(x,1); scale=std(x,0,1); scale(scale==0)=1;
            z=(x-center)./scale; response_center=mean(y); response_scale=std(y);
            if response_scale==0, response_scale=1; end
            response=(y-response_center)/response_scale;
            if strcmp(method,'linear')
                design=[ones(size(z,1),1),z];
                if rank(design)<size(design,2), error('regression:rank','重回帰の説明変数が独立でありません。定数列・重複列と行数を確認してください。'); end
                if strcmp(model.Loss,'quantile'), beta=ProcessRegressionModel.quantileFit(design,response,model.Quantile);
                else, beta=design\response; end
            else
                validateattributes(components,{'numeric'},{'scalar','integer','>=',1,'<=',size(x,2)});
                if components>rank(z), error('regression:components','PLS成分数は学習データの独立な説明変数数（%d）以下にしてください。',rank(z)); end
                if all(response==0), beta=zeros(size(x,2)+1,1);
                else
                    [~,loadings,scores,~,beta,~,~,stats]=plsregress(z,response,components); model.Components=components;
                    model.Vip=model.predictorVip(ProcessRegressionModel.vipScores(stats.W,loadings,scores));
                    if strcmp(model.Loss,'quantile')
                        % PLS の成分（スコア）に分位点回帰を当てはめ、元の列の係数へ戻す（スコア = 中心化した入力 × W）。
                        b=ProcessRegressionModel.quantileFit([ones(size(scores,1),1),scores],response,model.Quantile);
                        beta=[b(1);stats.W*b(2:end)];
                    end
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
            x=double(x); model.checkLevels(x);
            if ~isempty(model.GP)
                values=predict(model.GP,x);
            elseif ~isempty(model.Booster)
                values=model.Booster.predict(x);
            elseif ~isempty(model.ForestLeaves)
                values=model.forestQuantile(x);
            elseif ~isempty(model.Ensemble)
                values=predict(model.Ensemble,x); values=values(:);
            else
                values=model.designInputs(x)*model.Coefficients+model.Intercept;
            end
            validate_numeric_data(values,'予測値',mfilename);
        end
        function text=methodLabel(model)
            % 画面に表示する方式名（学習条件の表示と同じ言い方）。
            if strcmp(model.Method,'gpr_pro')
                text=ProcessRegressionModel.proGprLabel(model.GPOptions.Additive,any(model.GPOptions.Categorical)); return;
            end
            text=modeling_condition_label(struct('Kernel',model.Method,'Regressor',model.Method, ...
                'Components',model.Components,'Trees',model.Trees,'Parameters',model.Hyperparameters,'Search',[], ...
                'Loss',struct('Type',model.Loss,'Quantile',model.Quantile)));
        end
        function [mask,levels]=categoricalInfo(model)
            % 質的変数の列（論理値）と水準の一覧。GPR（gpr_pro）は GPOptions、それ以外は Categorical・Levels から返す。
            % 以前に保存したモデル（この項目がない）は、質的変数なしとして扱う。
            count=numel(model.PredictorNames); mask=false(1,count); levels=cell(1,count);
            if isfield(model.GPOptions,'Categorical') && ~isempty(model.GPOptions.Categorical)
                mask=logical(model.GPOptions.Categorical(:)'); levels=model.GPOptions.Levels;
            elseif ~isempty(model.Categorical)
                mask=logical(model.Categorical(:)'); levels=model.Levels;
            end
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
        function beta=quantileFit(design,response,tau)
            % 分位点回帰：Σ ρτ(y − Xβ) を最小にする β（ρτ(r) = r(τ − 1(r<0)) はピンボール損失）。
            % 重みを残差の大きさの逆数（正の残差は τ 倍、負の残差は 1−τ 倍）とした重み付き最小二乗を繰り返す（IRLS）。
            beta=design\response;
            floor_value=ProcessRegressionModel.IRLS_RESIDUAL_FLOOR*max(std(response),eps);
            for iteration=1:ProcessRegressionModel.IRLS_MAX_ITERATIONS
                residual=response-design*beta;
                weights=(tau*(residual>=0)+(1-tau)*(residual<0))./max(abs(residual),floor_value);
                root=sqrt(weights); updated=(design.*root)\(response.*root);
                converged=norm(updated-beta)<=1e-9*(1+norm(beta)); beta=updated;
                if converged, break; end
            end
        end
        function value=pinballLoss(actual,predicted,tau)
            % ピンボール損失の平均（分位点回帰の当てはまりの指標。小さいほど良い）。
            residual=actual(:)-predicted(:); value=mean(max(tau*residual,(tau-1)*residual));
        end
        function vip=vipScores(weights,response_loadings,scores)
            % VIP_j = sqrt( p × Σ_a SS_a (w_ja/||w_a||)² / Σ_a SS_a )、SS_a は成分 a が説明する目的変数の平方和。
            explained=sum(response_loadings.^2,1).*sum(scores.^2,1);
            normalized=weights./vecnorm(weights);
            vip=sqrt(size(weights,1)*(normalized.^2*explained')/sum(explained)); vip=vip(:)';
        end
    end
    methods (Access = private)
        function [model,options]=applyOptions(model,options)
            % 質的変数・損失関数・CatBoost の並べ替えを確かめて、モデルに持たせる。
            predictors=numel(model.PredictorNames);
            defaults=struct('Categorical',false(1,predictors),'Levels',{cell(1,predictors)},'Loss','squared','Quantile',NaN,'Order',[]);
            for name=fieldnames(defaults)'
                if ~isfield(options,name{1}) || isempty(options.(name{1})), options.(name{1})=defaults.(name{1}); end
            end
            mask=logical(options.Categorical(:)');
            if numel(mask)~=predictors, error('regression:categorical','質的変数の指定が説明変数の数と一致しません。'); end
            if any(mask)
                require_pro_feature('質的変数を使う回帰');
                levels=options.Levels; if numel(levels)~=predictors, levels=cell(1,predictors); end
                for column=find(mask)
                    if isempty(levels{column}), levels{column}=string(unique(model.X(:,column))); end
                    codes=model.X(:,column);
                    if any(codes~=round(codes) | codes<1 | codes>numel(levels{column}))
                        error('regression:categoricalCodes','質的変数の列「%s」の値は水準の番号（1〜%d）にしてください。',model.PredictorNames{column},numel(levels{column}));
                    end
                end
                model.Categorical=mask; model.Levels=levels;
            end
            loss=char(options.Loss);
            if ~ismember(loss,{'squared','quantile'}), error('regression:loss','損失関数は二乗誤差（squared）または分位点（quantile）を指定してください。'); end
            if strcmp(loss,'quantile')
                tau=options.Quantile; limits=ProcessRegressionModel.QUANTILE_LIMITS;
                if ~isnumeric(tau) || ~isscalar(tau) || ~(tau>=limits(1) && tau<=limits(2))
                    error('regression:quantile','分位点 τ は %g〜%g の数値で指定してください。',limits(1),limits(2));
                end
                model.Loss='quantile'; model.Quantile=double(tau);
            end
            if ~isempty(options.Order) && numel(options.Order)~=model.NumObservations
                error('regression:order','CatBoost の並べ替え列は、学習に使う行と同じ数の値にしてください。');
            end
        end
        function mask=categoricalMask(model)
            mask=false(1,numel(model.PredictorNames));
            if ~isempty(model.Categorical), mask=logical(model.Categorical(:)'); end
        end
        function counts=levelCounts(model)
            counts=zeros(1,numel(model.PredictorNames));
            for column=find(model.categoricalMask()), counts(column)=numel(model.Levels{column}); end
        end
        function design=designInputs(model,x)
            % 重回帰・PLS の入力：質的変数の列を、2番目以降の水準を表す0/1の列（ダミー変数）に置き換える。
            mask=model.categoricalMask();
            if ~any(mask), design=x; return; end
            parts=cell(1,numel(mask));
            for column=1:numel(mask)
                if mask(column), parts{column}=double(x(:,column)==(2:numel(model.Levels{column})));
                else, parts{column}=x(:,column); end
            end
            design=[parts{:}];
        end
        function vip=predictorVip(model,column_vip)
            % ダミー変数に分けた列の VIP を、元の説明変数ごとにまとめる（VIP² の平均の平方根）。
            mask=model.categoricalMask();
            if ~any(mask), vip=column_vip; return; end
            widths=ones(1,numel(mask));
            for column=find(mask), widths(column)=numel(model.Levels{column})-1; end
            ends=cumsum(widths); starts=ends-widths+1; vip=zeros(1,numel(mask));
            for column=1:numel(mask), vip(column)=sqrt(mean(column_vip(starts(column):ends(column)).^2)); end
        end
        function values=forestQuantile(model,x)
            % Quantile Regression Forest（Meinshausen 2006）：推定する行と同じ葉に入った学習データの行に、
            % 「1 / 葉の行数」の重みを木ごとに付けて平均し、その重みで目的変数の分位点を求める。
            trees=model.Ensemble.Trained; count=numel(trees); rows=size(x,1); values=zeros(rows,1);
            [sorted_y,order]=sort(model.Y); leaves=model.ForestLeaves(order,:);
            chunk=ProcessRegressionModel.FOREST_CHUNK_ROWS;
            for first=1:chunk:rows
                part=first:min(first+chunk-1,rows); weights=zeros(numel(part),numel(sorted_y));
                for tree=1:count
                    [~,node]=predict(trees{tree},x(part,:));
                    sizes=accumarray(leaves(:,tree),1,[max([leaves(:,tree);node]),1]);
                    weights=weights+(node==leaves(:,tree)')./sizes(node);
                end
                cumulative=cumsum(weights,2)/count;
                for index=1:numel(part)
                    position=find(cumulative(index,:)>=model.Quantile-1e-12,1);
                    if isempty(position), position=numel(sorted_y); end
                    values(part(index))=sorted_y(position);
                end
            end
        end
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
            [categorical,levels]=model.categoricalInfo();
            for column=find(categorical)
                codes=x(:,column); count=numel(levels{column});
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
            extra={}; mask=model.categoricalMask();
            if any(mask), extra={'CategoricalPredictors',find(mask)}; end
            ensemble=fitrensemble(model.X,model.Y,'Method','Bag','NumLearningCycles',values.NumTrees,'Learners',template,extra{:});
            model.Ensemble=compact(ensemble); model.Trees=values.NumTrees; model.Hyperparameters=values;
            model.MinLeafSize=values.MinLeafSize; model.VariablesPerSplit=variables;
            if strcmp(model.Loss,'quantile')
                % 分位点回帰では、学習データの各行が木ごとにどの葉に入るかを覚えておく（予測の重みに使う）。
                leaves=zeros(model.NumObservations,values.NumTrees);
                for tree=1:values.NumTrees, [~,node]=predict(model.Ensemble.Trained{tree},model.X); leaves(:,tree)=node; end
                model.ForestLeaves=leaves;
            end
        end
    end
end
