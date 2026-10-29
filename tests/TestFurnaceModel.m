classdef TestFurnaceModel < matlab.unittest.TestCase
    methods (TestClassSetup)
        function targetRelease(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
            require_r2025b();
        end
    end
    methods (Test)
        function smoothGprKernelsReturnPredictionsAndResponseIntervals(testCase)
            x = [1; 6; 12; 20; 31; 45; 60]; y = 100 + 2*sin(x/30) + 0.01*x;
            methods = {'gpr_squaredexponential', 'gpr_matern52', 'gpr_rationalquadratic'};
            report = evaluate_furnace_models(x, y, {'Thickness'}, (1:60)', methods, struct());
            testCase.verifyTrue(all(report.Comparison.Status == "成功"), evalc('disp(report.Comparison)'));
            testCase.verifyEqual(height(report.Metrics), 48);
            testCase.verifyTrue(all(isfinite(report.Predictions.ResponseSD)));
            testCase.verifyTrue(all(report.Predictions.Lower95 <= report.Predictions.Predicted & report.Predictions.Upper95 >= report.Predictions.Predicted));
            for index = 1:3
                selected = report.Series{index}; model = fit_furnace_model(x, y, methods{index});
                testCase.verifyClass(model.Fit, 'RegressionGP'); testCase.verifyEqual(model.Fit.NumObservations, 7);
                testCase.verifyEqual(predict_furnace_model(model, (1:60)'), selected.Prediction, 'AbsTol', 1e-9);
            end
            constant = fit_furnace_model(x, 1.46*ones(size(x)), 'gpr_matern52');
            [prediction, deviation, interval] = predict_furnace_model(constant, (1:60)');
            testCase.verifyEqual(prediction, 1.46*ones(60, 1), 'AbsTol', 1e-6);
            testCase.verifyTrue(all(isfinite(deviation))); testCase.verifyTrue(all(isfinite(interval), 'all'));
        end
        function validationMatchesFitWithoutHeldOutSlot(testCase)
            x = [1; 5; 11; 18; 26; 36]; y = 1.4 + 1e-5*cos(x/20);
            report = evaluate_furnace_models(x, y, {'RefractiveIndex'}, (1:36)', {'gpr_matern52'}, struct());
            retained = true(6, 1); retained(3) = false; model = fit_furnace_model(x(retained), y(retained), 'gpr_matern52');
            testCase.verifyEqual(report.Series{1}.ValidationPrediction(3), predict_furnace_model(model, x(3)), 'AbsTol', 1e-9);
        end
    end
end
