classdef HomePage < AppPage
    % 起動時の案内。やりたいことから各画面へ進めるようにする。
    properties (Constant)
        CARD_HEIGHT = 74
        BUTTON_WIDTH = 230
        TASKS = {
            'apc',     '1 APC 学習',          '露光APC用のGPRモデル（SIN_TH・SIN_RN・NSG_TH・RESIST_TH の4変数）を学習し、制御用のMATを保存します。'
            'swing',   '2 Swing Curve学習',   'レジスト膜厚に対する線幅の周期変動を学習します。膜厚だけ／下地の説明変数ありを選べます。'
            'generic', '3 汎用回帰学習',      '任意の列でGPR・重回帰・PLSを学習して比べます。'
            'furnace', '4 炉内補間',          'LP-CVDのBoatSlotごとの膜厚・屈折率を、計測済みSlotから補間します（Runごと）。'
            'predict', '5 保存モデルで推定',  '保存したMAT、または学習直後のモデルで、新しいデータの値を推定・評価します。'
            'shap',    '6 SHAP 解析',         '各説明変数が予測へどれだけ効いているか（SHAP）を、別のデータで確認します。'
            'doe',     '7 実験計画作成',      'D最適・I最適・直交表・既存計画への追加と、交絡の確認ができます。'
            'words',   '8 ワードクラウド',    '文章中の単語の出現数を図にします。'}
    end
    methods
        function page = HomePage(app, parent)
            page@AppPage(app, parent);
            count = size(page.TASKS, 1);
            grid = uigridlayout(page.Body, [count + 3, 1], 'Scrollable', 'on');
            grid.RowHeight = [{56, 64}, repmat({page.CARD_HEIGHT}, 1, count), {40}]; grid.Padding = [4, 4, 4, 4];
            edition = '通常版'; if strcmp(app.Edition, 'pro'), edition = 'Pro版'; end
            uilabel(grid, 'Text', sprintf('%s（%s）へようこそ。やりたいことを選んでください。', app.APP_NAME, edition), ...
                'FontSize', 18, 'FontWeight', 'bold');
            AppPage.hint(grid, ['モデルを作る画面（1〜3）は、上のタブを左から「① データを開く → ② 変数を選ぶ → ③ 条件を決めて実行 → ④ 結果を比べて保存」の順に進みます。' ...
                '学習と評価を先に行い、採用するモデルだけを最後にMATへ保存します。すべての処理はこのPC内で行い、データを外部へ送信しません。']);
            for index = 1:count
                card = uipanel(grid); row = uigridlayout(card, [1, 2]); row.ColumnWidth = {page.BUTTON_WIDTH, '1x'};
                key = page.TASKS{index, 1};
                uibutton(row, 'Text', page.TASKS{index, 2}, 'FontSize', 14, 'FontWeight', 'bold', ...
                    'ButtonPushedFcn', @(~, ~) app.selectPage(key));
                uilabel(row, 'Text', page.TASKS{index, 3}, 'WordWrap', 'on');
            end
            row = uigridlayout(grid, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {page.BUTTON_WIDTH, page.BUTTON_WIDTH, '1x'};
            uibutton(row, 'Text', '9 設定を開く', 'ButtonPushedFcn', @(~, ~) app.selectPage('settings'));
            uibutton(row, 'Text', '10 Help（用語・手順）を開く', 'ButtonPushedFcn', @(~, ~) app.selectPage('help'));
            uilabel(row, 'Text', '同梱のサンプルデータは、各学習画面の「サンプルデータを開く」から試せます。', 'WordWrap', 'on');
            notice = app.releaseNotice();
            if ~isempty(notice), page.message(notice); end
            page.message('左のメニュー、または上のボタンから機能を選びます。');
        end
    end
end
