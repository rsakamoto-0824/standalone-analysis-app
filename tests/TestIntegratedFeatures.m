classdef TestIntegratedFeatures < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function statusKeepsWholeSentences(testCase)
            testCase.verifyEqual(status_lines('保存が完了しました。'), {'保存が完了しました。'});
            testCase.verifyEqual(status_lines("先頭" + newline + "次の行"), {'先頭'; '次の行'});
            testCase.verifyEqual(status_lines({'警告1', '警告2'}), {'警告1'; '警告2'});
        end
        function rSquaredDetectsOffsetThatCorrelationMisses(testCase)
            values = evaluate_predictions([1; 2; 3], [101; 102; 103]);
            testCase.verifyEqual(values.Value(1), -14999, 'AbsTol', 1e-10);
            testCase.verifyEqual(values.Value(2), 100, 'AbsTol', 1e-12);
            testCase.verifyEqual(values.Value(6), 1, 'AbsTol', 1e-12);
        end
        function undefinedMetricDoesNotDiscardOtherMetrics(testCase)
            values = evaluate_predictions([0; 1; 2], [0; 1; 2]);
            testCase.verifyTrue(isnan(values.Value(3)));
            testCase.verifyNotEmpty(char(values.Note(3)));
            testCase.verifyEqual(values.Value(1:2), [1; 0]);
            values = evaluate_predictions(ones(3, 1), ones(3, 1));
            testCase.verifyTrue(isnan(values.Value(1)));
            testCase.verifyEqual(values.Value(2), 0);
        end
        function summaryIncludesEveryInputAndOutput(testCase)
            summary = summarize_model_columns([1, 10; 2, 20; 3, 30], ["Input", "Predicted"]);
            testCase.verifyEqual(height(summary), 22);
            testCase.verifyEqual(summary.Value(summary.Column == "Predicted" & summary.Statistic == "mean"), 20);
        end
        function settingsRoundtripAndUnknownFieldWhitelist(testCase)
            folder = tempname; mkdir(folder); cleanup = onCleanup(@() rmdir(folder, 's'));
            path = fullfile(folder, 'settings.json'); defaults = app_settings('defaults');
            defaults.SaveFolder = folder; defaults.Theme = 'ダーク'; defaults.Secret = 'must-not-be-saved';
            app_settings('save', path, defaults); actual = app_settings('load', path);
            testCase.verifyEqual(actual.Theme, 'ダーク'); testCase.verifyEqual(actual.SaveFolder, folder);
            testCase.verifyFalse(isfield(actual, 'Secret')); testCase.verifyFalse(contains(fileread(path), 'must-not-be-saved'));
            defaults.Bins = 1;
            testCase.verifyError(@() app_settings('save', path, defaults), 'settings:bins');
            testCase.verifyEqual(app_settings('load', path), actual);
        end
        function orthogonalArraysHaveBalancedPairs(testCase)
            for levels = [2, 3]
                design = create_experiment_design('orthogonal', 8, 20, 42, 'linear', levels);
                for first = 1:7
                    for second = first + 1:8
                        [~, ~, group] = unique(design(:, [first, second]), 'rows');
                        counts = accumarray(group, 1);
                        testCase.verifyEqual(numel(counts), levels^2);
                        testCase.verifyEqual(counts, repmat(size(design, 1) / levels^2, levels^2, 1));
                    end
                end
            end
        end
        function iOptimalLinearOneFactorUsesBothEndpoints(testCase)
            [design, details] = create_experiment_design('I', 1, 4, 8, 'linear', 3);
            testCase.verifyEqual(sort(design), [-1; -1; 1; 1]);
            testCase.verifyEqual(details.Criterion, 1 / 3, 'AbsTol', 1e-12);
        end
        function iOptimalQuadraticOneFactorMatchesKnownAllocation(testCase)
            [design, details] = create_experiment_design('I', 1, 8, 8, 'quadratic', 3);
            testCase.verifyEqual(sort(design), [-1; -1; 0; 0; 0; 0; 1; 1]);
            matrix = doe_model_matrix(design, 'quadratic');
            moments = [1, 0, 1/3; 0, 1/3, 0; 1/3, 0, 1/5];
            testCase.verifyEqual(details.Criterion, trace((matrix' * matrix) \ moments), 'AbsTol', 1e-12);
        end
        function augmentationPreservesExistingPointsAndRandomState(testCase)
            existing = [-1, -1; 0.2, 0.3; 1, 1]; previous = rng;
            for method = {'D', 'I'}
                [design, details] = create_experiment_design(method{1}, 2, 6, 42, 'quadratic', 3, existing);
                testCase.verifyEqual(design(1:3, :), existing);
                testCase.verifyEqual(size(design), [9, 2]); testCase.verifyEqual(details.FixedRows, 3);
                testCase.verifyEqual(rank(doe_model_matrix(design, 'quadratic')), 6);
                testCase.verifyEqual(create_experiment_design(method{1}, 2, 6, 42, 'quadratic', 3, existing), design);
            end
            testCase.verifyEqual(rng, previous);
        end
        function aliasDiagnosticsExposePairAndMultipleTermDependencies(testCase)
            design = create_experiment_design('orthogonal', 3, 4, 42, 'linear', 2);
            report = design_diagnostics(design, 'linear');
            testCase.verifyEqual(report.Rank, 4);
            testCase.verifyLessThan(report.FullRank, report.FullTerms);
            full = doe_model_matrix(design, 'quadratic');
            testCase.verifyEqual(full * report.Dependencies, zeros(4, size(report.Dependencies, 2)), 'AbsTol', 1e-12);
            intercept = find(report.Names == "Intercept"); square = find(report.Names == "F1^2");
            testCase.verifyEqual(report.Similarity(intercept, square), 1, 'AbsTol', 1e-12);
        end
        function insufficientRunsStopBeforeOptimization(testCase)
            testCase.verifyError(@() create_experiment_design('I', 3, 9, 42, 'quadratic', 3), 'doe:tooFewRuns');
            testCase.verifyError(@() create_experiment_design('D', 2, 10, 42, 'quadratic', 3, zeros(2, 1)), 'doe:columns');
        end
    end
end
