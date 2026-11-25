function [words, counts] = create_wordCloud(text, excluded)
% 文章を区切って単語ごとの出現数を数える（小文字にそろえ、1文字の語は除く）。
% excluded（省略可）に入れた語は数えない（小文字で比べる。例：english_stop_words()）。
if nargin < 2, excluded = {}; end
if ~(ischar(text) || isstring(text)) || isempty(text)
    error('create_wordCloud:invalidText', 'テキストを入力してください。');
end
text = char(text);
delimiters = {' ', '　', ',', '、', '。', '.', '!', '?', '！', '？', newline, char(13), char(9)};
tokens = strsplit(text, delimiters);
tokens = lower(tokens(~cellfun('isempty', tokens)));
[words, ~, ic] = unique(tokens);
if isempty(ic)
    counts = [];
else
    counts = accumarray(ic(:), 1);
end
keep = cellfun(@numel, words) > 1 & ~ismember(words, lower(strtrim(cellstr(string(excluded)))));
words = words(keep);
counts = counts(keep);
if isempty(words)
    error('create_wordCloud:noWords', '有効な単語が見つかりませんでした。テキストを確認してください。');
end
words = words(:);
counts = counts(:);
end
