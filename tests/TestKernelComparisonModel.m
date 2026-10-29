classdef TestKernelComparisonModel < matlab.unittest.TestCase
    properties
        Inputs
        Response
        Folder
    end
    methods (TestClassSetup)
        function targetReleaseOnly(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
            require_r2025b();
            index = (1:40)'; testCase.Inputs = [sin(index/4), cos(index/5), sin(index/7), index];
            testCase.Response = 50 + sin(index/4) + 0.02*index;
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); testCase.Folder = fixture.Folder;
        end
    end
    methods (Test)
        function allThreeFunctionsKeepFullModelsAndSaveContract(testCase)
            for kind = {'apc', 'swing', 'generic'}
                report = compare_gpr_kernels(kind{1}, testCase.Inputs, testCase.Response, {'matern32', 'squaredexponential'}, 'exact', 3, 0, 0);
                testCase.verifyTrue(all(report.Summary.Status == "成功"), evalc('disp(report.Summary)'));
                testCase.verifySize(report.OOFPredictions, [40, 2]); testCase.verifyTrue(all(isfinite(report.OOFPredictions), 'all'));
                selected = find(report.Summary.Rank == 1); model = report.Models{selected};
                testCase.verifyClass(model, 'RegressionGP'); testCase.verifyEqual(model.NumObservations, 40);
                testCase.verifyEqual(predict(model, model.X), report.TrainingPredictions(:, selected));
                file = fullfile(testCase.Folder, [kind{1} '.mat']); save_train_model(model, file);
                variables = whos('-file', file); testCase.verifyEqual({variables.name}, {'Train_Model'});
                expected = struct('KernelFunction', char(report.Summary.Kernel(selected)), 'FitMethod', 'exact', 'BasisFunction', 'constant', 'NumObservations', 40);
                verification = verify_saved_model(file, model, kind{1}, expected);
                testCase.verifyTrue(verification.Success, evalc('disp(verification.Checks)'));
            end
        end
        function validationPredictionMatchesIndependentFoldFit(testCase)
            report = compare_gpr_kernels('generic', testCase.Inputs, testCase.Response, {'matern32', 'matern52'}, 'exact', 3, 5, 0);
            held_out = report.FoldId == 1; before = rng; cleanup = onCleanup(@() rng(before));
            rng(6, 'twister'); model = train_generic_gpr_model(testCase.Inputs(~held_out, :), testCase.Response(~held_out), 'matern32', 'exact');
            testCase.verifyEqual(report.OOFPredictions(held_out, 1), predict(model, testCase.Inputs(held_out, :)), 'AbsTol', 1e-10);
        end
        function periodicKernelOptimizesInsideEachFold(testCase)
            thickness = linspace(0, 160, 25)'; X = [zeros(25, 3), thickness]; y = 50 + 2*sin(2*pi*thickness/40) + 0.01*thickness;
            report = compare_gpr_kernels('swing', X, y, {'matern32', 'swingperiodic'}, 'exact', 2, 0, 0);
            testCase.verifyTrue(all(report.Summary.Status == "成功"), evalc('disp(report.Summary)'));
            periodic_folds = report.FoldMetrics.Period(report.FoldMetrics.Kernel == "swingperiodic");
            testCase.verifyNumElements(periodic_folds, 2); testCase.verifyTrue(all(isfinite(periodic_folds)));
            info = swing_kernel_info(report.Models{2}.KernelFunction); testCase.verifyEqual(info.Period, report.Summary.Period(2));
            testCase.verifyEqual(report.Models{2}.NumObservations, 25);
        end
    end
end
