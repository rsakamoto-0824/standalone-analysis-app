classdef HelpPage < AppPage
    % Help の画面。用語・操作・公式の関数ヘルプ・手順書への入口をまとめる。
    methods
        function page = HelpPage(app, parent)
            page@AppPage(app, parent);
            % Help は処理を行わないため、下部の状況欄を使わない。
            page.Root.RowHeight = {'1x', 0}; page.Status.Visible = 'off';
            guide = app.resourcePath('docs', 'user-guide', 'procedure-guide.html');
            create_app_help(page.Body, guide, app.Edition);
        end
    end
end
