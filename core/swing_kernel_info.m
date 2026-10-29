function info = swing_kernel_info(kernel)
% functions(handle).workspaceの内部表現には依存しない。
info = [];
if ~isa(kernel, 'function_handle'), return; end
try
    candidate = kernel([], [], 'swingperiodic:info');
    if isstruct(candidate) && isscalar(candidate) && isfield(candidate, 'Name') && ...
            strcmp(candidate.Name, 'swingperiodic') && candidate.Version == 1 && ...
            isfinite(candidate.Period) && candidate.Period > 0 && candidate.ResistScale > 0
        info = candidate;
    end
catch
    % 既存の別カーネルには独自の情報照会を要求しない。
end
end
