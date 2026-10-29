classdef TestFurnaceInterpolation < matlab.unittest.TestCase
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function splineReproducesCubicAndKeepsMissingIntervals(testCase)
            x = [1; 5; 12; 19; 30]; y = 100 + 0.01*x.^3 - 0.4*x.^2 + x;
            model = fit_furnace_model(x, y, 'spline'); query = (1:30)';
            [prediction, deviation, interval] = predict_furnace_model(model, query);
            testCase.verifyEqual(prediction, 100 + 0.01*query.^3 - 0.4*query.^2 + query, 'AbsTol', 1e-10);
            testCase.verifyTrue(all(isnan(deviation))); testCase.verifyTrue(all(isnan(interval), 'all'));
        end
        function rbfLinearTailAndResponseUnitsArePreserved(testCase)
            x = [1; 8; 17; 30; 45]; y = 50 + 0.1*x; options = struct('RBFWidth', 0, 'RBFRidge', 1e-8);
            model = fit_furnace_model(x, y, 'rbf', options); query = (1:45)';
            testCase.verifyEqual(predict_furnace_model(model, query), 50 + 0.1*query, 'AbsTol', 1e-10);
            curved = 50 + cos(x/20); first = fit_furnace_model(x, curved, 'rbf', options);
            second = fit_furnace_model(x, 1000 + 5*curved, 'rbf', options);
            testCase.verifyEqual(predict_furnace_model(second, query), 1000 + 5*predict_furnace_model(first, query), 'AbsTol', 1e-9);
        end
        function cubicPolynomialPreservesSmallResponseAndShiftedSlots(testCase)
            offsets = [0; 3; 11; 24; 38; 49]; x = 999950 + offsets;
            response = @(z) 1.46 + 1e-5*(0.01*z.^3 - 0.4*z.^2 + z);
            model = fit_furnace_model(x, response(offsets), 'poly3'); query = (0:49)';
            [prediction, deviation, interval] = predict_furnace_model(model, 999950 + query);
            testCase.verifyEqual(prediction, response(query), 'AbsTol', 1e-14);
            testCase.verifyTrue(all(isnan(deviation))); testCase.verifyTrue(all(isnan(interval), 'all'));
            constant = fit_furnace_model(x, 1.46*ones(size(x)), 'poly3');
            testCase.verifyEqual(predict_furnace_model(constant, x), 1.46*ones(size(x)), 'AbsTol', 1e-14);
        end
        function cubicPolynomialUsesAllRowsForLeastSquares(testCase)
            x = (-3:3)'; y = 10 + x.^3 + [0; 0.3; -0.2; 0.5; -0.1; 0.2; 0];
            design = [x.^3, x.^2, x, ones(size(x))]; coefficients = design \ y;
            model = fit_furnace_model(x + 10, y, 'poly3'); prediction = predict_furnace_model(model, x + 10);
            testCase.verifyEqual(prediction, design*coefficients, 'AbsTol', 1e-12);
            testCase.verifyGreaterThan(norm(prediction - y), 0.1);
            testCase.verifyEqual(design'*(prediction - y), zeros(4, 1), 'AbsTol', 1e-10);
        end
        function cubicValidationRefitsWithoutHeldOutResponse(testCase)
            x = [1; 5; 12; 19; 30; 45]; y = 100 + 0.01*x.^3 - 0.4*x.^2 + x + [0; 1; -2; 3; -1; 0];
            report = evaluate_furnace_models(x, y, {'Film'}, (1:45)', {'poly3'}, struct());
            testCase.verifyEqual(report.Comparison.Status, "成功"); testCase.verifyEqual(height(report.Metrics), 16);
            for held_out = 2:numel(x) - 1
                train = true(size(x)); train(held_out) = false;
                design = [x(train).^3, x(train).^2, x(train), ones(sum(train), 1)]; coefficients = design \ y(train);
                expected = [x(held_out)^3, x(held_out)^2, x(held_out), 1]*coefficients;
                testCase.verifyEqual(report.Series{1}.ValidationPrediction(held_out), expected, 'AbsTol', 1e-9);
            end
            inside = report.Series{1}.ValidationPrediction(2:end - 1);
            testCase.verifyEqual(report.Comparison.RMSE, sqrt(mean((y(2:end - 1) - inside).^2)), 'AbsTol', 1e-12);
            testCase.verifyTrue(all(isnan(report.Series{1}.ValidationPrediction([1, end]))));
        end
        function smallResponseScaleIsRestoredWithoutChangingUnits(testCase)
            x = (1:7)'; model = fit_furnace_model(x, x/10, 'spline');
            model.ResponseCenter = 1.46; model.ResponseScale = 1e-5;
            [prediction, deviation, interval] = predict_furnace_model(model, x);
            testCase.verifyEqual(prediction, 1.46 + 1e-6*x, 'AbsTol', 1e-15);
            testCase.verifyTrue(all(isnan(deviation))); testCase.verifyTrue(all(isnan(interval), 'all'));
        end
        function sparseTargetsUseTheirOwnMeasuredSlotsAndRanges(testCase)
            x = (1:10)'; values = [100 + x.^2, 1.4 + x/1000]; values([2, 4, 8], 1) = NaN; values([1, 3, 9, 10], 2) = NaN;
            report = evaluate_furnace_models(x, values, {'Thickness', 'RefractiveIndex'}, (1:12)', {'spline', 'rbf'}, struct());
            testCase.verifyTrue(all(report.Comparison.Status == "成功"), evalc('disp(report.Comparison)'));
            testCase.verifyEqual(report.Comparison.MeasuredSlots, [7; 7; 6; 6]); testCase.verifyEqual(report.Comparison.ValidationSlots, [5; 5; 4; 4]);
            prediction = report.Predictions(report.Predictions.Target == "RefractiveIndex", :);
            testCase.verifyTrue(all(isnan(prediction.Predicted(prediction.BoatSlot == 1 | prediction.BoatSlot > 8))));
            testCase.verifyEqual(height(report.Metrics), 64);
            for index = 1:4
                data = report.Series{index}; inside = 2:numel(data.Slots) - 1;
                metrics = evaluate_predictions(data.Actual(inside), data.ValidationPrediction(inside));
                testCase.verifyEqual(report.Comparison.RMSE(index), metrics.Value(2));
                testCase.verifyTrue(isnan(data.ValidationPrediction(1)) && isnan(data.ValidationPrediction(end)));
            end
        end
        function validationRowsNeverReachTrainerAndEndpointsStayInTraining(testCase)
            x = [1; 5; 9; 15; 22; 30]; y = 100 + x; seen = cell(0, 1);
            report = evaluate_furnace_models(x, y, {'Film'}, (1:30)', {'spline', 'rbf'}, struct(), [], @train, @predict);
            testCase.verifyEqual(seen(1:4), seen(6:9));
            for fold = 1:4
                testCase.verifyFalse(ismember(x(fold + 1), seen{fold}));
                testCase.verifyTrue(ismember(x(1), seen{fold}) && ismember(x(end), seen{fold}));
            end
            testCase.verifyEqual(seen{5}, x); testCase.verifyEqual(seen{10}, x);
            testCase.verifyEqual(report.Comparison.RMSE, [0; 0]); testCase.verifyEqual(report.Comparison.Rank, [1; 2]);
            function model = train(inputs, response, method, options)
                seen{end + 1, 1} = inputs; model = fit_furnace_model(inputs, response, method, options);
            end
        end
        function explicitExtrapolationIsFlaggedAndNeverScoredAsInterpolation(testCase)
            x = [3; 7; 11; 16; 21]; y = 2 + x;
            report = evaluate_furnace_models(x, y, {'Film'}, (1:24)', {'spline'}, struct('AllowExtrapolation', true));
            testCase.verifyTrue(all(isfinite(report.Predictions.Predicted)));
            testCase.verifyEqual(report.Predictions.Region(report.Predictions.OutsideMeasuredRange), repmat("外挿", 5, 1));
            testCase.verifyEqual(report.Comparison.ValidationSlots, 3);
            testCase.verifyTrue(all(isnan(report.Validation.ValidationPredicted([1, end]))));
        end
        function insufficientTargetAndFailedMethodDoNotHideOtherResults(testCase)
            x = (1:7)'; y = [2 + x, [1; 2; NaN(5, 1)]];
            report = evaluate_furnace_models(x, y, {'Enough', 'TooFew'}, x, {'spline', 'rbf'}, struct());
            testCase.verifyEqual(report.Comparison.Status, ["成功"; "成功"; "失敗"; "失敗"]);
            testCase.verifyTrue(all(isnan(report.Comparison.Rank(3:4)))); testCase.verifyEmpty(report.Series{3});
            testCase.verifyTrue(all(contains(report.Comparison.Note(3:4), 'furnace:tooFewSlots')));
            report = evaluate_furnace_models(x, y(:, 1), {'Film'}, x, {'spline', 'rbf'}, struct(), [], @failRBF);
            testCase.verifyEqual(report.Comparison.Status, ["成功"; "失敗"]);
            testCase.verifyEmpty(report.Series{2}); testCase.verifyEqual(height(report.Metrics), 16);
        end
        function constantTargetKeepsUndefinedMetricReasons(testCase)
            x = (1:7)'; report = evaluate_furnace_models(x, ones(7, 1), {'Film'}, x, {'spline'}, struct());
            testCase.verifyTrue(isnan(report.Comparison.R2)); testCase.verifyEqual(report.Comparison.RMSE, 0);
            testCase.verifyTrue(all(strlength(report.Metrics.Note(report.Metrics.Metric == "R2")) > 0));
        end
        function cancellationAndRandomStateArePreserved(testCase)
            x = (1:7)'; before = rng;
            evaluate_furnace_models(x, x + 10, {'Film'}, x, {'spline'}, struct()); testCase.verifyEqual(rng, before);
            testCase.verifyError(@() evaluate_furnace_models(x, x + 10, {'Film'}, x, {'spline'}, struct(), @cancel), 'AnalysisApp:cancelled');
            testCase.verifyEqual(rng, before);
            function cancel(event)
                if event.Index > 1, error('AnalysisApp:cancelled', 'cancel'); end
            end
        end
        function batchProfilesNeverUseOtherRunsAndKeepWaferIds(testCase)
            source = batchSource(); data = prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'Thickness', 'RefractiveIndex'}, 'バッチ');
            report = interpolate_furnace_batches(data, (1:9)', {'spline', 'rbf', 'poly3'}, struct());
            testCase.verifyEqual(height(report.Comparison), 12);
            testCase.verifyEqual(unique(report.Comparison.Batch), ["A"; "B"]);
            a = report.Predictions(report.Predictions.Batch == "A" & report.Predictions.Target == "Thickness" & report.Predictions.Method == "spline", :);
            b = report.Predictions(report.Predictions.Batch == "B" & report.Predictions.Target == "Thickness" & report.Predictions.Method == "spline", :);
            testCase.verifyEqual(b.Predicted(1:7) - a.Predicted(1:7), 100*ones(7, 1), 'AbsTol', 1e-10);
            testCase.verifyEqual(a.WaferId(1:7), "W" + string((1:7)')); testCase.verifyEqual(a.WaferId(8:9), [""; ""]);
            testCase.verifyEqual(a.SourceRow(1:7), (2:8)'); testCase.verifyTrue(all(isnan(a.SourceRow(8:9))));
            testCase.verifyEqual(report.Validation.WaferId(1:7), "W" + string((1:7)'));
            a = report.Predictions(report.Predictions.Batch == "A" & report.Predictions.Target == "Thickness" & report.Predictions.Method == "poly3", :);
            b = report.Predictions(report.Predictions.Batch == "B" & report.Predictions.Target == "Thickness" & report.Predictions.Method == "poly3", :);
            testCase.verifyEqual(b.Predicted(1:7) - a.Predicted(1:7), 100*ones(7, 1), 'AbsTol', 1e-10);
            for index = 1:numel(report.Series)
                item = report.Series{index};
                if item.Target == "Thickness" && item.Batch == "A", testCase.verifyLessThan(max(item.Actual), 100); end
            end
        end
        function metadataAndMissingMeasurementRulesAreExplicit(testCase)
            source = batchSource(); source.Cells{3, 3} = ''; data = prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'Thickness'}, 'バッチ');
            testCase.verifyTrue(isnan(data.Values(3))); testCase.verifyEqual(data.WaferId(3), "W3");
            source.Cells{2, 1} = ''; testCase.verifyError(@() prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'Thickness'}, 'バッチ'), 'furnace:missingIdentifier');
            source = batchSource(); source.Cells{3, 5} = ''; testCase.verifyError(@() prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'Thickness'}, 'バッチ'), 'furnace:missingIdentifier');
            source = batchSource(); testCase.verifyError(@() prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'Thickness'}), 'furnace:duplicateSlots');
            source.Cells{2, 1} = source.Cells{1, 1}; testCase.verifyError(@() prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'Thickness'}, 'バッチ'), 'furnace:duplicateWafer');
            testCase.verifyError(@() prepare_furnace_data(source, 'BoatSlot', 'BoatSlot', {'Thickness'}, 'バッチ'), 'furnace:columns');
        end
        function csvIdentifiersKeepLeadingZerosAndMissingTargets(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture); file = fullfile(folder.Folder, 'input.csv');
            fid = fopen(file, 'w', 'n', 'UTF-8'); fprintf(fid, 'WaferId,BoatSlot,膜厚 nm,Batch\n0001,1,100,007\n0002,2,,007\n'); fclose(fid);
            source = read_furnace_data(file, 1, 1); data = prepare_furnace_data(source, 'WaferId', 'BoatSlot', {'膜厚 nm'}, 'Batch');
            testCase.verifyEqual(data.WaferId, ["0001"; "0002"]); testCase.verifyEqual(data.Batch, ["007"; "007"]);
            testCase.verifyTrue(isnan(data.Values(2))); testCase.verifyEqual(data.SourceRows, [2; 3]);
        end
        function invalidSlotsAndMeasurementsStop(testCase)
            x = (1:7)';
            testCase.verifyError(@() evaluate_furnace_models([1; 1; (3:7)'], x, {'Film'}, x, {'spline'}, struct()), 'furnace:duplicateSlots');
            testCase.verifyError(@() evaluate_furnace_models(x, [x, x], {'Film'}, x, {'spline'}, struct()), 'furnace:shape');
            testCase.verifyError(@() evaluate_furnace_models(x, [Inf; x(2:end)], {'Film'}, x, {'spline'}, struct()), 'evaluate_furnace_models:infiniteRows');
            if ~strcmp(version('-release'), '2025b')
                testCase.verifyError(@() fit_furnace_model(x, x, 'gpr_matern52'), 'AnalysisApp:wrongRelease');
            end
        end
    end
end

function [prediction, deviation, interval] = predict(~, x)
prediction = 100 + x; deviation = NaN(size(x)); interval = NaN(numel(x), 2);
end
function model = failRBF(x, y, method, options)
if strcmp(method, 'rbf'), error('test:failure', 'candidate failure'); end
model = fit_furnace_model(x, y, method, options);
end

function source = batchSource()
x = (1:7)'; values = [50 + x, 1.4 + x/1000];
cells = [cellstr("W" + string(x)), num2cell(x), num2cell(values), repmat({'A'}, 7, 1); ...
    cellstr("V" + string(x)), num2cell(x), num2cell(values + [100, 0.1]), repmat({'B'}, 7, 1)];
source = struct('FileName', 'synthetic.csv', 'Headers', {{'WaferId', 'BoatSlot', 'Thickness', 'RefractiveIndex', 'バッチ'}}, 'Cells', {cells}, 'RowNumbers', (2:15)');
end
