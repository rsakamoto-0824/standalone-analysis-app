classdef ProcessRegressionModel
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
    end
    methods
        function model=ProcessRegressionModel(x,y,names,method,components)
            if nargin==0, return; end
            if nargin<5, components=2; end
            validate_numeric_data(x,'説明変数',mfilename); validate_numeric_data(y,'目的変数',mfilename);
            names=cellstr(string(names(:)'));
            if ~isvector(y) || size(x,1)~=numel(y) || size(x,2)~=numel(names) || numel(unique(names))~=numel(names) || size(x,1)<2
                error('regression:shape','2行以上の説明変数・目的変数と、重複しない列名を指定してください。');
            end
            if ~ismember(method,{'linear','pls'}), error('regression:method','重回帰またはPLSを指定してください。'); end
            x=double(x); y=double(y(:)); center=mean(x,1); scale=std(x,0,1); scale(scale==0)=1;
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
            model.Method=method; model.KernelFunction=method; model.PredictorNames=names;
            model.X=x; model.Y=y; model.NumObservations=size(x,1); model.Coefficients=coefficients; model.Intercept=intercept;
        end
        function values=predict(model,x)
            if istable(x)
                if ~isequal(x.Properties.VariableNames,model.PredictorNames), error('regression:columnNames','保存モデルと同じ説明変数名・順序を指定してください。'); end
                x=table2array(x);
            end
            validate_numeric_data(x,'推定対象データ',mfilename);
            if size(x,2)~=numel(model.PredictorNames), error('regression:columnCount','モデルと同じ説明変数数を指定してください。'); end
            values=double(x)*model.Coefficients+model.Intercept;
            validate_numeric_data(values,'予測値',mfilename);
        end
    end
end
