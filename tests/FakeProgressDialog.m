classdef FakeProgressDialog < handle
    % テスト用の進捗バーの代わり。uiprogressdlg の CancelRequested はコードから変えられないため、
    % 途中停止の受け取りを確かめるときに使う。
    properties
        Indeterminate = 'on'
        Value = 0
        Message = ''
        CancelRequested = false
    end
end
