function findings = check_sources()
% 構文・静的解析のみ。R2025b での実行テストを代替しない。
project_root = setup_paths();
files = dir(fullfile(project_root, '**', '*.m'));
findings = cell(0, 3);
for index = 1:numel(files)
    fullName = fullfile(files(index).folder, files(index).name);
    messages = checkcode(fullName, '-id');
    for item = 1:numel(messages)
        findings(end + 1, :) = {fullName, messages(item).line, messages(item).message}; %#ok<AGROW>
    end
end
findings = cell2table(findings, 'VariableNames', {'File', 'Line', 'Message'});
disp(findings);
end
