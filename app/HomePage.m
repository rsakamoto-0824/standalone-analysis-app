classdef HomePage < AppPage
    % 起動時の案内。やりたいことから各画面へ進めるようにする。
    properties (Constant)
        CARD_HEIGHT = 74
        BUTTON_WIDTH = 230
        % {画面のキー, 説明}。名前と番号は AnalysisController.menuTitles から取る（版によって番号が変わるため）。
        TASKS = {
            'apc',     '露光APC用のGPRモデル（SIN_TH・SIN_RN・NSG_TH・RESIST_TH の4変数）を学習し、制御用のMATを保存します。'
            'swing',   'レジスト膜厚に対する線幅の周期変動を学習します。膜厚だけ／下地の説明変数ありを選べます。'
            'generic', '任意の列でGPR・重回帰・PLS・ランダムフォレスト・バギング木を学習して比べます。Permutation Importance・VIPで変数の効き方も確認できます。'
            'furnace', 'LP-CVDのBoatSlotごとの膜厚・屈折率を、計測済みSlotから補間します（Runごと）。'
            'predict', '保存したMAT、または学習直後のモデルで新しいデータを推定し、どのモデルでもSHAPの分布と依存図を確認します。'
            'sobol',   'Excel / CSV のデータ（または保存モデル）で、各入力が出力のばらつきにどれだけ効くかを、Sobol感度解析（1次・全効果）で調べます。'
            'causal',  'データの列どうしの因果の向きの候補を、PCアルゴリズムまたはDirectLiNGAMで推定し、グラフで表示します。'
            'bayes',   'グループ（ロット・装置など）ごとの回帰係数を、全体の傾向に引き寄せて推定する階層ベイズモデルを当てはめます。'
            'copula',  'データの列どうしの関係（またはご自分で指定した分布と順位相関）を保った乱数を、コピュラで作ります。'
            'doe',     'D最適・I最適・直交表の計画と、D効率・I基準などの評価指標、交絡の確認ができます。'
            'words',   '文章中の単語の出現数を図にします。形や色を変えられます。'}
        PRO_DOE_TEXT = 'D最適・I最適・直交表・既存計画への追加と、D効率・I基準などの評価指標、交絡の確認ができます。'
        % Pro 版だけの画面（通常版のホームには出さない）。
        PRO_GENERIC_TEXT = '任意の列でGPR（加法カーネル・質的変数にも対応）・重回帰・PLS・ランダムフォレスト・バギング木・EBM・XGBoost・LightGBM・CatBoostを学習して比べます。ハイパーパラメータの探索と、Permutation Importance・VIPもできます。'
    end
    methods
        function page = HomePage(app, parent)
            page@AppPage(app, parent);
            titles = AnalysisController.menuTitles(app.Edition);
            tasks = page.TASKS(isfield(titles, page.TASKS(:, 1)), :);
            count = size(tasks, 1);
            grid = uigridlayout(page.Body, [count + 3, 1], 'Scrollable', 'on');
            grid.RowHeight = [{56, 64}, repmat({page.CARD_HEIGHT}, 1, count), {40}]; grid.Padding = [4, 4, 4, 4];
            edition = '通常版'; if strcmp(app.Edition, 'pro'), edition = 'Pro版'; end
            uilabel(grid, 'Text', sprintf('%s（%s）へようこそ。やりたいことを選んでください。', app.APP_NAME, edition), ...
                'FontSize', 18, 'FontWeight', 'bold');
            AppPage.hint(grid, ['モデルを作る画面（1〜3）は、上のタブを左から「① データを開く → ② 変数を選ぶ → ③ 条件を決めて実行 → ④ 結果を比べて保存」の順に進みます。①では読み込んだデータの傾向をグラフで確認できます。' ...
                '学習と評価を先に行い、採用するモデルだけを最後にMATへ保存します。すべての処理はこのPC内で行い、データを外部へ送信しません。']);
            for index = 1:count
                card = uipanel(grid); row = uigridlayout(card, [1, 2]); row.ColumnWidth = {page.BUTTON_WIDTH, '1x'};
                key = tasks{index, 1}; text = tasks{index, 2};
                % 既存の計画への追加（拡張計画）は Pro 版だけ。
                if strcmp(key, 'doe') && strcmp(app.Edition, 'pro'), text = page.PRO_DOE_TEXT; end
                if strcmp(key, 'generic') && strcmp(app.Edition, 'pro'), text = page.PRO_GENERIC_TEXT; end
                uibutton(row, 'Text', titles.(key), 'FontSize', 14, 'FontWeight', 'bold', ...
                    'ButtonPushedFcn', @(~, ~) app.selectPage(key));
                uilabel(row, 'Text', text, 'WordWrap', 'on');
            end
            row = uigridlayout(grid, [1, 3]); row.Padding = [0, 0, 0, 0]; row.ColumnWidth = {page.BUTTON_WIDTH, page.BUTTON_WIDTH, '1x'};
            uibutton(row, 'Text', [AnalysisController.settingsTitle(app.Edition) 'を開く'], 'ButtonPushedFcn', @(~, ~) app.selectPage('settings'));
            uibutton(row, 'Text', [AnalysisController.helpTitle(app.Edition) '（用語・手順）を開く'], 'ButtonPushedFcn', @(~, ~) app.selectPage('help'));
            sample_text = '同梱のサンプルデータは、各学習画面の「サンプルデータを開く」から試せます。';
            if ~strcmp(app.Edition, 'pro'), sample_text = 'サンプルデータ（別に配るブック）は、各学習画面の「サンプルデータを開く」で選んで試せます。'; end
            uilabel(row, 'Text', sample_text, 'WordWrap', 'on');
            notice = app.releaseNotice();
            if ~isempty(notice), page.message(notice); end
            page.message('左のメニュー、または上のボタンから機能を選びます。');
        end
    end
end
