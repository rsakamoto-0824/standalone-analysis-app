function [codes, levels] = encode_categories(source, name, levels)
% 質的変数の列を、水準の番号（1, 2, …）に置き換える。
% levels を省略したときは、空欄以外の値を並べ替えた一覧を水準にする（学習時）。
% levels を渡したときは、その一覧で番号を付ける（推定時）。学習時になかった値は、元ファイルの行番号を示して止める。
column = data_column(source, name);
if any(column.Missing)
    error('encode_categories:missing', '質的変数の列「%s」に空欄があります（元ファイルの行 %s）。', name, ...
        strjoin(string(source.RowNumbers(find(column.Missing, 5))'), ', '));
end
if nargin < 3 || isempty(levels), levels = unique(column.Labels); end
levels = string(levels(:));
[known, codes] = ismember(column.Labels, levels);
if ~all(known)
    row = find(~known, 1);
    error('encode_categories:unknownLevel', '質的変数の列「%s」の値「%s」は、モデルの学習時になかった水準です（元ファイルの行 %d）。', ...
        name, column.Labels(row), source.RowNumbers(row));
end
if numel(levels) < 2, error('encode_categories:levels', '質的変数の列「%s」の水準が1つだけです。2つ以上の値がある列を選んでください。', name); end
codes = double(codes);
end
