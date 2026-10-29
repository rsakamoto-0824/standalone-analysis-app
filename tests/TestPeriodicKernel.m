classdef TestPeriodicKernel < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function covarianceIsSymmetricPositiveSemidefinite(testCase)
            index = (1:37)'; x = [sin(index/7), cos(index/11), sin(index/13), index/5];
            kernel = make_swing_periodic_kernel(4, 2, [2, 10]);
            gram = kernel(x, x, zeros(7, 1));
            testCase.verifyEqual(gram, gram', 'AbsTol', 1e-12);
            testCase.verifyGreaterThanOrEqual(min(eig((gram + gram')/2)), -1e-10);
            testCase.verifyEqual(kernel(x(1:4, :), x(5:9, :), zeros(7, 1)), gram(1:4, 5:9), 'AbsTol', 1e-12);
        end
        function periodicPartRepeatsInResistDimensionOnly(testCase)
            kernel = make_swing_periodic_kernel(80, 10, [20, 400]);
            theta = zeros(7, 1); theta(7) = -30;
            x = [0, 0, 0, 0]; same_phase = [0, 0, 0, 8]; half_phase = [0, 0, 0, 4];
            testCase.verifyEqual(kernel(x, same_phase, theta), kernel(x, x, theta), 'AbsTol', 1e-12);
            testCase.verifyLessThan(kernel(x, half_phase, theta), kernel(x, same_phase, theta));
            changed_other = [8, 0, 0, 0];
            testCase.verifyLessThan(kernel(x, changed_other, theta), kernel(x, same_phase, theta));
        end
        function linearBulkTermDoesNotForceWholeCurveToRepeat(testCase)
            kernel = make_swing_periodic_kernel(80, 10, [20, 400]); theta = zeros(7, 1);
            left = [0, 0, 0, 1]; a = [0, 0, 0, 2]; b = [0, 0, 0, 10];
            testCase.verifyEqual(kernel(left, b, theta) - kernel(left, a, theta), 8, 'AbsTol', 1e-12);
        end
        function originalAndStandardizedUnitsGiveSamePhase(testCase)
            physical = make_swing_periodic_kernel(80, 1, [20, 400]); standardized = make_swing_periodic_kernel(80, 100, [20, 400]);
            x = [zeros(9, 3), linspace(850, 1250, 9)']; z = x; z(:, 4) = (x(:, 4) - 1050)/100;
            theta = zeros(7, 1); theta(7) = -30;
            testCase.verifyEqual(physical(x, x, theta), standardized(z, z, theta), 'AbsTol', 1e-12);
        end
        function periodIsOutsideTheSevenLearningParameters(testCase)
            kernel = make_swing_periodic_kernel(80, 100, [20, 400]); info = swing_kernel_info(kernel);
            testCase.verifyEqual(info.Period, 80);
            testCase.verifyEqual(model_kernel_name(kernel), 'swingperiodic');
            testCase.verifyEqual(model_kernel_name('matern32'), 'matern32');
            testCase.verifyEmpty(swing_kernel_info(@(left, right, theta) left*right' + sum(theta)));
            testCase.verifyError(@() kernel(zeros(1, 4), zeros(1, 4), zeros(8, 1)), 'swing_kernel:parameters');
        end
        function functionHandleRoundtripPreservesPeriodAndKernel(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            kernel = make_swing_periodic_kernel(80, 100, [20, 400]);
            description = functions(kernel); testCase.verifyEmpty(description.file);
            file = fullfile(folder.Folder, 'kernel_only.mat'); save(file, 'kernel'); loaded = load(file, 'kernel');
            testCase.verifyEqual(swing_kernel_info(loaded.kernel), swing_kernel_info(kernel));
            x = [zeros(5, 3), (1:5)'];
            testCase.verifyEqual(loaded.kernel(x, x, zeros(7, 1)), kernel(x, x, zeros(7, 1)));
        end
        function syntheticLikelihoodPeakIsOptimizedInternally(testCase)
            thickness = linspace(850, 1250, 101)';
            result = optimize_swing_period(@(period, ~) -((400/period - 5.13)/0.4)^2, thickness);
            testCase.verifyEqual(result.Period, 400/5.13, 'AbsTol', 0.1);
            testCase.verifyLessThanOrEqual(result.Evaluations, result.MaximumEvaluations);
            testCase.verifyEqual(result.LogLikelihood, max(result.Trace.LogLikelihood));
            testCase.verifyTrue(all(result.Trace.Period >= result.SearchBounds(1) - 1e-12));
            testCase.verifyTrue(all(result.Trace.Period <= result.SearchBounds(2) + 1e-12));
        end
        function seededMultimodalSearchUsesLikelihoodNotSeed(testCase)
            x = linspace(0, 400, 101)';
            result = optimize_swing_period(@(period, ~) max(-((400/period - 5)/0.2)^2, -1 - ((400/period - 9)/0.3)^2), x, 400/9);
            testCase.verifyEqual(result.Period, 80, 'AbsTol', 0.1);
        end
        function failedCandidatesAreRecordedAndAllFailureStops(testCase)
            x = linspace(0, 400, 101)';
            result = optimize_swing_period(@testCase.limitedLikelihood, x, 80);
            testCase.verifyTrue(any(~result.Trace.Succeeded));
            testCase.verifyEqual(result.Period, 80, 'AbsTol', 0.1);
            testCase.verifyError(@() optimize_swing_period(@(~, ~) NaN, x), 'swing_period:allFailed');
            testCase.verifyError(@() optimize_swing_period(@(~, ~) 1, ones(10, 1)), 'swing_period:distinct');
        end
        function cancellationAndCallerRandomStateArePreserved(testCase)
            x = linspace(0, 400, 101)'; before = rng;
            optimize_swing_period(@(period, ~) -(period - 80)^2, x, 80);
            testCase.verifyEqual(rng, before);
            testCase.verifyError(@() optimize_swing_period(@(~, ~) 1, x, [], @testCase.cancel), 'test:cancel');
        end
        function swingSettingMigratesAndDoesNotAffectOtherModels(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            path = fullfile(folder.Folder, 'settings.json'); old = app_settings('defaults');
            old = rmfield(old, 'SwingKernel'); old.Kernel = 'matern32';
            migrated = app_settings('save', path, old); testCase.verifyEqual(migrated.SwingKernel, 'matern32');
            migrated.SwingKernel = 'swingperiodic'; app_settings('save', path, migrated);
            actual = app_settings('load', path); testCase.verifyEqual(actual.SwingKernel, 'swingperiodic');
            testCase.verifyEqual(actual.Kernel, 'matern32');
            testCase.verifyError(@() validate_model_parameters('swingperiodic', 'exact', 'test'), 'test:invalidKernel');
            validate_model_parameters('swingperiodic', 'fic', 'test', true);
        end
    end
    methods (Static, Access = private)
        function value = limitedLikelihood(period, ~)
            if period < 30, error('test:candidateFailure', '候補失敗の試験'); end
            value = -(400/period - 5)^2;
        end
        function cancel(~, ~, ~)
            error('test:cancel', '中止の試験');
        end
    end
end
