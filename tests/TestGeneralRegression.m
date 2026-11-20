classdef TestGeneralRegression < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function ordinaryLeastSquaresRestoresOriginalUnits(testCase)
            t=(1:40)'; x=[1e6+t,1e-6*sin(t)]; y=3+.02*x(:,1)+4e5*x(:,2);
            model=ProcessRegressionModel(x,y,{'A','B'},'linear',2);
            testCase.verifyEqual(predict(model,x),y,'AbsTol',1e-9);
            testCase.verifyEqual(model.Coefficients,[.02;4e5],'RelTol',1e-8);
            testCase.verifyEqual(predict(model,array2table(x,'VariableNames',{'A','B'})),predict(model,x));
        end
        function fullComponentPlsMatchesLeastSquares(testCase)
            t=(1:40)'; x=[t,sin(t)]; y=2+3*x(:,1)-4*x(:,2)+.1*cos(t);
            linear=ProcessRegressionModel(x,y,{'A','B'},'linear',2);
            pls=ProcessRegressionModel(x,y,{'A','B'},'pls',2);
            testCase.verifyEqual(predict(pls,x),predict(linear,x),'AbsTol',1e-10);
            testCase.verifyEqual(pls.Components,2);
        end
        function plsAcceptsCollinearityAndConstantResponse(testCase)
            t=(1:20)'; x=[t,2*t,3*t]; y=3+4*t;
            pls=ProcessRegressionModel(x,y,{'A','B','C'},'pls',1);
            testCase.verifyEqual(predict(pls,x),y,'AbsTol',1e-10);
            constant=ProcessRegressionModel(x,1.46*ones(20,1),{'A','B','C'},'pls',1);
            testCase.verifyEqual(predict(constant,x),1.46*ones(20,1),'AbsTol',1e-12);
        end
        function modelRoundtripKeepsPredictionsNamesAndTargets(testCase)
            t=(1:24)'; x=[t,sin(t)]; y=2+t+.5*sin(t);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for method={'linear','pls'}
                model=ProcessRegressionModel(x,y,{'A','B'},method{1},2);
                path=fullfile(fixture.Folder,[method{1} '.mat']); report=save_regression_model(model,path);
                loaded=load_analysis_model(path); query=[2.5,.13;30,-.2];
                testCase.verifyTrue(report.Success); testCase.verifyEqual(predict(loaded,query),predict(model,query));
                testCase.verifyEqual(loaded.Y,y); testCase.verifyEqual(loaded.Method,method{1});
                variables=whos('-file',path); testCase.verifyEqual({variables.name},{'Regression_Model'});
            end
        end
        function validationFitsEachFoldWithoutHeldOutRows(testCase)
            t=(1:36)'; x=[t,sin(t)]; y=[2+t+.5*sin(t)+cos(t),4-t+.4*cos(t)];
            conditions=modeling_conditions({}, {'linear','pls'},'sr',1);
            services=struct('Trainer',@(a,b,c,callback)train_modeling_candidate('generic',a,b,{'A','B'},c,[],callback), ...
                'Predictor',@(model,a)predict(model,a),'Shap',@testShap);
            records=evaluate_modeling_batch(x,y,{'A','B'},{'Y1','Y2'},conditions,struct('Folds',3,'Seed',7,'Bins',0),services);
            for index=1:4
                record=records{index}; testCase.verifyEqual(record.Status,'成功',record.Note);
                target=ceil(index/2);
                for fold=1:3
                    held=record.FoldId==fold;
                    model=ProcessRegressionModel(x(~held,:),y(~held,target),{'A','B'},record.Condition.Regressor,1);
                    testCase.verifyEqual(record.Prediction(held),predict(model,x(held,:)),'AbsTol',1e-10);
                end
                testCase.verifyEqual(record.Model.Y,y(:,target));
            end
        end
        function comparisonUsesOnlyConfiguredGprFitMethod(testCase)
            c=modeling_conditions({'squaredexponential','matern52'},{'gpr','linear','pls'},'fic',2);
            testCase.verifyNumElements(c,4); testCase.verifyEqual({c(1:2).FitMethod},{'fic','fic'});
            testCase.verifyEqual({c(3:4).FitMethod},{'-','-'});
            testCase.verifyEqual(modeling_condition_label(c(4)),'PLS（2成分）');
        end
        function forestAndBaggingTrainSaveAndReload(testCase)
            rng(3); x=rand(60,3); y=sin(4*x(:,1))+x(:,2).^2+.05*randn(60,1);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            expected=struct('forest',{{1,'ランダムフォレスト（40本）'}},'bagging',{{3,'バギング木（40本）'}});
            for method={'forest','bagging'}
                model=ProcessRegressionModel(x,y,{'A','B','C'},method{1},2,40);
                testCase.verifyEqual(model.Trees,40); testCase.verifyEqual(model.MinLeafSize,5);
                testCase.verifyEqual(model.VariablesPerSplit,expected.(method{1}){1});
                testCase.verifyEqual(model.methodLabel(),expected.(method{1}){2});
                prediction=predict(model,x); testCase.verifyLessThan(sqrt(mean((prediction-y).^2)),std(y));
                testCase.verifyEqual(predict(model,array2table(x,'VariableNames',{'A','B','C'})),prediction);
                path=fullfile(fixture.Folder,[method{1} '.mat']); report=save_regression_model(model,path);
                testCase.verifyTrue(report.Success); loaded=load_analysis_model(path);
                testCase.verifyEqual(predict(loaded,x),prediction); testCase.verifyEqual(loaded.Method,method{1});
            end
            testCase.verifyError(@()ProcessRegressionModel(x,y,{'A','B','C'},'forest',2,5),'regression:trees');
        end
        function ensembleConditionsAreComparedInOneBatch(testCase)
            t=(1:40)'; x=[t,sin(t)]; y=2+.1*t+sin(t);
            conditions=modeling_conditions({}, {'forest','bagging'},'exact',2,20);
            testCase.verifyEqual({conditions.Regressor},{'forest','bagging'}); testCase.verifyEqual([conditions.Trees],[20,20]);
            services=struct('Trainer',@(a,b,c,callback)train_modeling_candidate('generic',a,b,{'A','B'},c,[],callback), ...
                'Predictor',@(model,a)predict(model,a),'Shap',@testShap);
            records=evaluate_modeling_batch(x,y,{'A','B'},{'Y1'},conditions,struct('Folds',4,'Seed',2,'Bins',0),services);
            for index=1:2
                testCase.verifyEqual(records{index}.Status,'成功',records{index}.Note);
                testCase.verifyEqual(records{index}.Model.Trees,20);
                testCase.verifyTrue(all(isfinite(records{index}.Prediction)));
            end
        end
        function invalidTrainingAndInputColumnsStop(testCase)
            x=[(1:8)',2*(1:8)']; y=(1:8)';
            testCase.verifyError(@()ProcessRegressionModel(x,y,{'A','B'},'linear',1),'regression:rank');
            testCase.verifyError(@()ProcessRegressionModel(x,y,{'A','B'},'pls',2),'regression:components');
            model=ProcessRegressionModel(x,y,{'A','B'},'pls',1);
            testCase.verifyError(@()predict(model,array2table(x,'VariableNames',{'B','A'})),'regression:columnNames');
            testCase.verifyError(@()predict(model,x(:,1)),'regression:columnCount');
        end
    end
end
function [object,values]=testShap(~,x)
object=[]; values=zeros(size(x));
end
