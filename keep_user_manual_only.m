function removed = keep_user_manual_only(guide_folder)
% 通常版に同梱する手順書のフォルダから、利用者向けの user-manual.html と、
% そこから参照するファイル（CSS・JavaScript・画像）以外を削除する。
% Pro 版の機能を説明する手順書（procedure-guide.html・build-guide.html）と、その画像を通常版に含めないため。
% removed：削除したファイル（guide_folder からの相対パス）。
MANUAL = 'user-manual.html';
listing = dir(guide_folder); guide_folder = listing(1).folder;   % 相対パスでも比べられるよう絶対パスにする
text = fileread(fullfile(guide_folder, MANUAL));
referenced = regexp(text, '(?:href|src)="([^"#:]+)"', 'tokens');
referenced = unique([cellfun(@(item) strrep(item{1}, '/', filesep), referenced, 'UniformOutput', false), {MANUAL}]);
files = dir(fullfile(guide_folder, '**', '*'));
files = files(~[files.isdir]); removed = {};
for index = 1:numel(files)
    full_path = fullfile(files(index).folder, files(index).name);
    relative = full_path(numel(guide_folder) + 2:end);
    if ~any(strcmp(relative, referenced)), delete(full_path); removed{end + 1} = strrep(relative, filesep, '/'); end %#ok<AGROW>
end
end
