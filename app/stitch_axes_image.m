function picture = stitch_axes_image(container, resolution)
% 入れ物（パネル）の中の図を1枚ずつ画像にし、左から順に横へつないだ RGB 画像を返す。
% exportgraphics にパネルを直接渡すと、R2022b では失敗してアプリのウィンドウまで壊れることがあったため、
% 図（UIAxes）だけを書き出してつなぐ。
GAP_PIXELS = 24;
axes_list = findobj(container, 'Type', 'axes');
if isempty(axes_list), error('stitch_axes_image:noChart', '書き出す図がありません。'); end
positions = arrayfun(@(ax) getpixelposition(ax, true), axes_list, 'UniformOutput', false);
[~, order] = sort(cellfun(@(position) position(1), positions)); axes_list = axes_list(order);
images = cell(1, numel(axes_list));
for index = 1:numel(axes_list)
    temporary = [tempname '.png'];
    exportgraphics(axes_list(index), temporary, 'Resolution', resolution);
    images{index} = imread(temporary); delete(temporary);
    if size(images{index}, 3) == 1, images{index} = repmat(images{index}, 1, 1, 3); end
end
background = images{1}(1, 1, :); height = max(cellfun(@(image) size(image, 1), images));
pieces = {};
for index = 1:numel(images)
    image = images{index};
    filler = repmat(background, height - size(image, 1), size(image, 2));
    pieces{end + 1} = [image; filler]; %#ok<AGROW>
    if index < numel(images), pieces{end + 1} = repmat(background, height, GAP_PIXELS); end %#ok<AGROW>
end
picture = [pieces{:}];
end
