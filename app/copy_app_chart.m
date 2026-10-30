function copied_name = copy_app_chart(charts, names)
% 表示中の図を優先し、表の表示中などはコピー対象を選択する。
copied_name = '';
valid = cellfun(@(chart) isgraphics(chart) && ...
    (~isa(chart, 'matlab.ui.control.UIAxes') || ~isempty(chart.Children)), charts);
charts = charts(valid); names = names(valid);
if isempty(charts), error('AnalysisApp:noChart', 'コピーするグラフがありません。先に解析を実行してください。'); end
visible = find(cellfun(@isDisplayed, charts));
if numel(visible) == 1
    choice = visible;
elseif numel(charts) == 1
    choice = 1;
else
    [choice, accepted] = listdlg('ListString', names, 'SelectionMode', 'single', 'PromptString', 'コピーするグラフ');
    if ~accepted, return; end
end
chart = charts{choice}; container = chart.Parent;
while ~isempty(container)
    if isa(container, 'matlab.ui.container.Tab'), container.Parent.SelectedTab = container; end
    if isa(container, 'matlab.ui.Figure'), break; end
    container = container.Parent;
end
drawnow;
background = [1, 1, 1]; container = chart.Parent;
while ~isempty(container)
    if isprop(container, 'BackgroundColor') && isnumeric(container.BackgroundColor)
        background = container.BackgroundColor; break;
    end
    if isa(container, 'matlab.ui.Figure'), background = container.Color; break; end
    container = container.Parent;
end
copygraphics(chart, 'ContentType', 'image', 'Resolution', 150, 'BackgroundColor', background);
copied_name = names{choice};
end

function displayed = isDisplayed(chart)
displayed = true; container = chart;
while ~isempty(container)
    if isprop(container, 'Visible') && strcmp(container.Visible, 'off')
        displayed = false; return;
    end
    if isa(container, 'matlab.ui.container.Tab') && ~isequal(container.Parent.SelectedTab, container)
        displayed = false; return;
    end
    if isa(container, 'matlab.ui.Figure'), break; end
    container = container.Parent;
end
end
