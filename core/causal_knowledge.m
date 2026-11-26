function knowledge = causal_knowledge(names, rules)
% 因果探索の事前の知識（前もって分かっている因果）を、列×列の行列にまとめる。
%   rules：n×3 の cell {元の列, 種類, 先の列}。種類は次のどれか。
%     'forbidden' 元 → 先 の向きはあり得ない（逆向きは残る）
%     'none'      元 と 先 の間に因果はない（どちらの向きもあり得ない）
%     'required'  元 → 先 の因果がある（推定で必ず残す）
% 戻り値：Forbidden（行→列の向きがあり得ないなら true）、Required（行→列の因果があるなら true）。
% 選んだ列にない列名、同じ列どうし、矛盾する指定（ある と あり得ない、両向きの「ある」、「ある」の循環）は止める。
count = numel(names); names = cellstr(string(names(:)'));
knowledge = struct('Forbidden', false(count), 'Required', false(count));
if nargin < 2 || isempty(rules), return; end
if size(rules, 2) ~= 3, error('causal:knowledgeShape', '事前の知識は {元, 種類, 先} の3列で指定してください。'); end
for row = 1:size(rules, 1)
    from = find(strcmp(names, char(string(rules{row, 1}))), 1); to = find(strcmp(names, char(string(rules{row, 3}))), 1);
    kind = char(string(rules{row, 2}));
    if isempty(from) || isempty(to)
        error('causal:knowledgeColumn', '事前の知識 %d 行目の列（%s → %s）が、選んだ列にありません。', row, string(rules{row, 1}), string(rules{row, 3}));
    end
    if from == to, error('causal:knowledgeSelf', '事前の知識 %d 行目は、元と先が同じ列です（%s）。', row, names{from}); end
    switch kind
        case 'forbidden', knowledge.Forbidden(from, to) = true;
        case 'none', knowledge.Forbidden(from, to) = true; knowledge.Forbidden(to, from) = true;
        case 'required', knowledge.Required(from, to) = true;
        otherwise, error('causal:knowledgeKind', '事前の知識の種類は forbidden・none・required のどれかにしてください（%d 行目: %s）。', row, kind);
    end
end
[from, to] = find(knowledge.Required & knowledge.Forbidden, 1);
if ~isempty(from)
    error('causal:knowledgeConflict', '「%s → %s」を、因果がある とも あり得ない とも指定しています。どちらかを消してください。', names{from}, names{to});
end
[from, to] = find(knowledge.Required & knowledge.Required', 1);
if ~isempty(from)
    error('causal:knowledgeConflict', '「%s」と「%s」の因果を、両方の向きで「ある」と指定しています。どちらかの向きにしてください。', names{from}, names{to});
end
% 「ある」の向きをたどって元の列へ戻る（循環する）と、因果の順序が決められない。
cycle = findCycle(knowledge.Required);
if ~isempty(cycle)
    error('causal:knowledgeCycle', '「因果がある」の指定が循環しています（%s）。どこかの向きを見直してください。', strjoin(names([cycle, cycle(1)]), ' → '));
end
end

function cycle = findCycle(required)
% 有向グラフの循環を1つ探す（深さ優先）。なければ空。
count = size(required, 1); state = zeros(1, count); parent = zeros(1, count); cycle = [];
for start = 1:count
    if state(start) == 0, visit(start); end
    if ~isempty(cycle), return; end
end
    function visit(node)
        state(node) = 1;
        for next = find(required(node, :))
            if ~isempty(cycle), return; end
            if state(next) == 1
                path = node; while path(1) ~= next, path = [parent(path(1)), path]; end %#ok<AGROW> 循環の長さは事前に分からない
                cycle = path; return;
            elseif state(next) == 0
                parent(next) = node; visit(next);
            end
        end
        state(node) = 2;
    end
end
