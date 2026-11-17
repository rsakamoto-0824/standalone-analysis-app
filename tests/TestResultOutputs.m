classdef TestResultOutputs < matlab.unittest.TestCase
    % 進捗の表示、出力の1表へのまとめ、CSVの文字コードを確認する。
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root, 'core')));
        end
    end
    methods (Test)
        function progressShowsPercentElapsedAndRemaining(testCase)
            [fraction, text] = format_progress(3, 12, 30);
            testCase.verifyEqual(fraction, 0.25);
            testCase.verifyEqual(text, '25%（経過 30秒 / 残り 約1分30秒）');
            [~, text] = format_progress(0.2, 12, 10);
            testCase.verifyEqual(text, '1%（経過 10秒）', '始まった直後は残り時間の目安を出さない。');
            [fraction, text] = format_progress(12, 12, 4000);
            testCase.verifyEqual(fraction, 1); testCase.verifyEqual(text, '100%（経過 1時間06分）');
            testCase.verifyEqual(format_progress(5, 0, 1), 0);
            testCase.verifyEqual(format_progress(20, 10, 1), 1);
        end
        function outputsSitNextToTheOriginalColumns(testCase)
            parts = struct('SourceRows', (2:5)', 'InputColumns', {{'膜厚', 'SIN_TH'}}, 'Inputs', [1 10; 2 20; 3 30; 4 40], ...
                'TargetName', 'CD_X', 'Actual', [5; 6; 7; 8], 'Predicted', [4; 6; 9; 8], ...
                'Extra', table([1; 2; 1; 2], 'VariableNames', {'検証分割'}), ...
                'ShapColumns', {{'SHAP_RESIST_TH', 'SHAP_SIN_TH'}}, 'ShapValues', [0.1 0.2; 0.3 0.4]);
            output = combine_model_outputs(parts);
            testCase.verifyEqual(output.Properties.VariableNames, ...
                {'SourceRow', '膜厚', 'SIN_TH', 'CD_X', 'CD_X_予測値', 'CD_X_残差', '検証分割', 'SHAP_RESIST_TH', 'SHAP_SIN_TH'});
            testCase.verifyEqual(output.("CD_X_残差"), [1; 0; -2; 0]);
            testCase.verifyEqual(output.SHAP_SIN_TH, [0.2; 0.4; NaN; NaN], '計算していない行のSHAPは空欄（NaN）。');
            testCase.verifyEqual(output.SourceRow, (2:5)');
        end
        function outputsWithoutActualOrShapAndDuplicateNames(testCase)
            parts = struct('SourceRows', (1:3)', 'InputColumns', {{'予測値', 'B'}}, 'Inputs', [8 1; 3 5; 4 9], 'Predicted', [1; 2; 3]);
            output = combine_model_outputs(parts);
            testCase.verifyEqual(width(output), 4);
            testCase.verifyEqual(numel(unique(output.Properties.VariableNames)), 4, '列名が重複したら番号を付けて区別する。');
            bad = parts; bad.Predicted = [1; 2];
            testCase.verifyError(@() combine_model_outputs(bad), 'combine_model_outputs:rows');
            bad = parts; bad.ShapColumns = {'SHAP_A'}; bad.ShapValues = ones(4, 1);
            testCase.verifyError(@() combine_model_outputs(bad), 'combine_model_outputs:shap');
        end
        function csvStartsWithBomAndRoundTrips(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture()).Folder;
            data = table([1; 2], ["あ"; "い"], 'VariableNames', {'膜厚', '備考'});
            path = fullfile(folder, 'out.csv'); write_result_table(data, path);
            file = fopen(path, 'r'); head = fread(file, 3, '*uint8')'; fclose(file);
            testCase.verifyEqual(head, uint8([239, 187, 191]));
            back = readtable(path, 'VariableNamingRule', 'preserve', 'Encoding', 'UTF-8', 'TextType', 'string');
            testCase.verifyEqual(back.Properties.VariableNames, {'膜厚', '備考'});
            testCase.verifyEqual(back.("備考"), ["あ"; "い"]);
            write_result_table(data, path);
            file = fopen(path, 'r'); bytes = fread(file, Inf, '*uint8')'; fclose(file);
            testCase.verifyNotEqual(bytes(4:6), uint8([239, 187, 191]), '上書きしてもBOMを重ねない。');
            testCase.verifyError(@() write_result_table(data, fullfile(folder, 'out.txt')), 'write_result_table:fileType');
        end
    end
end
