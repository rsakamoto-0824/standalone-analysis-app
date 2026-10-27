classdef TestModelCompatibility < matlab.unittest.TestCase
    properties
        X
        Y
        Folder
    end
    methods (TestClassSetup)
        function initialize(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
            require_r2025b();
            testCase.assertTrue(license('test', 'Statistics_Toolbox'));
            index = (1:150)';
            testCase.X = [sin(index / 7), cos(index / 11), index / 31, sin(index / 13) + index / 200];
            testCase.Y = sin(testCase.X(:, 1)) + testCase.X(:, 2).^2 + ...
                0.5 * testCase.X(:, 3) + 0.3 * testCase.X(:, 4) + 0.02 * cos(index);
            fixture = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture());
            testCase.Folder = fixture.Folder;
        end
    end
    methods (Test)
        function allModelTypes_savedVariableAndPredictionsMatch(testCase)
            models = {train_apc_model(testCase.X, testCase.Y), ...
                train_swing_curve_model(testCase.X(:, 1:3), testCase.X(:, 4), testCase.Y), ...
                train_in_plane_model(testCase.X(:, 1:2), testCase.Y), ...
                train_generic_gpr_model(testCase.X, testCase.Y)};
            types = {'apc', 'swing', 'in_plane', 'generic'};
            constants = model_constants();
            for index = 1:numel(models)
                path = fullfile(testCase.Folder, [types{index} '.mat']);
                save_train_model(models{index}, path);
                variables = whos('-file', path);
                testCase.verifyEqual({variables.name}, {'Train_Model'});
                loaded = load(path, 'Train_Model');
                testCase.verifyClass(loaded.Train_Model, 'RegressionGP');
                testCase.verifyEqual(predict(models{index}, models{index}.X), predict(loaded.Train_Model, models{index}.X));
                if index <= 2
                    testCase.verifyEqual(models{index}.PredictorNames, constants.PREDICTOR_NAMES);
                    testCase.verifyTrue(istable(models{index}.X));
                else
                    testCase.verifyFalse(istable(models{index}.X));
                end
                report = verify_saved_model(path, models{index}, types{index});
                testCase.verifyTrue(report.Success, evalc('disp(report.Checks)'));
            end
        end
        function shuffledFileColumns_canonicalModelsPredictExactlyEqual(testCase)
            constants = model_constants();
            names = [constants.PREDICTOR_NAMES, {'y'}];
            input_table = array2table([testCase.X, testCase.Y], 'VariableNames', names);
            original_path = fullfile(testCase.Folder, 'original.csv');
            shuffled_path = fullfile(testCase.Folder, 'shuffled.csv');
            writetable(input_table, original_path);
            order = [3, 5, 1, 4, 2];
            writetable(input_table(:, order), shuffled_path);
            source = read_input_data(original_path, 1, 1);
            original = assign_required_columns(source, constants.PREDICTOR_NAMES);
            source = read_input_data(shuffled_path, 1, 1);
            reordered = assign_required_columns(source, constants.PREDICTOR_NAMES);
            first = train_apc_model(original, testCase.Y);
            second = train_apc_model(reordered, testCase.Y);
            testCase.verifyEqual(first.PredictorNames, second.PredictorNames);
            testCase.verifyEqual(predict(first, first.X), predict(second, first.X));
        end
        function apcBoundaryRows_warningsOnlyFrom25Through149(testCase)
            testCase.verifyError(@() train_apc_model(testCase.X(1:24, :), testCase.Y(1:24)), 'train_apc_model:tooFewRows');
            for count = [25, 149]
                [~, warnings] = train_apc_model(testCase.X(1:count, :), testCase.Y(1:count));
                testCase.verifyEqual(warnings, "データが少ないためモデルの扱いに注意してください");
            end
            [~, warnings] = train_apc_model(testCase.X, testCase.Y);
            testCase.verifyEmpty(warnings);
        end
        function swingBelow25Rows_noApcRowLimit(testCase)
            [~, warnings] = train_swing_curve_model(testCase.X(1:12, 1:3), testCase.X(1:12, 4), testCase.Y(1:12));
            testCase.verifyEmpty(warnings);
        end
        function missingTrainingValue_noImplicitRowDeletion(testCase)
            missing_input = testCase.X; missing_input(4, 2) = NaN;
            testCase.verifyError(@() train_apc_model(missing_input, testCase.Y), 'train_apc_model:missingRows');
        end
        function selectedSettingsMismatch_verificationFails(testCase)
            model = train_generic_gpr_model(testCase.X, testCase.Y);
            path = fullfile(testCase.Folder, 'mismatch.mat'); save_train_model(model, path);
            expected = struct('KernelFunction', 'matern32', 'FitMethod', 'exact', ...
                'BasisFunction', 'constant', 'NumObservations', 150);
            report = verify_saved_model(path, model, 'generic', expected);
            testCase.verifyFalse(report.Success);
        end
        function explicitSeed_doeRepeatsExactly(testCase)
            first = create_D_DOE(2, 12, 42); second = create_D_DOE(2, 12, 42);
            testCase.verifyEqual(size(first), [12, 2]); testCase.verifyEqual(first, second);
        end
        function smallQuery_shapDimensionsMatch(testCase)
            model = train_generic_gpr_model(testCase.X(1:12, 1:2), testCase.Y(1:12));
            [~, values] = compute_shap_values(model, testCase.X(1:3, 1:2));
            testCase.verifyEqual(size(values), [3, 2]);
        end
        function tableAndMatrixModels_predictionInputTypeMatches(testCase)
            table_model = train_apc_model(testCase.X, testCase.Y);
            matrix_model = train_generic_gpr_model(testCase.X, testCase.Y);
            testCase.verifyTrue(istable(format_model_input(table_model, testCase.X(1:2, :))));
            testCase.verifyTrue(isnumeric(format_model_input(matrix_model, testCase.X(1:2, :))));
        end
    end
end
