function name = model_kernel_name(kernel)
info = swing_kernel_info(kernel);
if ~isempty(info)
    name = info.Name;
elseif isa(kernel, 'function_handle')
    name = func2str(kernel);
else
    name = char(string(kernel));
end
end
