function assume_target_release(testCase)
% SHAPの複数行計算（shapley の QueryPoints）は対象リリースだけで使える。
% 開発用の例外で別リリースのテストを実行した場合は、失敗ではなく未実施として扱う。
constants = model_constants();
testCase.assumeTrue(strcmp(version('-release'), constants.REQUIRED_RELEASE), ...
    sprintf('この確認は MATLAB R%s で実行します。', constants.REQUIRED_RELEASE));
end
