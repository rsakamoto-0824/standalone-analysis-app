function results = run_tests(edition)
% 単体テストを実行する。失敗があれば止める。
%   run_tests()            すべてのテスト（開発での確認）
%   run_tests('pro')       Pro 版のビルド用：すべてのテスト
%   run_tests('standard')  通常版のビルド用：Pro 版だけの機能のテスト（TestTags が 'Pro'）を除く
% 通常版の exe には Pro 版だけの機能のファイルを入れないため、そのテストは通常版のビルドでは意味がない。
if nargin < 1, edition = 'all'; end
if ~any(strcmp(edition, {'all', 'standard', 'pro'})), error('run_tests:edition', 'all・standard・pro のどれかを指定してください。'); end
PRO_TAG = 'Pro';
project_root = setup_paths();
require_r2025b();
check_model_contract();
suite = matlab.unittest.TestSuite.fromFolder(fullfile(project_root, 'tests'), 'IncludingSubfolders', true);
if strcmp(edition, 'standard')
    suite = suite.selectIf(~matlab.unittest.selectors.HasTag(PRO_TAG));
    fprintf('通常版のビルド用に、Pro 版だけの機能のテストを除いた %d 件を実行します。\n', numel(suite));
end
results = run(suite);
disp(table(results));
assertSuccess(results);
end
