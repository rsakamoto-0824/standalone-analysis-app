classdef TestSampleWorkbook < matlab.unittest.TestCase
    properties
        File
    end
    methods (TestMethodSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
            testCase.File=fullfile(root,'samples','ProcessInsight_Samples.xlsx');
        end
    end
    methods (Test)
        function apcAndPredictionHaveMatchingInputsAndMultipleTargets(testCase)
            names={'SIN_TH','SIN_RN','NSG_TH','RESIST_TH'};
            for item={'APC','Predict_SHAP'}
                source=read_input_data(testCase.File,item{1},1);
                x=extract_numeric_columns(source,names); y=extract_numeric_columns(source,{'CD_X','CD_Y'});
                testCase.verifySize(x,[size(y,1),4]); testCase.verifyTrue(all(isfinite(y),'all'));
            end
        end
        function swingModesAndGenericCanBeMapped(testCase)
            source=read_input_data(testCase.File,'Swing_NoBase',1);
            [x,y]=modeling_input_data(source,{1,'RESIST_TH','RESIST_TH'},{'CD_X','CD_Y'});
            testCase.verifySize(x,[80,1]); testCase.verifySize(y,[80,2]);
            source=read_input_data(testCase.File,'Swing_Base',1); testCase.verifySize(extract_numeric_columns(source,{'SIN_TH','SIN_RN','NSG_TH','RESIST_TH'}),[80,4]);
            source=read_input_data(testCase.File,'Generic',1); testCase.verifySize(extract_numeric_columns(source,{'X1','X2','X3','Y1','Y2'}),[80,5]);
        end
        function furnaceHasTwoRunsAndValidSparseMeasurements(testCase)
            source=read_furnace_data(testCase.File,'Furnace',1);
            data=prepare_furnace_data(source,'WaferId','BoatSlot',{'膜厚_nm','屈折率'},'Batch');
            testCase.verifyEqual(numel(unique(data.Batch)),2);
            testCase.verifyEqual(sum(isfinite(data.Values),1),[20,20]);
            report=interpolate_furnace_batches(data,(5:10:195)',{'spline','poly3','rbf'},struct());
            testCase.verifyTrue(all(report.Comparison.Status=="成功"));
            testCase.verifyEqual(height(report.Comparison),12);
        end
        function codedExistingDesignAndWordCloudAreUsable(testCase)
            source=read_input_data(testCase.File,'DOE_Existing',1); design=extract_numeric_columns(source,{'F1','F2','F3'});
            testCase.verifySize(design,[10,3]); testCase.verifyTrue(all(abs(design)<=1,'all'));
            source=read_input_data(testCase.File,'WordCloud',1); [words,counts]=create_wordCloud(source.Cells{1,1});
            testCase.verifyGreaterThan(sum(counts),5); testCase.verifyTrue(any(strcmp(words,'成膜')));
        end
    end
end
