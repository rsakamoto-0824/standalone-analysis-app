classdef TestFurnaceSave < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root=fileparts(fileparts(mfilename('fullpath'))); testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function allNumericModelsSaveWithoutRefittingAndPredictIdentically(testCase)
            slots=(5:20:185)'; y=100+.02*slots+.5*sin(slots/50);
            source=struct('Slots',slots,'Values',y,'TargetNames',{{'膜厚_nm'}},'Batch',repmat("Run-A",numel(slots),1),'WaferId',"W"+string(slots),'SourceRows',(2:numel(slots)+1)');
            report=interpolate_furnace_batches(source,(5:10:185)',{'spline','rbf','poly3'},struct());
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for k=1:numel(report.Series)
                item=report.Series{k}; file=fullfile(fixture.Folder,['model_' char(item.Method) '.mat']);
                verified=save_furnace_model(item,report.Options,file); loaded=load_furnace_model(file);
                testCase.verifyTrue(verified.Success); testCase.verifyEqual(loaded.Batch,"Run-A"); testCase.verifyEqual(loaded.Target,"膜厚_nm");
                testCase.verifyEqual(loaded.SourceRows,item.SourceRows); testCase.verifyEqual(loaded.Model,item.Model);
                probe=linspace(min(slots),max(slots),37)';
                testCase.verifyEqual(predict_furnace_model(loaded.Model,probe),predict_furnace_model(item.Model,probe));
                variables=whos('-file',file); testCase.verifyEqual({variables.name},{'Furnace_Model'});
            end
        end
        function selectedRunAndResponseKeepTheirOwnData(testCase)
            slots=(1:6)'; values=[100+slots,1.46+.001*slots];
            data=struct('Slots',[slots;slots],'Values',[values;values+[5,.01]],'TargetNames',{{'TH','RI'}}, ...
                'Batch',[repmat("A",6,1);repmat("B",6,1)],'WaferId',"W"+string((1:12)'),'SourceRows',(2:13)');
            report=interpolate_furnace_batches(data,slots,{'poly3'},struct()); item=report.Series{4};
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); file=fullfile(fixture.Folder,'selected.mat');
            save_furnace_model(item,report.Options,file); loaded=load_furnace_model(file);
            testCase.verifyEqual(loaded.Batch,"B"); testCase.verifyEqual(loaded.Target,"RI");
            testCase.verifyEqual(loaded.Actual,values(:,2)+.01); testCase.verifyEqual(loaded.SourceRows,(8:13)');
        end
        function otherMatFormatsAreRejected(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); file=fullfile(fixture.Folder,'other.mat');
            Other=1; save(file,'Other');
            testCase.verifyError(@()load_furnace_model(file),'furnace:modelVariable');
        end
    end
end
