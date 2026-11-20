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
    end
    properties (Constant)
        METHODS = {'linear', 'pls', 'forest', 'bagging', 'ebm', 'xgboost', 'lightgbm', 'catboost'}
        % Pro 版だけの方式。
        PRO_METHODS = {'ebm', 'xgboost', 'lightgbm', 'catboost'}
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
            if ~ismember(method,ProcessRegressionModel.METHODS), error('regression:method','重回帰・PLS・ランダムフォレスト・バギング木・EBM・XGBoost・LightGBM・CatBoost のどれかを指定してください。'); end
            if ismember(method,ProcessRegressionModel.PRO_METHODS), require_pro_feature('EBM・XGBoost・LightGBM・CatBoost'); end
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
            if ismember(method,ProcessRegressionModel.PRO_METHODS)
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
                    [~,~,~,~,beta]=plsregress(z,response,components); model.Components=components;
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
            if ~isempty(model.Booster)
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
            text=modeling_condition_label(struct('Kernel',model.Method,'Regressor',model.Method, ...
                'Components',model.Components,'Trees',model.Trees,'Parameters',model.Hyperparameters,'Search',[]));
        end
    end
    methods (Access = private)
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
