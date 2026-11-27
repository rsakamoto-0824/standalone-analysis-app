classdef TestRegressionOptions < matlab.unittest.TestCase
    % 汎用回帰の損失関数（分位点回帰）・質的変数（GPR 以外の方式）・CatBoost の並べ替えの確認。
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function quantileStandardMethodsCoverHeldOutData(testCase)
            % y = 2x + 誤差（標準偏差1）。τ = 0.9 の分位点回帰では、学習に使っていない行の約9割が予測以下になる。
            [x,y]=TestRegressionOptions.linearData(1,1200); train=1:800; test=801:1200;
            for method={'linear','pls','forest','bagging'}
                model=ProcessRegressionModel(x(train,:),y(train),{'a','b'},method{1},2,100,struct(),struct('Loss','quantile','Quantile',0.9));
                coverage=mean(y(test)<=predict(model,x(test,:)));
                testCase.verifyEqual(coverage,0.9,'AbsTol',0.06,method{1});
                testCase.verifyTrue(contains(model.methodLabel(),'分位点τ=0.9'),method{1});
            end
            % 重回帰の係数は、分位点が変わっても傾きはほぼ同じで、切片が誤差の分位点だけずれる。
            low=ProcessRegressionModel(x,y,{'a','b'},'linear',2,[],struct(),struct('Loss','quantile','Quantile',0.1));
            high=ProcessRegressionModel(x,y,{'a','b'},'linear',2,[],struct(),struct('Loss','quantile','Quantile',0.9));
            testCase.verifyEqual(high.Coefficients,low.Coefficients,'AbsTol',0.25);
            testCase.verifyEqual(high.Intercept-low.Intercept,2*norminv(0.9),'AbsTol',0.3);
            testCase.verifyError(@()ProcessRegressionModel(x,y,{'a','b'},'linear',2,[],struct(),struct('Loss','quantile','Quantile',1)),'regression:quantile');
            testCase.verifyError(@()ProcessRegressionModel(x,y,{'a','b'},'linear',2,[],struct(),struct('Loss','absolute')),'regression:loss');
        end
        function rankingComparesSameLossOnly(testCase)
            % 平均のモデルは RMSE、分位点のモデルは同じ τ どうしでピンボール損失の順位。まとまりごとに1位がある。
            actual=(1:10)'; plain=struct('Loss',[]); q9=struct('Loss',struct('Type','quantile','Quantile',0.9));
            make=@(condition,prediction) struct('Run',1,'Target','y','Condition',condition,'Model',1, ...
                'Metrics',table([0;sqrt(mean((actual-prediction).^2))],'VariableNames',{'Value'}),'Actual',actual,'Prediction',prediction);
            records={make(plain,actual+1),make(plain,actual),make(q9,actual+3),make(q9,actual+0.5),struct('Run',1,'Target','y','Condition',q9,'Model',[], ...
                'Metrics',table(),'Actual',actual,'Prediction',[])};
            [ranks,scores,groups]=model_rank_scores(records);
            testCase.verifyEqual(ranks(1:4)',[2,1,2,1]); testCase.verifyTrue(isnan(ranks(5)));
            testCase.verifyEqual(groups(1),"1/y/平均"); testCase.verifyEqual(groups(3),"1/y/分位点τ=0.9");
            testCase.verifyEqual(scores(4),ProcessRegressionModel.pinballLoss(actual,actual+0.5,0.9),'AbsTol',1e-12);
        end
        function pinballLossAndLabels(testCase)
            testCase.verifyEqual(ProcessRegressionModel.pinballLoss([1;2;3],[2;2;2],0.9),(0.1*1+0+0.9*1)/3,'AbsTol',1e-12);
            loss=struct('Type','quantile','Quantile',0.25);
            conditions=modeling_conditions({'matern52'},{'gpr','linear','pls'},'exact',2,100,struct(),[],[],struct('Loss',loss));
            testCase.verifyEmpty(conditions(1).Loss);  % GPR は損失関数を持たない
            testCase.verifyEqual(conditions(2).Loss,loss);
            testCase.verifyEqual(modeling_condition_label(conditions(2)),'重回帰（分位点τ=0.25）');
            testCase.verifyEqual(modeling_condition_label(conditions(3)),'PLS（2成分・分位点τ=0.25）');
            testCase.verifyEqual(modeling_condition_label(conditions(1)),'matern52');
            plain=modeling_conditions({},{'linear','pls'},'sr',1);
            testCase.verifyEqual(modeling_condition_label(plain(1)),'重回帰'); testCase.verifyEqual(modeling_condition_label(plain(2)),'PLS（1成分）');
        end
    end
    methods (Test, TestTags = {'Pro'})
        function categoricalWorksForEveryMethod(testCase)
            % y = 3x + 水準の効果（A:0, B:2, C:−1）+ 誤差。x = 0.5 での水準ごとの予測は 1.5, 3.5, 0.5 に近い。
            rng(2); n=600; x=rand(n,1); g=randi(3,n,1); effect=[0;2;-1]; y=3*x+effect(g)+0.3*randn(n,1);
            options=struct('Categorical',[false,true],'Levels',{{[],["A";"B";"C"]}});
            for method={'linear','pls','forest','bagging','ebm','xgboost','lightgbm','catboost'}
                model=ProcessRegressionModel([x,g],y,{'x','g'},method{1},2,100,struct(),options);
                testCase.verifyEqual(predict(model,[0.5,1;0.5,2;0.5,3])',[1.5,3.5,0.5],'AbsTol',0.45,method{1});
                [mask,levels]=model.categoricalInfo(); testCase.verifyEqual(mask,[false,true],method{1}); testCase.verifyEqual(levels{2},["A";"B";"C"],method{1});
                testCase.verifyError(@()predict(model,[0.5,4]),'regression:categoricalCodes');
            end
            % 重回帰はダミー変数（B・C の2列）を使う。PLS の VIP は元の説明変数ごとに1つ。
            linear=ProcessRegressionModel([x,g],y,{'x','g'},'linear',2,[],struct(),options);
            testCase.verifyNumElements(linear.Coefficients,3);
            pls=ProcessRegressionModel([x,g],y,{'x','g'},'pls',2,[],struct(),options); testCase.verifyNumElements(pls.Vip,2);
            % EBM の質的変数の形は、水準ごとの効果（平均0にそろえたもの）。
            ebm=ProcessRegressionModel([x,g],y,{'x','g'},'ebm',2,[],struct(),options);
            [positions,values]=ebm.Booster.shape(2); testCase.verifyEqual(positions,1:3);
            testCase.verifyEqual(values-values(1),[0,2,-1],'AbsTol',0.3);
        end
        function linearHandlesLevelsMissingFromTraining(testCase)
            % 学習の行にない水準（交差検証で行の少ない水準が抜けたときなど）があっても重回帰を学習できる。
            % その水準のダミー変数の係数は0（予測は基準の水準と同じ）。基準の水準（1番目）がないときは、ある最初の水準を基準にする。
            rng(9); n=80; x=rand(n,1); levels={[],["A";"B";"C";"D"]}; effect=[0;2;-1;5];
            for missing=[4,1]
                g=randi(4,n,1); g(g==missing)=mod(missing,4)+1; y=x+effect(g)+0.05*randn(n,1);
                for loss={'squared','quantile'}
                    model=ProcessRegressionModel([x,g],y,{'x','g'},'linear',2,[],struct(),struct('Categorical',[false,true],'Levels',{levels},'Loss',loss{1},'Quantile',0.5));
                    present=setdiff(1:4,missing); predicted=predict(model,[0.5*ones(3,1),present']);
                    testCase.verifyEqual(predicted',0.5+effect(present)','AbsTol',0.1,sprintf('水準%dなし・%s',missing,loss{1}));
                end
            end
        end
        function quantileBoostingCoversHeldOutData(testCase)
            % 分位点の葉の値は葉に入った行の残差の分位点のため、葉が小さい・回数が多いと学習データに合わせすぎ、
            % 学習に使っていない行で割合が τ からずれる（学習データでは τ どおりになる）。
            % XGBoost・LightGBM 方式は葉の最小行数を20（LightGBM の既定と同じ）、ブースティングの回数は50にする。
            [x,y]=TestRegressionOptions.linearData(3,1200); train=1:800; test=801:1200;
            parameters=struct('ebm',struct(),'xgboost',struct('MinChildWeight',20,'NumRounds',50), ...
                'lightgbm',struct('MinDataInLeaf',20,'NumRounds',50),'catboost',struct('NumRounds',50));
            for method={'ebm','xgboost','lightgbm','catboost'}
                model=ProcessRegressionModel(x(train,:),y(train),{'a','b'},method{1},2,[],parameters.(method{1}),struct('Loss','quantile','Quantile',0.2));
                testCase.verifyEqual(mean(y(train)<=predict(model,x(train,:))),0.2,'AbsTol',0.02,method{1});
                testCase.verifyEqual(mean(y(test)<=predict(model,x(test,:))),0.2,'AbsTol',0.07,method{1});
            end
        end
        function catBoostOrderedTargetStatisticsFollowOrder(testCase)
            % Ordered TS：並べた順で前の行だけの目的変数の平均（事前値で補う）。先頭の行は事前値（平均）になる。
            % 水準1は行1・2・4、水準2は行3・5。行2 → 行4 → 行1 → 行5 → 行3 の順に並べる。
            x=[1;1;2;1;2]; y=[10;20;30;40;50]; order=[3;1;5;2;4];
            [encoded,stats]=GradientBoostedTrees.orderedTargetStats(x,y,true,2,[2;4;1;5;3]);
            prior=mean(y);
            testCase.verifyEqual(encoded(2),prior);                          % 水準1の最初
            testCase.verifyEqual(encoded(4),(20+prior)/2,'AbsTol',1e-12);     % 前は行2だけ
            testCase.verifyEqual(encoded(1),(20+40+prior)/3,'AbsTol',1e-12);  % 前は行2・4
            testCase.verifyEqual(encoded(5),prior);                          % 水準2の最初
            testCase.verifyEqual(encoded(3),(50+prior)/2,'AbsTol',1e-12);
            testCase.verifyEqual(stats.Sums{1}',[70,80]); testCase.verifyEqual(stats.Counts{1}',[3,2]);
            testCase.verifyEqual(GradientBoostedTrees.applyTargetStats([2;3],stats),[(80+prior)/3;prior],'AbsTol',1e-12);
            % 並べ替えの値は小さい順。同じ値は乱数の順（Seed で決まる）。
            testCase.verifyEqual(GradientBoostedTrees.rowOrder(order,5,0),[2;4;1;5;3]);
            % 同じ並べ替えなら同じモデル、並べ替えを変えると質的変数の置き換えが変わる。
            rng(4); n=200; g=randi(4,n,1); v=rand(n,1); target=g+v+0.2*randn(n,1);
            options=struct('Categorical',[true,false],'Levels',{{"L"+(1:4)',[]}},'Order',(1:n)');
            first=ProcessRegressionModel([g,v],target,{'g','v'},'catboost',2,[],struct('NumRounds',30,'OrderedBoosting',1),options);
            again=ProcessRegressionModel([g,v],target,{'g','v'},'catboost',2,[],struct('NumRounds',30,'OrderedBoosting',1),options);
            testCase.verifyEqual(predict(first,[g,v]),predict(again,[g,v]));
            options.Order=(n:-1:1)';
            other=ProcessRegressionModel([g,v],target,{'g','v'},'catboost',2,[],struct('NumRounds',30,'OrderedBoosting',1),options);
            testCase.verifyNotEqual(predict(other,[g,v]),predict(first,[g,v]));
            testCase.verifyLessThan(sqrt(mean((target-predict(first,[g,v])).^2)),0.45);
            options.Order=(1:n-1)';
            testCase.verifyError(@()ProcessRegressionModel([g,v],target,{'g','v'},'catboost',2,[],struct(),options),'regression:order');
        end
        function orderColumnValuesAndCrossValidationRows(testCase)
            data=struct('Headers',{{'日時','X'}},'Cells',{{'2024/01/03',1;'2024/01/01',2;'2024/01/02',3}},'RowNumbers',(2:4)');
            testCase.verifyEqual(order_column_values(data,'日時'),[3;1;2]);
            testCase.verifyEqual(order_column_values(data,'X'),[1;2;3]);
            data.Cells{2,1}=missing; testCase.verifyError(@()order_column_values(data,'日時'),'order_column_values:missing');
            data.Cells(:,1)={1;Inf;2}; testCase.verifyError(@()order_column_values(data,'日時'),'order_column_values:nonFinite');
            % 交差検証では、学習に使う行の分だけの並べ替えの値を学習へ渡す。
            rng(5); n=60; x=rand(n,1); y=2*x+0.1*randn(n,1); seen={};
            conditions=modeling_conditions({},{'catboost'},'exact',2,100,struct('catboost',struct('NumRounds',10)),[],[],struct('Order',(1:n)'));
            services=struct('Trainer',@trainer,'Predictor',@(model,inputs) predict(model,inputs),'Shap',[]);
            evaluate_modeling_batch(x,y,{'x'},{'y'},conditions,struct('Folds',3,'Seed',1,'Bins',0,'ComputeShap',false),services);
            testCase.verifyEqual(cellfun(@numel,seen),[40,40,40,60]);
            function [model,warnings,details]=trainer(inputs,response,condition,~)
                seen{end+1}=condition.Order; testCase.verifyEqual(numel(condition.Order),size(inputs,1));
                [model,warnings,details]=train_modeling_candidate('generic',inputs,response,{'x'},condition,[],[]);
            end
        end
        function quantileSearchUsesPinballLoss(testCase)
            [x,y]=TestRegressionOptions.linearData(6,240);
            search=struct('Mode','grid','Trials',3,'Folds',3,'Seed',0,'Candidates',struct('MaxDepth',[1,3]));
            [~,trace]=search_hyperparameters(x,y,{'a','b'},'xgboost',2,struct('NumRounds',30),search,[],struct('Loss','quantile','Quantile',0.9));
            testCase.verifyTrue(all(ismember({'CV_ピンボール損失','それまでの最良ピンボール損失'},trace.Properties.VariableNames)));
            [~,best]=min(trace.("CV_ピンボール損失")); testCase.verifyTrue(trace.("採用")(best));
        end
    end
    methods (Static)
        function [x,y]=linearData(seed,n)
            rng(seed); x=[rand(n,1)*4, rand(n,1)]; y=2*x(:,1)+randn(n,1);
        end
    end
end
