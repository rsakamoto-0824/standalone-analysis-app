classdef TestProAnalysisFeatures < matlab.unittest.TestCase
    % Pro 版で追加した計算（ブースティング・EBM・ハイパーパラメータ探索・データの可視化・計画の評価指標）の確認。
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function boostingStylesLearnNonlinearFunction(testCase)
            [x,y]=TestProAnalysisFeatures.sample(200);
            for style={'xgboost','lightgbm','catboost'}
                model=GradientBoostedTrees(x(1:150,:),y(1:150),style{1},struct('NumRounds',150));
                rmse=sqrt(mean((model.predict(x(151:end,:))-y(151:end)).^2));
                testCase.verifyLessThan(rmse,0.5*std(y),style{1});
                testCase.verifyLessThan(model.TrainingRMSE(end),model.TrainingRMSE(1),style{1});
            end
        end
        function boostingIsReproducibleWithSampling(testCase)
            [x,y]=TestProAnalysisFeatures.sample(80);
            options=struct('NumRounds',30,'Subsample',0.7,'ColsampleByTree',0.67,'Seed',3);
            first=GradientBoostedTrees(x,y,'xgboost',options); second=GradientBoostedTrees(x,y,'xgboost',options);
            testCase.verifyEqual(first.predict(x),second.predict(x));
        end
        function symmetricTreeHasPowerOfTwoLeaves(testCase)
            [x,y]=TestProAnalysisFeatures.sample(60);
            model=GradientBoostedTrees(x,y,'catboost',struct('NumRounds',10,'Depth',3));
            testCase.verifyEqual(numel(model.Trees{1}.Value),2^size(model.Trees{1}.Levels,1));
        end
        function ebmRecoversAdditiveShapesAndInteraction(testCase)
            rng(2); x=rand(300,3)*2-1; y=x(:,1).^2+sin(2*x(:,2))+3*x(:,1).*x(:,3);
            additive=ExplainableBoostingModel(x,y,struct('Interactions',0));
            with_pair=ExplainableBoostingModel(x,y,struct('Interactions',1));
            testCase.verifyEmpty(additive.Pairs);
            testCase.verifyEqual(with_pair.Pairs,[1,3]);
            testCase.verifyLessThan(with_pair.TrainingRMSE,additive.TrainingRMSE);
            [positions,values]=with_pair.shape(2);
            testCase.verifyEqual(numel(positions),numel(values));
            testCase.verifyGreaterThan(corr(interp1(positions,values,[-0.8;0;0.8],'previous'),sin(2*[-0.8;0;0.8])),0.9);
        end
        function regressionModelWrapsProMethodsAndRoundtrips(testCase)
            [x,y]=TestProAnalysisFeatures.sample(60); fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for method={'ebm','xgboost','lightgbm','catboost'}
                model=ProcessRegressionModel(x,y,{'A','B','C'},method{1},2,[],struct('Seed',1));
                path=fullfile(fixture.Folder,[method{1} '.mat']); report=save_regression_model(model,path);
                loaded=load_analysis_model(path);
                testCase.verifyTrue(report.Success,method{1});
                testCase.verifyEqual(predict(loaded,x(1:5,:)),predict(model,x(1:5,:)),method{1});
                testCase.verifyEqual(loaded.Hyperparameters.Seed,1);
            end
        end
        function forestUsesTunedLeafSizeAndVariableFraction(testCase)
            [x,y]=TestProAnalysisFeatures.sample(60);
            model=ProcessRegressionModel(x,y,{'A','B','C'},'forest',2,[],struct('NumTrees',30,'MinLeafSize',2,'VariableFraction',1));
            testCase.verifyEqual([model.Trees,model.MinLeafSize,model.VariablesPerSplit],[30,2,3]);
            testCase.verifyEqual(model.methodLabel(),'ランダムフォレスト（30本）');
        end
        function hyperparameterValuesRejectWrongNamesAndRanges(testCase)
            testCase.verifyError(@()hyperparameter_values('xgboost',struct('Depth',3)),'hyperparameter:name');
            testCase.verifyError(@()hyperparameter_values('xgboost',struct('MaxDepth',2.5)),'hyperparameter:value');
            testCase.verifyError(@()hyperparameter_values('lightgbm',struct('LearningRate',0)),'hyperparameter:value');
            values=hyperparameter_values('catboost',struct('Depth',5));
            testCase.verifyEqual([values.Depth,values.NumRounds],[5,200]);
        end
        function gridAndRandomSearchKeepBestAndTrace(testCase)
            [x,y]=TestProAnalysisFeatures.sample(90); base=hyperparameter_values('xgboost',struct('NumRounds',40));
            grid=struct('Mode','grid','Trials',0,'Folds',3,'Seed',0,'Candidates',struct('MaxDepth',[1,3],'LearningRate',[0.1,0.3]));
            [best,trace,searched]=search_hyperparameters(x,y,{'A','B','C'},'xgboost',2,base,grid);
            testCase.verifyEqual(height(trace),4); testCase.verifyEqual({searched.Name},{'MaxDepth','LearningRate'});
            [~,winner]=min(trace.CV_RMSE);
            testCase.verifyEqual([best.MaxDepth,best.LearningRate],[trace.("木の深さ")(winner),trace.("学習率 η")(winner)]);
            testCase.verifyEqual(trace.("それまでの最良RMSE"),cummin(trace.CV_RMSE),'AbsTol',1e-12);
            random=grid; random.Mode='random'; random.Trials=3;
            [~,again]=search_hyperparameters(x,y,{'A','B','C'},'xgboost',2,base,random);
            [~,repeat]=search_hyperparameters(x,y,{'A','B','C'},'xgboost',2,base,random);
            testCase.verifyEqual(height(again),3); testCase.verifyEqual(again.CV_RMSE,repeat.CV_RMSE);
            too_many=grid; too_many.Candidates=struct('MaxDepth',1:10,'LearningRate',linspace(0.01,1,21));
            testCase.verifyError(@()search_hyperparameters(x,y,{'A','B','C'},'xgboost',2,base,too_many),'search:tooMany');
        end
        function conditionsCarryParametersSearchAndLabels(testCase)
            search=struct('Mode','random','Trials',4,'Folds',3,'Seed',0,'Candidates',struct('lightgbm',struct('NumLeaves',[7,15])));
            conditions=modeling_conditions({'matern52'},{'gpr','lightgbm','xgboost','forest'},'exact',2,40, ...
                struct('xgboost',struct('MaxDepth',3)),search);
            labels=arrayfun(@(index) modeling_condition_label(conditions(index)),1:numel(conditions),'UniformOutput',false);
            testCase.verifyEqual(labels,{'matern52','LightGBM（ランダムサーチ）','XGBoost（200回・深さ3）','ランダムフォレスト（40本）'});
            testCase.verifyEmpty(conditions(3).Search); testCase.verifyEqual(conditions(2).Search.Candidates.NumLeaves,[7,15]);
            [model,~,details]=train_modeling_candidate('generic',rand(40,2),rand(40,1),{'A','B'},conditions(2),[],[]);
            testCase.verifyTrue(ismember(model.Hyperparameters.NumLeaves,[7,15]));
            testCase.verifyEqual(height(details.SearchTrace),2);
        end
        function dataColumnsAndCategoryGroups(testCase)
            data=struct('Headers',{{'Value','Lot'}},'Cells',{{1,'A';2,'B';[],'A';4,missing;5,'B';6,'C'}});
            value=data_column(data,'Value'); lot=data_column(data,'Lot');
            testCase.verifyTrue(value.IsNumeric); testCase.verifyFalse(lot.IsNumeric);
            testCase.verifyEqual(value.Missing',[false,false,true,false,false,false]);
            [groups,names]=category_groups(lot);
            testCase.verifyEqual(names,["A";"B";"C";"(欠損)"]); testCase.verifyEqual(groups',[1,2,1,4,2,3]);
            [groups,names]=category_groups(struct('Labels',string(1:12)','Missing',false(12,1),'IsNumeric',true,'Numbers',(1:12)'),3);
            testCase.verifyEqual(numel(names),3); testCase.verifyEqual(accumarray(groups,1)',[4,4,4]);
        end
        function flowLayoutsKeepCountsAndStacking(testCase)
            groups=[1,1;1,2;2,2;2,2;1,1];
            for style={'sets','sankey'}
                layout=category_flow_layout(groups,[2,2],style{1});
                for column=1:2
                    ribbons=layout.Ribbons(layout.Ribbons.Column==1,:); side={'FromLevel','ToLevel'};
                    totals=accumarray(ribbons.(side{column}),ribbons.Count,[2,1]);
                    testCase.verifyEqual(totals,layout.Nodes.Count(layout.Nodes.Column==column),style{1});
                end
                testCase.verifyLessThanOrEqual(max(layout.Nodes.Top),1+1e-12);
                testCase.verifyEqual(layout.Ribbons.LeftTop-layout.Ribbons.LeftBottom,layout.Ribbons.RightTop-layout.Ribbons.RightBottom,'AbsTol',1e-12);
            end
        end
        function anovaPcaAndClusters(testCase)
            rng(4); response=[randn(20,1);randn(20,1)+3]; factor={[repmat("a",20,1);repmat("b",20,1)]};
            result=calc_anova_summary(response,factor,{'F'});
            testCase.verifyLessThan(result.Table.("p値")(1),1e-6);
            testCase.verifyEqual(result.Table.("寄与率")(1)+result.Table.("寄与率")(2),1,'AbsTol',1e-10);
            values=[randn(30,2);randn(30,2)+6]; values(:,3)=2*values(:,1);
            pca_result=calc_pca_summary(values,{'A','B','C'});
            testCase.verifyEqual(sum(pca_result.Explained),100,'AbsTol',1e-8);
            for method={'kmeans','ward'}
                clusters=calc_cluster_summary(values(:,1:2),{'A','B'},method{1},2,0);
                testCase.verifyEqual(sort(clusters.Centers.("件数"))',[30,30],method{1});
                testCase.verifyGreaterThan(clusters.Silhouette,0.7,method{1});
            end
        end
        function designMetricsMatchKnownDesigns(testCase)
            full=[-1,-1;1,-1;-1,1;1,1];
            metrics=design_metrics(full,'interaction');
            testCase.verifyEqual(metrics.Values.DEfficiency,100,'AbsTol',1e-9);
            testCase.verifyEqual(metrics.Values.AEfficiency,100,'AbsTol',1e-9);
            testCase.verifyEqual(metrics.Values.MaxVIF,1,'AbsTol',1e-12);
            % 2^2 計画・交互作用モデルの平均予測分散は (1 + 1/3 + 1/3 + 1/9)/4。
            testCase.verifyEqual(metrics.Values.ICriterion,(1+2/3+1/9)/4,'AbsTol',1e-12);
            testCase.verifyEqual(metrics.Values.GEfficiency,100,'AbsTol',1e-9);
            deficient=design_metrics([-1,-1;1,1;0,0],'interaction');
            testCase.verifyTrue(isnan(deficient.Values.DEfficiency)); testCase.verifyEmpty(deficient.Variance);
        end
    end
    methods (Static)
        function [x,y]=sample(rows)
            rng(1); x=[rand(rows,2)*2-1,rand(rows,1)];
            y=2*x(:,1)+x(:,2).^2+sin(pi*x(:,3))+x(:,1).*x(:,2)+0.05*randn(rows,1);
        end
    end
end
