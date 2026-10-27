classdef TestPureFunctions < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addProjectPaths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function knownVectors_metricsMatchHandCalculation(testCase)
            actual = [1, 2, 4]; predicted = [2; 3; 5];
            testCase.verifyEqual(calc_rmse(actual, predicted), 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(calc_mae(actual, predicted), 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(calc_rmspe(actual, predicted), sqrt(7 / 16) * 100, 'AbsTol', 1e-12);
            testCase.verifyEqual(calc_pearson(actual, predicted), 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(calc_r_squared(actual, predicted), 1, 'AbsTol', 1e-12);
            testCase.verifyEqual(calc_all_metrics(actual, predicted), ...
                {'rmse', 1; 'mae', 1; 'r', 1; 'r_squared', 1}, 'AbsTol', 1e-12);
        end
        function shiftedPrediction_rSquaredRemainsCorrelationSquared(testCase)
            testCase.verifyEqual(calc_r_squared([1; 2; 3], [101; 102; 103]), 1, 'AbsTol', 1e-12);
        end
        function knownVectorWithNaN_summaryMatchesHandCalculation(testCase)
            summary = calc_column_summary([1, 2, 3, 4, NaN]);
            expected_names = {'n'; 'n_missing'; 'mean'; 'median'; 'max'; 'min'; 'range'; 'iqr'; 'q1'; 'q3'; 'std'};
            expected_values = [4; 1; 2.5; 2.5; 4; 1; 3; 2; 1.5; 3.5; sqrt(5 / 3)];
            testCase.verifyEqual(summary(:, 1), expected_names);
            testCase.verifyEqual(cell2mat(summary(:, 2)), expected_values, 'AbsTol', 1e-12);
        end
        function knownHistograms_klUsesNaturalLogAndPseudocounts(testCase)
            expected = (3 / 4) * log(3 / 2) + (1 / 4) * log(1 / 2);
            testCase.verifyEqual(calc_kl_divergence([0, 0], [0, 1], 2), expected, 'AbsTol', 1e-12);
        end
        function knownJointCounts_mutualInformationUsesBits(testCase)
            expected = 2 * (3 / 8) * log2(3 / 2) + 2 * (1 / 8) * log2(1 / 2);
            testCase.verifyEqual(calc_mutual_information([0, 0, 1, 1], [0, 0, 1, 1], 2), expected, 'AbsTol', 1e-12);
        end
        function knownBounds_extrapolationFlagsOnlyOutsideRows(testCase)
            training = [-1, 0, 1; 1, 0, 1; 0, 2, 2];
            [outside, rows] = isExtrapolationDetected(training, [0, 1, 1.5; 1, 2, 2]);
            testCase.verifyFalse(outside); testCase.verifyEqual(rows, [false; false]);
            [outside, rows] = isExtrapolationDetected(training, [0, 1, 1.5; 0, 1, 0.5]);
            testCase.verifyTrue(outside); testCase.verifyEqual(rows, [false; true]);
        end
        function radiusOutsideEvenWithXYInside_extrapolationIsDetected(testCase)
            training = [-1, 0; 1, 0; 0, 1; 0, -1];
            training = [training, sqrt(sum(training.^2, 2))];
            query = [1, 1, sqrt(2)];
            testCase.verifyTrue(isExtrapolationDetected(training, query));
        end
        function reorderedColumns_mappingRestoresCanonicalOrder(testCase)
            source = testCase.makeSource({'NSG_TH', 'y', 'SIN_RN', 'RESIST_TH', 'SIN_TH'}, ...
                num2cell([3, 9, 2, 4, 1; 30, 90, 20, 40, 10]));
            constants = model_constants();
            testCase.verifyEqual(assign_required_columns(source, constants.PREDICTOR_NAMES), [1, 2, 3, 4; 10, 20, 30, 40]);
        end
        function missingOrRepeatedColumn_mappingStops(testCase)
            source = testCase.makeSource({'A', 'B'}, num2cell([1, 2; 3, 4]));
            testCase.verifyError(@() extract_numeric_columns(source, {'A', 'C'}), 'extract_numeric_columns:missingColumn');
            testCase.verifyError(@() extract_numeric_columns(source, {'A', 'A'}), 'extract_numeric_columns:duplicateColumns');
            source.Headers = {'A', 'A'};
            testCase.verifyError(@() extract_numeric_columns(source, {'A'}), 'extract_numeric_columns:missingColumn');
        end
        function missingCell_trainingInputStopsAtOriginalRow(testCase)
            source = testCase.makeSource({'A', 'B'}, {1, 2; 3, []});
            testCase.verifyError(@() extract_numeric_columns(source, {'A', 'B'}), 'extract_numeric_columns:missingRows');
            matrix = extract_numeric_columns(source, {'A', 'B'}, true);
            testCase.verifyTrue(isnan(matrix(2, 2)));
        end
        function invalidTextCell_noSilentConversion(testCase)
            source = testCase.makeSource({'A'}, {1; 'not a number'});
            testCase.verifyError(@() extract_numeric_columns(source, {'A'}), 'extract_numeric_columns:nonNumeric');
        end
        function repeatedCsvHeaders_importStops(testCase)
            path = [tempname, '.csv']; cleanup = onCleanup(@() delete(path));
            testCase.writeText(path, "A,A" + newline + "1,2" + newline);
            testCase.verifyError(@() read_input_data(path, 1, 1), 'read_input_data:duplicateHeaders');
        end
        function csvHeaderOffsetAndBlankCell_preservesOriginalRows(testCase)
            path = [tempname, '.csv']; cleanup = onCleanup(@() delete(path));
            testCase.writeText(path, "metadata," + newline + "A,B" + newline + "1,2" + newline + "3," + newline);
            source = read_input_data(path, 1, 2);
            testCase.verifyEqual(source.Headers, {'A', 'B'});
            testCase.verifyEqual(source.RowNumbers, [3; 4]);
            testCase.verifyError(@() extract_numeric_columns(source, {'A', 'B'}), 'extract_numeric_columns:missingRows');
        end
        function allDelimiters_wordCountsMatch(testCase)
            text = "Alpha alpha　BETA,beta、Gamma。gamma.delta!delta?epsilon！epsilon？z" + ...
                newline + "Beta" + char(13) + "alpha" + char(9) + "gamma";
            [words, counts] = create_wordCloud(text);
            testCase.verifyEqual(words, {'alpha'; 'beta'; 'delta'; 'epsilon'; 'gamma'});
            testCase.verifyEqual(counts, [3; 3; 2; 2; 3]);
            testCase.verifyError(@() create_wordCloud('a ! ?'), 'create_wordCloud:noWords');
        end
        function invalidParameters_errorListsValidValues(testCase)
            testCase.verifyError(@() validate_model_parameters('bad', 'exact', 'test'), 'test:invalidKernel');
            testCase.verifyError(@() validate_model_parameters('matern32', 'bad', 'test'), 'test:invalidFitMethod');
            validate_model_parameters('MATERN32', 'EXACT', 'test');
            testCase.verifyError(@() train_apc_model(ones(25, 4), ones(25, 1), 0, 'bad', 'exact'), ...
                'train_apc_model:invalidKernel');
            testCase.verifyError(@() train_swing_curve_model(ones(3, 3), ones(3, 1), ones(3, 1), 'matern32', 'bad'), ...
                'train_swing_curve_model:invalidFitMethod');
            testCase.verifyError(@() train_in_plane_model(ones(3, 2), ones(3, 1), 'bad', 'exact'), ...
                'train_in_plane_model:invalidKernel');
            testCase.verifyError(@() train_generic_gpr_model(ones(3, 2), ones(3, 1), 'matern32', 'bad'), ...
                'train_generic_gpr_model:invalidFitMethod');
        end
        function fewerThan25ApcRows_stopsBeforeTraining(testCase)
            testCase.verifyError(@() train_apc_model(ones(24, 4), ones(24, 1)), 'train_apc_model:tooFewRows');
        end
        function invalidSwingColumns_stopsBeforeTraining(testCase)
            testCase.verifyError(@() train_swing_curve_model(ones(5, 2), ones(5, 1), ones(5, 1)), ...
                'train_swing_curve_model:columnCount');
        end
        function mismatchedVectorsOrZeroRmspe_error(testCase)
            testCase.verifyError(@() calc_all_metrics([1, 2], 1), 'calc_all_metrics:rowCount');
            testCase.verifyError(@() calc_all_metrics(1, 1), 'calc_all_metrics:tooFewRows');
            testCase.verifyError(@() calc_rmspe([0, 1], [1, 1]), 'calc_rmspe:zeroTrueValue');
            testCase.verifyError(@() calc_kl_divergence([1, 1], [1, 1]), 'calc_kl_divergence:constantData');
            testCase.verifyError(@() calc_mutual_information([1, 2], [1, 2], 1), 'calc_mutual_information:invalidBins');
            testCase.verifyError(@() calc_column_summary([NaN, 1]), 'calc_column_summary:tooFewRows');
        end
        function loggingWhitelist_omitsMeasurementArrays(testCase)
            folder = tempname; mkdir(folder); cleanup = onCleanup(@() rmdir(folder, 's'));
            entry = struct('Function', 'apc', 'Rows', 25, 'Status', 'test', 'X', 123456789, 'y', 987654321);
            write_training_log(folder, entry);
            content = fileread(fullfile(folder, 'training.jsonl'));
            record = jsondecode(content);
            testCase.verifyFalse(isfield(record, 'X')); testCase.verifyFalse(isfield(record, 'y'));
            testCase.verifyFalse(contains(content, '123456789'));
            testCase.verifyEqual(record.Rows, 25);
        end
        function extraMatVariable_verificationFails(testCase)
            path = [tempname, '.mat']; cleanup = onCleanup(@() delete(path));
            Train_Model = 1; extra = 2; save(path, 'Train_Model', 'extra');
            report = verify_saved_model(path, Train_Model, 'generic', struct());
            testCase.verifyFalse(report.Success);
            testCase.verifyFalse(report.Checks.Passed(1));
            testCase.verifyEqual(report.Message, 'このモデルを制御に使用しないでください');
        end
    end
    methods (Static, Access = private)
        function source = makeSource(headers, cells)
            source = struct('Headers', {headers}, 'Cells', {cells}, 'RowNumbers', (2:size(cells, 1) + 1)');
        end
        function writeText(path, content)
            fid = fopen(path, 'w', 'n', 'UTF-8'); cleanup = onCleanup(@() fclose(fid));
            fprintf(fid, '%s', char(content));
        end
    end
end
