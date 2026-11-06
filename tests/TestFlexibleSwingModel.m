classdef TestFlexibleSwingModel < matlab.unittest.TestCase
    methods (TestClassSetup)
        function environment(testCase)
            setup_paths(); require_r2025b();
        end
    end
    methods (Test)
        function singlePredictorSavesAndPredicts(testCase)
            x = linspace(800, 1250, 30)'; y = 2*sin(2*pi*x/140)+0.01*x;
            [model, ~] = train_swing_gpr_model(x,y,{'RESIST_TH'},'squaredexponential','exact');
            testCase.verifyEqual(model.PredictorNames, {'RESIST_TH'});
            [explainer, values] = calc_shap_dependence(model,x(1:8));
            testCase.verifySize(values,[8,1]);
            [resist, ~, noise_values] = denoise_for_swing_curve(model,zeros(8,0),x(1:8));
            testCase.verifySize(resist,[8,1]); testCase.verifyEqual(resist,noise_values(:,end));
            window=uifigure('Visible','off'); cleanup=onCleanup(@() delete(window));
            ax=uiaxes(window); swarmchart(ax,explainer);
            testCase.verifyNotEmpty(findobj(ax,'Type','scatter'));
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(fixture.Folder,default_model_filename('swing')); save_train_model(model,file);
            check = verify_saved_model(file,model,'swing'); testCase.verifyTrue(check.Success);
        end
        function singlePredictorPeriodicAndComparison(testCase)
            x = linspace(800,1250,24)'; y = sin(2*pi*x/140)+0.001*x;
            options = swing_period_options(248,1.77,[135,145]);
            [model, ~, details] = train_swing_gpr_model(x,y,{'RESIST_TH'},'swingperiodic','exact',[],options);
            testCase.verifyGreaterThanOrEqual(details.Period,135); testCase.verifyLessThanOrEqual(details.Period,145);
            testCase.verifyEqual(numel(model.KernelInformation.KernelParameters),4);
            context=struct('PredictorNames',{{'RESIST_TH'}},'PeriodOptions',options);
            report=compare_gpr_kernels('swing',x,y,{'matern32','squaredexponential'},'exact',3,0,0,[],context);
            testCase.verifyTrue(all(report.Summary.Status=="成功"));
        end
    end
end
