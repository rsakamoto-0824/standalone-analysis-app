classdef TestEditionAndDisplay < matlab.unittest.TestCase
    % 文字の大きさの設定と、版ごとの Help の内容を確認する。
    methods (TestClassSetup)
        function paths(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root)); setup_paths();
        end
    end
    methods (Test)
        function fontSizeIsSavedAndValidated(testCase)
            defaults = app_settings('defaults'); testCase.verifyEqual(defaults.FontSize, 12);
            folder = tempname; mkdir(folder); cleanup = onCleanup(@() rmdir(folder, 's'));
            path = fullfile(folder, 'settings.json'); proposed = defaults; proposed.SaveFolder = folder;
            % 文字の大きさを持たない以前の設定ファイルは、標準の12として読む。
            written = app_settings('save', path, rmfield(proposed, 'FontSize')); testCase.verifyEqual(written.FontSize, 12);
            proposed.FontSize = 16; app_settings('save', path, proposed);
            testCase.verifyEqual(app_settings('load', path).FontSize, 16);
            for invalid = {7, 21, 12.5, 'large'}
                proposed.FontSize = invalid{1};
                testCase.verifyError(@() app_settings('save', path, proposed), 'settings:fontSize');
            end
        end
        function fontScalingKeepsRatiosAndDoesNotAccumulate(testCase)
            window = uifigure('Visible', 'off'); cleanup = onCleanup(@() delete(window));
            grid = uigridlayout(window, [3, 1]);
            normal = uilabel(grid, 'Text', '標準'); title_label = uilabel(grid, 'Text', '見出し', 'FontSize', 18);
            ax = uiaxes(grid); title(ax, '題名'); marker = text(ax, 0.5, 0.5, '注記', 'FontSize', 9);
            apply_app_theme(window, 'ライト', 16); apply_app_theme(window, 'ライト', 16);
            testCase.verifyEqual([normal.FontSize, title_label.FontSize, marker.FontSize], [16, 24, 12]);
            % 題名は軸の文字に合わせて自動で変わる（個別に固定しない）。
            testCase.verifyEqual(ax.Title.FontSize, ax.FontSize * ax.TitleFontSizeMultiplier, 'AbsTol', 1e-9);
            apply_app_theme(window, 'ダーク', 12);
            testCase.verifyEqual([normal.FontSize, title_label.FontSize, marker.FontSize], [12, 18, 9]);
            % 後から作った部品も、作成時の大きさを基準に同じ比率で変わる。
            added = uilabel(grid, 'Text', '追加'); apply_app_theme(window, 'ライト', 9);
            testCase.verifyEqual([added.FontSize, normal.FontSize, title_label.FontSize], [9, 9, 13.5]);
            % 一部の部品だけ配色を直すとき（大きさの指定なし）は、文字の大きさを変えない。
            apply_app_theme(normal, 'ダーク'); testCase.verifyEqual(normal.FontSize, 9);
        end
        function standardHelpOmitsProOnlyDescriptions(testCase)
            [terms, operations, buttons] = TestEditionAndDisplay.help('standard');
            pro_words = {'swingperiodic', '周期カーネル', '拡張実験計画', '拡張 D最適', '残差診断', 'Swing Curve近似', '正規性検定', 'Pro版', 'Pro 版', '既存＋追加'};
            texts = [terms(:); operations(:); buttons(:)];
            for index = 1:numel(pro_words)
                testCase.verifyFalse(any(contains(texts, pro_words{index})), pro_words{index});
            end
            testCase.verifyFalse(any(contains(buttons, {'daugment', 'lillietest', 'ビルド・利用手順書'})));
            testCase.verifyTrue(any(strcmp(terms(:, 1), 'ランダムフォレスト / バギング木')));
            testCase.verifyTrue(any(contains(buttons, 'fitrensemble')));
            testCase.verifyEqual(numel(unique(terms(:, 1))), size(terms, 1), '用語が重複しています。');
        end
    end
    % Pro 版だけの機能のテスト。通常版のビルド（run_tests('standard')）では実行しない。
    methods (Test, TestTags = {'Pro'})
        function proHelpKeepsProDescriptions(testCase)
            [terms, operations, buttons] = TestEditionAndDisplay.help('pro');
            testCase.verifyTrue(all(ismember({'swingperiodic', '拡張実験計画', '近似残差', '通常版 / Pro版'}, terms(:, 1))));
            testCase.verifyTrue(any(contains(operations, '残差診断（Pro版）')));
            testCase.verifyTrue(any(contains(buttons, 'daugment')) && any(contains(buttons, 'ビルド・利用手順書')));
            testCase.verifyEqual(numel(unique(terms(:, 1))), size(terms, 1), '用語が重複しています。');
        end
    end
    methods (Static, Access = private)
        function [terms, operations, buttons] = help(edition)
            window = uifigure('Visible', 'off'); cleanup = onCleanup(@() delete(window));
            create_app_help(window, {'user-manual.html', 'procedure-guide.html'}, edition);
            terms = findobj(window, 'Type', 'uitable').Data;
            areas = findobj(window, 'Type', 'uitextarea'); operations = {};
            for index = 1:numel(areas), operations = [operations; areas(index).Value(:)]; end %#ok<AGROW>
            labels = findobj(window, 'Type', 'uilabel'); buttons = [{labels.Text}'; {findobj(window, 'Type', 'uibutton').Text}'];
        end
    end
end
