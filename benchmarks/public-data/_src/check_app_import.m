function report = check_app_import()
% モデリング前に、同梱CSVとアプリの読込み処理の対応を確認する。
bundle_root = fileparts(fileparts(mfilename('fullpath')));
project_root = fileparts(fileparts(bundle_root));
addpath(fullfile(project_root, 'core'));
catalog = jsondecode(fileread(fullfile(bundle_root, 'catalog.json')));
records = catalog.datasets;
observation_files = 0;
total_rows = 0;
for index = 1:numel(records)
    if iscell(records), item = records{index}; else, item = records(index); end
    folder = fullfile(bundle_root, item.category, item.id);
    if strcmp(item.category, 'causal')
        names = fieldnames(item.profiles);
        file_names = strrep(names, '_csv', '.csv');
    else
        file_names = {item.data_file};
    end
    for file_index = 1:numel(file_names)
        file_name = file_names{file_index};
        source = read_input_data(fullfile(folder, file_name), 1, 1);
        values = extract_numeric_columns(source, source.Headers);
        if strcmp(file_name, item.data_file)
            expected = item.quality;
        else
            expected = item.profiles.(matlab.lang.makeValidName(file_name));
        end
        assert(isequal(size(values), [expected.rows, expected.columns]), ...
            'benchmark:shape', 'CSVの行列数が一致しません: %s / %s', item.id, file_name);
        assert(all(isfinite(values(:))), 'benchmark:finite', ...
            '欠損または非有限値があります: %s / %s', item.id, file_name);
        for column = 1:numel(source.Headers)
            limits = expected.ranges.(source.Headers{column});
            actual = [min(values(:, column)), max(values(:, column))];
            reference = [limits.min, limits.max];
            assert(all(abs(actual - reference) <= 4 * eps(max(abs(reference), 1))), ...
                'benchmark:range', '数値の範囲が一致しません: %s / %s', item.id, source.Headers{column});
        end
        observation_files = observation_files + 1;
        total_rows = total_rows + size(values, 1);
    end
end
report = struct('status', 'passed', 'matlab_release', version('-release'), ...
    'platform', computer, 'datasets', numel(records), ...
    'observation_files', observation_files, 'rows_checked', total_rows, ...
    'scope', 'read_input_data / extract_numeric_columns; header, shape, finite values, min/max', ...
    'modeling_and_causal_scores_run', false);
disp(report);
end
