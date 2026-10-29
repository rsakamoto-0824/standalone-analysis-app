classdef TestSwingCurve < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function knownTrendAndSineRecoverParameters(testCase)
            x = linspace(850, 1250, 321)';
            y = 3.1 + 0.01 * (x - 1050) + 2.5 * sin(2*pi*(x - 1050)/80 + 0.4);
            fit = fit_swing_curve(x, y);
            testCase.verifyEqual(fit.Period, 80, 'AbsTol', 1e-5);
            testCase.verifyEqual(fit.Amplitude, 2.5, 'AbsTol', 1e-6);
            testCase.verifyEqual(fit.Slope, 0.01, 'AbsTol', 1e-8);
            testCase.verifyEqual(fit.Prediction, y, 'AbsTol', 1e-5);
            testCase.verifyGreaterThan(fit.RSquared, 0.999999);
            testCase.verifyLessThan(fit.RMSE, 1e-5);
        end
        function irregularUnsortedRepeatedInputsAreSupported(testCase)
            x = 850 + 400 * mod((1:240)' * 0.61803398875, 1); x = [x; x(1:20)];
            y = -0.006*(x - 1050) + 1.4*sin(2*pi*(x - 1050)/75 + 0.7) + 0.01*sin(1.7*x);
            fit = fit_swing_curve(x, y, struct('PeriodBounds', [60, 90]));
            testCase.verifyEqual(fit.Period, 75, 'AbsTol', 0.02);
            testCase.verifyEqual(fit.Slope, -0.006, 'AbsTol', 1e-5);
            testCase.verifyEqual(fit.Count, 260);
            testCase.verifyLessThan(fit.RMSE, 0.02);
        end
        function pureSineCanDisableBulkTrend(testCase)
            x = linspace(0, 100, 101)'; y = 2 + 3*sin(2*pi*x/25 + 0.2);
            fit = fit_swing_curve(x, y, struct('IncludeTrend', false));
            testCase.verifyEqual(fit.Period, 25, 'AbsTol', 1e-5);
            testCase.verifyEqual(fit.Amplitude, 3, 'AbsTol', 1e-5);
            testCase.verifyEqual(fit.Slope, 0);
        end
        function extremaUseDerivativeOfTrendPlusSine(testCase)
            fit = testCase.knownFit(0.1);
            [extrema, segments] = swing_curve_extrema(fit, [0, 60]);
            derivative = fit.Slope + fit.Amplitude*2*pi/fit.Period*cos(2*pi*extrema.Thickness/fit.Period);
            testCase.verifyEqual(derivative, zeros(height(extrema), 1), 'AbsTol', 1e-12);
            first_maximum = extrema.Thickness(find(extrema.Type == "極大", 1));
            testCase.verifyEqual(first_maximum, acos(-0.1/(2*2*pi/20))*20/(2*pi), 'AbsTol', 1e-12);
            testCase.verifyNotEqual(first_maximum, 5);
            testCase.verifyEqual(segments.Slope, repmat(0.1, height(segments), 1), 'AbsTol', 1e-12);
            testCase.verifyEqual(extrema.SHAP, swing_curve_values(fit, extrema.Thickness), 'AbsTol', 1e-12);
        end
        function maximaAndMinimaSegmentsKeepNegativeSlope(testCase)
            fit = testCase.knownFit(-0.05);
            [extrema, segments] = swing_curve_extrema(fit, [-20, 80]);
            testCase.verifyEqual(unique(segments.Type), ["極大間"; "極小間"]);
            testCase.verifyEqual(segments.Slope, repmat(-0.05, height(segments), 1), 'AbsTol', 1e-12);
            testCase.verifyGreaterThanOrEqual(extrema.Thickness, -20*ones(height(extrema), 1));
            testCase.verifyLessThanOrEqual(extrema.Thickness, 80*ones(height(extrema), 1));
        end
        function steepTrendHasNoFalseExtrema(testCase)
            fit = testCase.knownFit(1);
            [extrema, segments] = swing_curve_extrema(fit, [0, 60]);
            testCase.verifyEmpty(extrema); testCase.verifyEmpty(segments);
        end
        function boundaryStationaryPointsIncludedOnce(testCase)
            fit = testCase.knownFit(0); fit.SinCoefficient = 0; fit.CosCoefficient = 2; fit.PhaseRadians = pi/2;
            extrema = swing_curve_extrema(fit, [0, 40]);
            testCase.verifyEqual(extrema.Thickness, [0; 10; 20; 30; 40], 'AbsTol', 1e-12);
            testCase.verifyEqual(extrema.Type, ["極大"; "極小"; "極大"; "極小"; "極大"]);
        end
        function restrictedRangeDoesNotExtrapolateSegments(testCase)
            fit = testCase.knownFit(0);
            [extrema, segments] = swing_curve_extrema(fit, [15.1, 34.9]);
            testCase.verifyEqual(extrema.Thickness, 25, 'AbsTol', 1e-12);
            testCase.verifyEmpty(segments);
        end
        function invalidOrUnidentifiableInputsStopClearly(testCase)
            x = (1:20)';
            testCase.verifyError(@() fit_swing_curve(x, ones(size(x))), 'fit_swing_curve:noOscillation');
            testCase.verifyError(@() fit_swing_curve(x, 2*x + 3), 'fit_swing_curve:noOscillation');
            testCase.verifyError(@() fit_swing_curve(ones(size(x)), sin(x)), 'fit_swing_curve:distinct');
            testCase.verifyError(@() fit_swing_curve(x, sin(x), struct('PeriodBounds', [10, 1])), 'fit_swing_curve:bounds');
            testCase.verifyError(@() swing_curve_extrema(testCase.knownFit(0), [5, 5]), 'swing_curve_extrema:range');
        end
    end
    methods (Static, Access = private)
        function fit = knownFit(slope)
            fit = struct('Center', 0, 'Offset', 0, 'Slope', slope, 'SinCoefficient', 2, ...
                'CosCoefficient', 0, 'Amplitude', 2, 'Period', 20, 'PhaseRadians', 0);
        end
    end
end
