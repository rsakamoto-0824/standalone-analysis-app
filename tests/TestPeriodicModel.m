classdef TestPeriodicModel < matlab.unittest.TestCase
    properties
        Inputs
        Response
        Model
        Details
        Folder
    end
    methods (TestClassSetup)
        function trainInTargetRelease(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
            require_r2025b();
            thickness = linspace(0, 200, 41)';
            testCase.Inputs = [zeros(numel(thickness), 3), thickness];
            testCase.Response = 50 + 2*sin(2*pi*thickness/40 + 0.3) + 0.006*thickness;
            [testCase.Model, ~, testCase.Details] = train_swing_curve_model(testCase.Inputs(:, 1:3), thickness, testCase.Response, 'swingperiodic', 'exact');
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); testCase.Folder = fixture.Folder;
        end
    end
    methods (Test)
        function knownWaveAndFullModelContract(testCase)
            testCase.verifyClass(testCase.Model, 'RegressionGP');
            testCase.verifyEqual(testCase.Model.PredictorNames, {'SIN_TH', 'SIN_RN', 'NSG_TH', 'RESIST_TH'});
            testCase.verifyEqual(testCase.Details.Period, 40, 'AbsTol', 2);
            testCase.verifyNumElements(testCase.Model.KernelInformation.KernelParameters, 7);
            testCase.verifyEmpty(testCase.Model.HyperparameterOptimizationResults);
            testCase.verifyEqual(testCase.Details.LogLikelihood, testCase.Model.LogLikelihood);
            prediction = predict(testCase.Model, testCase.Model.X);
            testCase.verifyLessThan(sqrt(mean((prediction - testCase.Response).^2)), 0.1);
        end
        function matContainsOnlyTrainModelAndRetainsPeriod(testCase)
            file = fullfile(testCase.Folder, 'periodic.mat'); save_train_model(testCase.Model, file);
            variables = whos('-file', file); testCase.verifyEqual({variables.name}, {'Train_Model'});
            loaded = load_train_model(file);
            testCase.verifyEqual(swing_kernel_info(loaded.KernelFunction), swing_kernel_info(testCase.Model.KernelFunction));
            testCase.verifyEqual(predict(loaded, loaded.X), predict(testCase.Model, testCase.Model.X));
            expected = struct('KernelFunction', 'swingperiodic', 'FitMethod', 'exact', 'BasisFunction', 'constant', 'NumObservations', 41);
            report = verify_saved_model(file, testCase.Model, 'swing', expected);
            testCase.verifyTrue(report.Success, evalc('disp(report.Checks)'));
            comparison = compare_models(file, file, testCase.Inputs);
            testCase.verifyTrue(all(comparison.Checks.Passed));
            testCase.verifyTrue(comparison.PredictionsExactlyEqual);
        end
        function customKernelSupportsShapPredictions(testCase)
            [~, values] = compute_shap_values(testCase.Model, testCase.Inputs(1:3, :));
            testCase.verifySize(values, [3, 4]); testCase.verifyTrue(all(isfinite(values), 'all'));
        end
        function approximateMethodsUseTheSelectedMethod(testCase)
            for method = {'sd', 'sr', 'fic'}
                [model, ~, details] = train_swing_curve_model(testCase.Inputs(:, 1:3), testCase.Inputs(:, 4), testCase.Response, 'swingperiodic', method{1});
                testCase.verifyEqual(model.FitMethod, method{1});
                testCase.verifyEqual(details.Criterion, '近似周辺対数尤度');
                testCase.verifyTrue(all(isfinite(predict(model, model.X))));
            end
        end
    end
end
