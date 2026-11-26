function report = check_installer_samples(folder, edition)
% サンプルのフォルダを確かめる。Pro 版はインストーラーに入れるフォルダ（samples/installer/pro）をビルドの前に、
% 通常版は別に配るフォルダ（samples/separate/standard）を配る前やテストで確かめる。
% 「サンプルデータを開く」ボタンが開くブック ProcessInsight_Samples.xlsx と、ボタンが開くシートが必要。
% 通常版には Pro 版だけの機能のサンプル（ワードクラウドの文章、WordCloud・DOE_Existing のシート）を入れない。
% 問題があれば理由を示して止める。report.Files は同梱するファイル、report.Sheets はブックのシート名。
SAMPLE_FILE = 'ProcessInsight_Samples.xlsx';
% 画面の「サンプルデータを開く」が開くシート（ModelingPage.SAMPLE_SHEETS と FurnacePage.SAMPLE_SHEET）。
REQUIRED_SHEETS = {'APC', 'Swing_Base', 'Generic', 'Furnace'};
PRO_ONLY_FILES = {'sample_wordcloud.txt'}; PRO_ONLY_SHEETS = {'WordCloud', 'DOE_Existing'};
if ~isfolder(folder), error('samples:folder', 'サンプルのフォルダが見つかりません: %s', folder); end
entries = dir(folder); entries = entries(~[entries.isdir] & ~startsWith({entries.name}, '.'));
files = {entries.name};
if ~any(strcmp(files, SAMPLE_FILE))
    error('samples:workbook', ['サンプルのフォルダに %s がありません（%s）。「サンプルデータを開く」ボタンはこの名前のブックを開きます。' ...
        '置き換えるときも同じ名前にしてください。'], SAMPLE_FILE, folder);
end
[~, sheets] = read_xlsx_cells(fullfile(folder, SAMPLE_FILE));
missing_sheets = setdiff(REQUIRED_SHEETS, sheets, 'stable');
if ~isempty(missing_sheets)
    error('samples:sheets', '%s に、「サンプルデータを開く」が開くシートがありません: %s（必要なシート: %s）', ...
        SAMPLE_FILE, strjoin(missing_sheets, ', '), strjoin(REQUIRED_SHEETS, ', '));
end
for index = 1:numel(REQUIRED_SHEETS)
    try
        read_input_data(fullfile(folder, SAMPLE_FILE), REQUIRED_SHEETS{index}, 1);
    catch err
        error('samples:sheetContent', '%s のシート「%s」を読めません（1行目を列名として読みます）: %s', SAMPLE_FILE, REQUIRED_SHEETS{index}, err.message);
    end
end
if strcmp(edition, 'standard')
    pro_files = intersect(files, PRO_ONLY_FILES); pro_sheets = intersect(sheets, PRO_ONLY_SHEETS);
    if ~isempty(pro_files) || ~isempty(pro_sheets)
        error('samples:proOnly', '通常版のサンプルに、Pro 版だけの機能のサンプルがあります: %s', strjoin([pro_files, pro_sheets], ', '));
    end
end
report = struct('Folder', folder, 'Files', {files}, 'Sheets', {sheets});
end
