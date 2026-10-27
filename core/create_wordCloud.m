function [words, counts] = create_wordCloud(text)
if ~(ischar(text) || isstring(text)) || isempty(text)
    error('create_wordCloud:invalidText', 'テキストを入力してください。');
end
text = char(text);
delimiters = {' ', '　', ',', '、', '。', '.', '!', '?', '！', '？', char(10), char(13), char(9)};
tokens = strsplit(text, delimiters);
tokens = lower(tokens(~cellfun('isempty', tokens)));
[words, ~, ic] = unique(tokens);
if isempty(ic)
    counts = [];
else
    counts = accumarray(ic(:), 1);
end
keep = cellfun(@numel, words) > 1;
words = words(keep);
counts = counts(keep);
if isempty(words)
    error('create_wordCloud:noWords', '有効な単語が見つかりませんでした。テキストを確認してください。');
end
words = words(:);
counts = counts(:);
end
