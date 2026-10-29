classdef TestSwingResiduals < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function normalQuantilesHaveExpectedShapeAndBoundedP(testCase)
            residual = norminv(((1:201)' - 0.5) / 201);
            report = swing_residual_diagnostics(residual, zeros(size(residual)));
            testCase.verifyTrue(report.Tested);
            testCase.verifyEqual(report.Reject, 0);
            testCase.verifyEqual(report.PRelation, ">=");
            testCase.verifyEqual(report.PValue, 0.5);
            testCase.verifyEqual(report.Skewness, 0, 'AbsTol', 1e-12);
            testCase.verifyEqual(report.Kurtosis, 3, 'AbsTol', 0.1);
            testCase.verifyEqual(report.ExcessKurtosis, report.Kurtosis - 3);
            testCase.verifyEqual(report.TheoreticalQuantiles, residual);
        end
        function skewedDistributionRejectsAndReportsLowerBound(testCase)
            residual = exp(norminv(((1:301)' - 0.5) / 301));
            report = swing_residual_diagnostics(residual, zeros(size(residual)));
            testCase.verifyEqual(report.Reject, 1);
            testCase.verifyEqual(report.PRelation, "<=");
            testCase.verifyEqual(report.PValue, 0.001);
            testCase.verifyGreaterThan(report.Skewness, 2);
            testCase.verifyGreaterThan(report.Kurtosis, 3);
        end
        function biasCorrectionMatchesKnownSmallSample(testCase)
            report = swing_residual_diagnostics([0; 0; 0; 0; 1], zeros(5, 1));
            testCase.verifyEqual(report.Skewness, sqrt(5), 'AbsTol', 1e-12);
            testCase.verifyEqual(report.Kurtosis, 8, 'AbsTol', 1e-12);
            testCase.verifyEqual(report.ExcessKurtosis, 5, 'AbsTol', 1e-12);
        end
        function centeredStandardizationKeepsOriginalResiduals(testCase)
            fitted = (10:15)'; actual = fitted + [3; 5; 4; 8; 7; 6];
            report = swing_residual_diagnostics(actual', fitted');
            testCase.verifyEqual(report.Residual, actual - fitted);
            testCase.verifyEqual(report.Mean, 5.5);
            testCase.verifyEqual(mean(report.Standardized), 0, 'AbsTol', 1e-14);
            testCase.verifyEqual(std(report.Standardized), 1, 'AbsTol', 1e-14);
            testCase.verifyEqual(report.ObservedQuantiles, sort(report.Standardized));
        end
        function zeroAndConstantResidualsAreNotTested(testCase)
            x = (1:20)'; zero = swing_residual_diagnostics(x, x);
            constant = swing_residual_diagnostics(x + 2, x);
            for report = [zero, constant]
                testCase.verifyFalse(report.Tested);
                testCase.verifyTrue(isnan(report.Reject));
                testCase.verifyTrue(isnan(report.Skewness));
                testCase.verifyTrue(isnan(report.Kurtosis));
                testCase.verifyEmpty(report.ObservedQuantiles);
            end
        end
        function nearExactCurveDoesNotTestOptimizerRoundoff(testCase)
            x = linspace(850, 1250, 241)'; y = 0.01*(x - 1050) + 2.5*sin(2*pi*(x - 1050)/80 + 0.4);
            fit = fit_swing_curve(x, y);
            report = swing_residual_diagnostics(y, fit.Prediction);
            testCase.verifyFalse(report.Tested);
        end
        function fittedNoisyCurveProducesAlignedResiduals(testCase)
            stream = RandStream('mt19937ar', 'Seed', 42);
            x = linspace(850, 1250, 241)'; y = 0.01*(x - 1050) + 2.5*sin(2*pi*(x - 1050)/80 + 0.4) + 0.15*randn(stream, size(x));
            fit = fit_swing_curve(x, y); report = swing_residual_diagnostics(y, fit.Prediction);
            testCase.verifyTrue(report.Tested);
            testCase.verifyEqual(sqrt(mean(report.Residual.^2)), fit.RMSE, 'AbsTol', 1e-12);
            testCase.verifyEqual(report.Count, numel(x));
        end
        function testRestoresWarningsAndDoesNotUseRandomNumbers(testCase)
            high = warning('query', 'stats:lillietest:OutOfRangePHigh');
            low = warning('query', 'stats:lillietest:OutOfRangePLow'); before = rng;
            residual = norminv(((1:201)' - 0.5) / 201);
            swing_residual_diagnostics(residual, zeros(size(residual)), 0.01);
            testCase.verifyEqual(warning('query', high.identifier), high);
            testCase.verifyEqual(warning('query', low.identifier), low);
            testCase.verifyEqual(rng, before);
        end
        function csvAndExcelKeepNumbersAndPRelation(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            residual = exp(norminv(((1:101)' - 0.5) / 101));
            report = swing_residual_diagnostics(residual, zeros(size(residual)));
            for extension = ["csv", "xlsx"]
                file = fullfile(folder.Folder, "normality." + extension);
                writetable(report.Table, file);
                restored = readtable(file, 'TextType', 'string');
                testCase.verifyEqual(restored.Metric, report.Table.Metric);
                testCase.verifyEqual(restored.Value, report.Table.Value, 'AbsTol', 1e-10);
                testCase.verifyEqual(restored.Details, report.Table.Details);
            end
        end
        function invalidSamplesAndAlphaAreRejected(testCase)
            testCase.verifyError(@() swing_residual_diagnostics([1; 2; 3], [0; 0; 0]), 'swing_residual_diagnostics:tooFewRows');
            testCase.verifyError(@() swing_residual_diagnostics((1:5)', zeros(4, 1)), 'swing_residual_diagnostics:rowCount');
            testCase.verifyError(@() swing_residual_diagnostics((1:5)', zeros(5, 1), 0), 'MATLAB:notGreaterEqual');
        end
    end
end
