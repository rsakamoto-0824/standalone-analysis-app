function [cells, sheets] = read_xlsx_cells(path, sheet)
% Excel（.xlsx）の1シートを、readcell と同じ形の cell 配列で読む（数値は double、文字は char、空欄は missing）。
%   [~, sheets] = read_xlsx_cells(path)          シート名の一覧だけを返す
%   [cells, sheets] = read_xlsx_cells(path, sheet) sheet はシート名または番号
% 配布版（MATLAB Runtime）では readcell・sheetnames が
% 「Implementation Error: cannot call this method before validating "Filename"」で止まることがあったため、
% .xlsx（中身は zip に入った XML）を直接読む。Excel 本体は使わない。
% 数式のセルは、保存時に計算された値を読む。日付の書式のセルは、Excel の日付の数値（シリアル値）のまま返す。
if nargin < 2, sheet = []; end
if ~isfile(path), error('read_xlsx_cells:missing', 'ファイルが見つかりません: %s', path); end
folder = tempname; mkdir(folder); cleanup = onCleanup(@() removeFolder(folder));
try
    unzip(path, folder);
catch err
    error('read_xlsx_cells:format', 'Excel（.xlsx）として読めません。ファイルが壊れていないか、Excel で開いて保存し直して確かめてください。詳細: %s', err.message);
end
workbook = readText(fullfile(folder, 'xl', 'workbook.xml'));
relations = readText(fullfile(folder, 'xl', '_rels', 'workbook.xml.rels'));
sheet_tags = regexp(workbook, '<sheet\s[^>]*?/?>', 'match');
if isempty(sheet_tags), error('read_xlsx_cells:noSheet', 'Excel のファイルにシートがありません。'); end
sheets = cellfun(@(tag) decodeXml(attribute(tag, 'name')), sheet_tags, 'UniformOutput', false);
cells = {};
if isempty(sheet), return; end
if isnumeric(sheet)
    if sheet < 1 || sheet > numel(sheets) || sheet ~= round(sheet), error('read_xlsx_cells:sheet', 'シート番号 %g がありません（1〜%d）。', sheet, numel(sheets)); end
    position = sheet;
else
    position = find(strcmp(sheets, char(sheet)), 1);
    if isempty(position), error('read_xlsx_cells:sheet', 'シート「%s」が見つかりません。', char(sheet)); end
end
relation_id = attribute(sheet_tags{position}, 'r:id');
target = '';
for tag = regexp(relations, '<Relationship\s[^>]*?/?>', 'match')
    if strcmp(attribute(tag{1}, 'Id'), relation_id), target = attribute(tag{1}, 'Target'); break; end
