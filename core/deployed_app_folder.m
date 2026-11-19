function folder = deployed_app_folder()
% 配布版（exe）が置かれているフォルダ。ソースから実行している場合や、分からない場合は ''。
% Windows の配布版では、起動時に exe のフォルダが環境変数 PATH の先頭に加わるため、そこから求める。
folder = '';
if ~isdeployed || ~ispc, return; end
[status, result] = system('path');
if status ~= 0, return; end
token = regexpi(result, 'Path=(.*?);', 'tokens', 'once');
if ~isempty(token) && isfolder(strtrim(token{1})), folder = strtrim(token{1}); end
end
