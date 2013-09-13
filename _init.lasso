<?lassoscript

local(root) = {}->callsite_file->split('/')->removelast & join('/') + '/'


with path in (:
	'sequential.lasso',
	'tables.lasso',
	'activerow.lasso',
	'ds.lasso',
	'ds_row.lasso',
	'ds_result.lasso',
	'statement.lasso'
) do protect => {
	local(s) = micros
	handle => {
		stdoutnl(
			error_msg + ' (' + ((micros - #s) * 0.000001)->asstring(-precision=3) + ' seconds)'
		)
	}
	stdout('\t' + #path + ' - ')
	sourcefile(file_read(#root+#path)->asstring,#path,false,false)()
	
	//lassoapp_include(#path)
}
stdoutnl('\tdone')

?>