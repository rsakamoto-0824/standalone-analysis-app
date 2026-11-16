classdef ModelStore < handle
    % アプリの起動中に学習・読込みしたモデルの一覧。画面をまたいで共有する。
    properties (SetAccess = private)
        Entries = struct('Id', {}, 'Label', {}, 'Model', {}, 'Kind', {}, 'Record', {})
    end
    events
        Changed
    end
    methods
        function id = add(store, model, label, kind, record)
            if nargin < 5, record = []; end
            id = numel(store.Entries) + 1;
            store.Entries(end + 1) = struct('Id', id, 'Label', sprintf('%d: %s', id, label), ...
                'Model', model, 'Kind', kind, 'Record', record);
            notify(store, 'Changed');
        end
        function entry = get(store, id)
            if ~isnumeric(id) || ~isscalar(id) || id < 1 || id > numel(store.Entries) || id ~= round(id)
                error('ModelStore:missing', '選択したモデルが見つかりません。モデルを選び直してください。');
            end
            entry = store.Entries(id);
        end
        function setRecord(store, id, record)
            store.get(id); store.Entries(id).Record = record;
        end
        function total = count(store)
            total = numel(store.Entries);
        end
        function [labels, ids] = list(store)
            labels = {store.Entries.Label}; ids = [store.Entries.Id];
        end
    end
end
