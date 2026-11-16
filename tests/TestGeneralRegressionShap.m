classdef TestGeneralRegressionShap < matlab.unittest.TestCase
    methods (TestClassSetup)
        function environment(testCase)
            root=fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths(); require_r2025b();
        end
    end
    methods (Test)
        function savedLinearAndPlsCanUseStandardShapleySwarmchart(testCase)
            assume_target_release(testCase);
            t=(1:18)'; x=[sin(t),cos(t/3)]; y=2+3*x(:,1)-4*x(:,2);
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            for method={'linear','pls'}
                model=ProcessRegressionModel(x,y,{'A','B'},method{1},2);
                path=fullfile(fixture.Folder,[method{1} '.mat']); save_regression_model(model,path); loaded=load_analysis_model(path);
                [object,values]=calc_shap_dependence(loaded,x(1:3,:));
                testCase.verifyClass(object,'shapley'); testCase.verifySize(values,[3,2]);
                window=uifigure('Visible','off'); cleanup=onCleanup(@()delete(window));
                ax=uiaxes(window); swarmchart(ax,object); testCase.verifyNotEmpty(findobj(ax,'Type','scatter'));
                clear cleanup;
            end
        end
    end
end
