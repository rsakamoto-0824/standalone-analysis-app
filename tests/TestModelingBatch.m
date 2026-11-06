classdef TestModelingBatch < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function multipleResponsesRetainIndependentModelsAndShap(testCase)
            [x,y,names,targets,c,o,s]=fixture(); records=evaluate_modeling_batch(x,y,names,targets,c,o,s);
            testCase.verifyNumElements(records,4);
            testCase.verifyEqual(records{1}.Target,'Y1'); testCase.verifyEqual(records{3}.Target,'Y2');
            testCase.verifyNotEqual(records{1}.Model.Coefficients,records{3}.Model.Coefficients);
            for k=1:4, testCase.verifyEqual(records{k}.Status,'成功'); testCase.verifyEqual(records{k}.ShapStatus,'成功'); testCase.verifySize(records{k}.Shap.Values,[30,1]); end
        end
        function commonValidationExcludesEveryHeldOutRow(testCase)
            [x,y,names,targets,c,o,s]=fixture(); o.Folds=3;
            records=evaluate_modeling_batch(x,y,names,targets,c,o,s);
            for k=1:4, testCase.verifyEqual(records{k}.Status,'成功',records{k}.Note); testCase.verifyEqual(records{k}.Metrics.Value(2),0,'AbsTol',1e-10); end
            testCase.verifyEqual(records{1}.Scope,'3分割交差検証');
        end
        function shapFailureKeepsModelAndOtherTargets(testCase)
            [x,y,names,targets,c,o,s]=fixture(); c(1).Kernel='shap_fail';
            records=evaluate_modeling_batch(x,y,names,targets,c,o,s);
            testCase.verifyEqual(records{1}.Status,'成功'); testCase.verifyEqual(records{1}.ShapStatus,'失敗');
            testCase.verifyNotEmpty(records{1}.Model); testCase.verifyEqual(records{4}.ShapStatus,'成功');
        end
        function trainingFailureDoesNotEraseSuccessfulCandidates(testCase)
            [x,y,names,targets,c,o,s]=fixture(); c(1).Kernel='train_fail';
            records=evaluate_modeling_batch(x,y,names,targets,c,o,s);
            testCase.verifyEqual(records{1}.Status,'失敗'); testCase.verifyEmpty(records{1}.Model); testCase.verifyEqual(records{4}.Status,'成功');
        end
        function cancellationPropagatesBeforeResultsAreRegistered(testCase)
            [x,y,names,targets,c,o,s]=fixture();
            testCase.verifyError(@()evaluate_modeling_batch(x,y,names,targets,c,o,s,@cancel),'AnalysisApp:cancelled');
        end
        function responseLeakageAndDuplicateInputsStop(testCase)
            source=struct('Headers',{{'TH','CD','CD2'}},'Cells',{num2cell([(1:10)',(2:11)',(3:12)'])});
            mapping={1,'RESIST_TH','TH'};
            [x,y]=modeling_input_data(source,mapping,{'CD','CD2'}); testCase.verifySize(x,[10,1]); testCase.verifySize(y,[10,2]);
            testCase.verifyError(@()modeling_input_data(source,mapping,{'TH'}),'modeling:responseLeak');
            testCase.verifyError(@()modeling_input_data(source,[mapping;mapping],{'CD'}),'modeling:predictors');
        end
        function settingsUse25RunsAndMigrateRbfDefaults(testCase)
            d=app_settings('defaults'); testCase.verifyEqual(d.Runs,25); testCase.verifyEqual(d.RBFWidth,0); testCase.verifyEqual(d.RBFRidge,1e-8);
            folder=tempname; mkdir(folder); cleanup=onCleanup(@()rmdir(folder,'s'));
            old=rmfield(d,{'RBFWidth','RBFRidge'}); old.SaveFolder=folder;
            written=app_settings('save',fullfile(folder,'settings.json'),old);
            testCase.verifyEqual(written.RBFWidth,0); testCase.verifyEqual(written.RBFRidge,1e-8);
        end
        function allTwoThroughFiveLevelArraysHaveBalancedPairs(testCase)
            for q=2:5
                [array,~]=create_experiment_design('orthogonal',8,25,42,'linear',q);
                digits=round((array+1)*(q-1)/2)+1;
                testCase.verifyTrue(all(digits(:)>=1 & digits(:)<=q));
                for a=1:7
                    for b=a+1:8
                        counts=accumarray(digits(:,[a,b]),1,[q,q]);
                        testCase.verifyEqual(counts,repmat(size(array,1)/q^2,q,q));
                    end
                end
            end
        end
        function optimalDesignsUseChosenGridAndKeepExistingPoints(testCase)
            existing=[-1,-1;0,0;1,1];
            for q=[4,5]
                [array,~]=create_experiment_design('D',2,10,42,'quadratic',q,existing);
                testCase.verifyEqual(array(1:3,:),existing);
                testCase.verifyTrue(all(ismember(array(4:end,:),linspace(-1,1,q)),'all'));
            end
        end
    end
end

function [x,y,names,targets,c,o,s]=fixture()
x=(1:30)'; y=[2*x+3,5*x-2]; names={'RESIST_TH'}; targets={'Y1','Y2'};
c=struct('Kernel',{'one','two'},'FitMethod',{'exact','exact'}); o=struct('Folds',0,'Seed',0,'Bins',0);
s=struct('Trainer',@train,'Predictor',@prediction,'Shap',@shap);
end
function [model,warnings,details]=train(x,y,c,~)
if strcmp(c.Kernel,'train_fail'), error('test:train','合成学習失敗'); end
model=struct('Coefficients',[ones(size(x,1),1),x]\y,'X',x,'Rows',size(x,1),'FailShap',strcmp(c.Kernel,'shap_fail'));
warnings=[]; details=[];
end
function values=prediction(model,x)
if model.Rows<30 && any(ismember(x,model.X,'rows')), error('test:leak','検証行が学習に混入しました。'); end
values=[ones(size(x,1),1),x]*model.Coefficients;
end
function [object,values]=shap(model,x)
if model.FailShap, error('test:shap','合成SHAP失敗'); end
object=[]; values=x*model.Coefficients(2);
end
function cancel(~), error('AnalysisApp:cancelled','中止'); end