end
if isempty(target), error('read_xlsx_cells:format', 'シート「%s」の場所が見つかりません。', sheets{position}); end
target = strrep(target, '\', '/');
if startsWith(target, '/'), sheet_path = fullfile(folder, target(2:end)); else, sheet_path = fullfile(folder, 'xl', target); end
shared = sharedStrings(fullfile(folder, 'xl', 'sharedStrings.xml'));
cells = sheetCells(readText(sheet_path), shared);
end

function cells = sheetCells(xml, shared)
% <c r="B3" t="s"><v>0</v></c> の形のセルを、行・列の位置へ並べる。
data = regexp(xml, '<sheetData[^>]*>(.*)</sheetData>', 'tokens', 'once');
if isempty(data), cells = cell(0, 0); return; end
% 選択肢の中のかっこは MATLAB の tokens で返らないことがあるため、セル全体を取り出してから属性と中身に分ける。
matches = regexp(data{1}, '<c\s[^>]*?(?:/>|>.*?</c>)', 'match');
count = numel(matches); rows = zeros(count, 1); columns = zeros(count, 1); values = cell(count, 1);
for index = 1:count
    attributes = regexp(matches{index}, '^<c\s([^>]*?)/?>', 'tokens', 'once'); attributes = attributes{1};
    body = regexp(matches{index}, '^<c\s[^>]*>(.*)</c>$', 'tokens', 'once'); if isempty(body), body = ''; else, body = body{1}; end
    [rows(index), columns(index)] = cellPosition(attribute(attributes, 'r'));
    values{index} = cellValue(attribute(attributes, 't'), body, shared);
end
if count == 0, cells = cell(0, 0); return; end
% 値のあるセルの範囲だけを並べる（書式だけの空のセルは数えない）。
% readcell と同じく、先頭の空の行・列は詰める（以前からの「ヘッダー行」の数え方を変えないため）。
filled = ~cellfun(@(value) isscalar(value) && ismissing(value), values);
if ~any(filled), cells = cell(0, 0); return; end
top = min(rows(filled)); left = min(columns(filled));
cells = repmat({missing}, max(rows(filled)) - top + 1, max(columns(filled)) - left + 1);
for index = find(filled)'
    cells{rows(index) - top + 1, columns(index) - left + 1} = values{index};
end
end

function value = cellValue(type, body, shared)
value = missing;
raw = regexp(body, '<v>(.*?)</v>', 'tokens', 'once');
switch type
    case 's'
        if ~isempty(raw), value = shared{str2double(raw{1}) + 1}; end
    case 'inlineStr'
        value = richText(body);
    case 'str'
        if ~isempty(raw), value = decodeXml(raw{1}); end
    case 'b'
        if ~isempty(raw), value = strcmp(raw{1}, '1'); end
    case 'e'
        value = missing;
    otherwise
        if ~isempty(raw)
            value = str2double(raw{1});
            if isnan(value), value = decodeXml(raw{1}); end
        end
end
if ischar(value) && isempty(value), value = missing; end
end

function strings = sharedStrings(path)
strings = {};
if ~isfile(path), return; end
items = regexp(readText(path), '<si>(.*?)</si>', 'tokens');
strings = cellfun(@(item) richText(item{1}), items, 'UniformOutput', false);
end

function text = richText(xml)
% 書式つきの文字（<r><t>…</t></r> の並び）は、<t> の中身をつなぐ。ふりがな（<rPh>…</rPh>）は除く。
% MATLAB の正規表現では \b が単語の区切りでなくバックスペースになるため、属性の有無で書き分ける。
xml = regexprep(xml, '<rPh(?:\s[^>]*)?>.*?</rPh>', '');
parts = regexp(xml, '<t(?:\s[^>]*)?>(.*?)</t>', 'tokens');
text = decodeXml(strjoin(cellfun(@(part) part{1}, parts, 'UniformOutput', false), ''));
end

function [row, column] = cellPosition(reference)
letters = upper(regexp(reference, '^[A-Za-z]+', 'match', 'once')); digits = regexp(reference, '\d+$', 'match', 'once');
if isempty(letters) || isempty(digits), error('read_xlsx_cells:format', 'セルの位置「%s」を読めません。', reference); end
column = 0;
for character = letters, column = column * 26 + (double(character) - double('A') + 1); end
row = str2double(digits);
end

function value = attribute(tag, name)
value = regexp(tag, ['(?:^|\s)' regexptranslate('escape', name) '="([^"]*)"'], 'tokens', 'once');
if isempty(value), value = ''; else, value = value{1}; end
end

function text = decodeXml(text)
text = regexprep(text, '&#x([0-9A-Fa-f]+);', '${char(hex2dec($1))}');
text = regexprep(text, '&#(\d+);', '${char(str2double($1))}');
text = strrep(strrep(strrep(strrep(strrep(text, '&lt;', '<'), '&gt;', '>'), '&quot;', '"'), '&apos;', ''''), '&amp;', '&');
text = regexprep(text, '_x000D_', '');
end

function text = readText(path)
if ~isfile(path), error('read_xlsx_cells:format', 'Excel の中のファイルが見つかりません: %s', path); end
file = fopen(path, 'r', 'n', 'UTF-8'); cleanup = onCleanup(@() fclose(file));
text = fread(file, Inf, '*char')';
end

function removeFolder(folder)
if isfolder(folder), rmdir(folder, 's'); end
end
