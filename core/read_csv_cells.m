function cells = read_csv_cells(path, as_text)
% CSV を、readcell と同じ形の cell 配列で読む（数値は double、文字は char、空欄は missing）。
% as_text = true のときは、数値に見える値も文字のまま返す（WaferId の先頭のゼロなどを失わないため）。
% 配布版（MATLAB Runtime）では readcell・readtable が止まることがあったため、ファイルを直接読む。
% 文字コードは、BOM 付きまたは UTF-8 として正しく読めれば UTF-8、そうでなければ Shift_JIS（Windows の Excel の既定）とする。
% 値は , で区切り、" で囲んだ値の中の , と改行は値の一部、"" は " 1文字として扱う。
if nargin < 2, as_text = false; end
if ~isfile(path), error('read_csv_cells:missing', 'ファイルが見つかりません: %s', path); end
file = fopen(path, 'r'); if file < 0, error('read_csv_cells:open', 'ファイルを開けません: %s', path); end
bytes = fread(file, Inf, '*uint8')'; fclose(file);
text = decodeBytes(bytes);
rows = parseRows(text);
columns = max([cellfun(@numel, rows), 1]);
cells = repmat({missing}, numel(rows), columns);
for row = 1:numel(rows)
    for column = 1:numel(rows{row})
        cells{row, column} = convertValue(rows{row}{column}, as_text);
    end
end
end

function text = decodeBytes(bytes)
UTF8_BOM = uint8([239, 187, 191]);
if numel(bytes) >= 3 && isequal(bytes(1:3), UTF8_BOM)
    text = native2unicode(bytes(4:end), 'UTF-8'); return;
end
text = native2unicode(bytes, 'UTF-8');
% UTF-8 として読めない並びは置き換え文字（U+FFFD）になる。そのときは Shift_JIS として読み直す。
if any(text == char(65533)), text = native2unicode(bytes, 'Shift_JIS'); end
end

function rows = parseRows(text)
% " を含まないファイルは、行と , でまとめて分ける（速い）。" を含むときは1文字ずつ読み、" の中かどうかで区切りと改行を判断する。
if ~contains(text, '"')
    lines = regexp(text, '\r\n|\n|\r', 'split');
    if ~isempty(lines) && isempty(lines{end}), lines(end) = []; end
    rows = cellfun(@(line) strsplit(line, ',', 'CollapseDelimiters', false), lines, 'UniformOutput', false);
    return;
end
rows = {}; fields = {}; field = blanks(0); quoted = false; index = 1; count = numel(text); started = false;
while index <= count
    character = text(index);
    if quoted
        if character == '"'
            if index < count && text(index + 1) == '"', field(end + 1) = '"'; index = index + 1; %#ok<AGROW>
            else, quoted = false; end
        else
            field(end + 1) = character; %#ok<AGROW>
        end
    elseif character == '"'
        quoted = true; started = true;
    elseif character == ','
        fields{end + 1} = field; field = blanks(0); started = true; %#ok<AGROW>
    elseif character == newline || character == char(13)
        if character == char(13) && index < count && text(index + 1) == newline, index = index + 1; end
        fields{end + 1} = field; rows{end + 1} = fields; %#ok<AGROW>
        fields = {}; field = blanks(0); started = false;
    else
        field(end + 1) = character; started = true; %#ok<AGROW>
    end
    index = index + 1;
end
if quoted, error('read_csv_cells:quote', 'CSV の " が閉じていません。ファイルの最後の行を確認してください。'); end
if started || ~isempty(fields), fields{end + 1} = field; rows{end + 1} = fields; end
end

function value = convertValue(field, as_text)
trimmed = strtrim(field);
if isempty(trimmed), value = missing; return; end
if as_text, value = field; return; end
number = str2double(trimmed);
if ~isnan(number) || strcmpi(trimmed, 'NaN')
    value = number;
else
    value = field;
end
end
