classdef TestKernelComparison < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function commonFoldsExcludeEveryValidationRow(testCase)
            X = (1:23)'; y = 2*X + 10; calls = cell(0, 1);
            report = evaluate_kernel_candidates(X, y, {'exact', 'biased'}, 5, 91, 0, @train, @predictHeldOut);
            testCase.verifyEqual(sort(report.FoldId), repelem((1:5)', [5; 5; 5; 4; 4]));
            testCase.verifyEqual(calls(1:5), calls(7:11));
            testCase.verifyEqual(calls{6}, X); testCase.verifyEqual(calls{12}, X);
            testCase.verifyEqual(report.OOFPredictions, [y, y + 1]);
            testCase.verifyEqual(report.Summary.RMSE, [0; 1]); testCase.verifyEqual(report.Summary.Rank, [1; 2]);
            testCase.verifyEqual(height(report.Metrics), 32); testCase.verifyEqual(height(report.FoldMetrics), 10);
            testCase.verifyEqual(report.Summary.R2, [1; 1 - 23/sum((y - mean(y)).^2)], 'AbsTol', 1e-12);
            function [model, warnings, details] = train(inputs, ~, kernel, ~)
                calls{end + 1, 1} = inputs;
                model = struct('Seen', inputs, 'Bias', double(strcmp(kernel, 'biased'))); warnings = strings(0, 1); details = [];
            end
            function predicted = predictHeldOut(model, inputs)
                if numel(model.Seen) < numel(X), assert(~any(ismember(inputs, model.Seen))); end
                predicted = 2*inputs + 10 + model.Bias;
            end
        end
        function randomConditionsAreIndependentOfOrderAndCaller(testCase)
            X = (1:20)'; y = X + 10; before = rng;
            first = evaluate_kernel_candidates(X, y, {'a', 'b'}, 4, 19, 0, @randomModel, @(model, inputs) inputs + model);
            testCase.verifyEqual(rng, before);
            second = evaluate_kernel_candidates(X, y, {'b', 'a'}, 4, 19, 0, @randomModel, @(model, inputs) inputs + model);
            testCase.verifyEqual(first.FoldId, second.FoldId);
            testCase.verifyEqual(first.OOFPredictions, second.OOFPredictions(:, [2, 1]));
            testCase.verifyEqual(first.Models, second.Models([2, 1]));
        end
        function failedCandidateCannotBeRankedOrSaved(testCase)
            X = (1:20)'; report = evaluate_kernel_candidates(X, X + 10, {'bad', 'a', 'b'}, 4, 0, 0, @maybeFail, @(model, inputs) inputs + model);
            testCase.verifyEqual(report.Summary.Status, ["失敗"; "成功"; "成功"]);
            testCase.verifyTrue(isnan(report.Summary.Rank(1))); testCase.verifyEmpty(report.Models{1});
            testCase.verifyTrue(all(isnan(report.OOFPredictions(:, 1))));
            testCase.verifyTrue(contains(report.Summary.Note(1), 'test:failure'));
            testCase.verifyEqual(report.Summary.Rank(2:3), [1; 2]);
        end
        function allFailuresStillProduceInspectableReport(testCase)
            X = (1:12)'; report = evaluate_kernel_candidates(X, X + 10, {'bad', 'bad2'}, 3, 0, 0, @alwaysFail, @(model, inputs) inputs + model);
            testCase.verifyTrue(all(report.Summary.Status == "失敗")); testCase.verifyTrue(all(isnan(report.Summary.Rank)));
            testCase.verifyEmpty(report.Metrics); testCase.verifyTrue(all(cellfun(@isempty, report.Models)));
        end
        function periodCallbackReceivesFoldContextAndTrainingSubset(testCase)
            X = (1:20)'; contexts = cell(0, 1); seen = cell(0, 1);
            report = evaluate_kernel_candidates(X, X + 10, {'periodic', 'plain'}, 4, 8, 0, @train, @(~, inputs) inputs + 10, @progress);
            testCase.verifyEqual(numel(contexts), 10);
            testCase.verifyEqual([contexts{1:5}], 1:5);
            testCase.verifyEqual(seen{5}, X);
            for fold = 1:4, testCase.verifyEqual(seen{fold}, X(report.FoldId ~= fold)); end
            testCase.verifyEqual(report.Summary.Period, [20; 20]);
            function [model, warnings, details] = train(inputs, ~, kernel, callback)
                if strcmp(kernel, 'periodic'), seen{end + 1, 1} = inputs; end
                callback(1, 48, 20); model = 10; warnings = "warning"; details = struct('Period', 20);
            end
            function progress(event)
                if event.PeriodCount > 0
                    progress_fold = event.Fold; if progress_fold == 0, progress_fold = 5; end
                    contexts{end + 1, 1} = progress_fold;
                end
            end
        end
        function cancellationPropagatesAndRestoresRandomState(testCase)
            X = (1:20)'; before = rng;
            testCase.verifyError(@() evaluate_kernel_candidates(X, X, {'a', 'b'}, 4, 0, 0, @randomModel, @(model, inputs) inputs + model, @cancel), 'AnalysisApp:cancelled');
            testCase.verifyEqual(rng, before);
            function cancel(event)
                if event.KernelIndex == 2, error('AnalysisApp:cancelled', 'cancel'); end
            end
        end
        function finalFitFailureDoesNotLeaveCrossValidationPredictions(testCase)
            X = (1:20)';
            report = evaluate_kernel_candidates(X, X + 10, {'a', 'b'}, 4, 0, 0, @train, @(model, inputs) inputs + model);
            testCase.verifyTrue(all(report.Summary.Status == "失敗"));
            testCase.verifyTrue(all(isnan(report.OOFPredictions), 'all')); testCase.verifyEmpty(report.Metrics);
            function [model, warnings, details] = train(inputs, ~, ~, ~)
                if numel(inputs) == 20, error('test:finalFit', 'failed full fit'); end
                model = 10; warnings = []; details = [];
            end
        end
        function undefinedMetricsKeepReasons(testCase)
            X = (1:20)'; report = evaluate_kernel_candidates(X, zeros(20, 1), {'a', 'b'}, 4, 0, 0, @randomModel, @(~, inputs) ones(size(inputs)));
            testCase.verifyTrue(all(isnan(report.Summary.R2))); testCase.verifyTrue(all(isnan(report.Summary.RMSPE_percent)));
            notes = report.Metrics.Note(ismember(report.Metrics.Metric, ["R2", "RMSPE_percent"]));
            testCase.verifyTrue(all(strlength(notes) > 0));
        end
        function invalidRequestsStopBeforeFitting(testCase)
            X = (1:12)';
            testCase.verifyError(@() evaluate_kernel_candidates(X, X, {'a'}, 3, 0, 0, @alwaysFail, @plus), 'evaluate_kernel_candidates:kernels');
            testCase.verifyError(@() evaluate_kernel_candidates(X, X, {'a', 'a'}, 3, 0, 0, @alwaysFail, @plus), 'evaluate_kernel_candidates:kernels');
            testCase.verifyError(@() compare_gpr_kernels('apc', ones(25, 4), X, {'matern32', 'matern52'}, 'exact', 5, 0, 0), 'compare_gpr_kernels:apcRows');
            testCase.verifyError(@() compare_gpr_kernels('generic', X, X, {'matern32', 'swingperiodic'}, 'exact', 3, 0, 0), 'compare_gpr_kernels:invalidKernel');
        end
    end
end

function [model, warnings, details] = randomModel(~, ~, ~, ~)
model = 10 + rand(); warnings = []; details = [];
end
function [model, warnings, details] = maybeFail(~, ~, kernel, ~)
if strcmp(kernel, 'bad'), error('test:failure', 'failed candidate'); end
model = 10; warnings = []; details = [];
end
function [model, warnings, details] = alwaysFail(~, ~, ~, ~)
model = []; warnings = []; details = []; %#ok<NASGU>
error('test:failure', 'failed candidate');
end
