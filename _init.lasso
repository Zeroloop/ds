<?lassoscript
with file in (:
	'sequential.lasso',
	'tables.lasso',
	'activerow.lasso',
	'ds.lasso',
	'ds_row.lasso',
	'ds_result.lasso',
	'statement.lasso'
) do  {
	local(s) = micros
	handle => {
		stdoutnl(
			error_msg + ' (' + ((micros - #s) * 0.000001)->asstring(-precision=3) + ' seconds)'
		)
	}
	
	stdout('\t' + #file + ' - ')

	// allow relative includes
	.filename !>> '/LassoApps/' && .filename !>> 'zip:' && .filename != '/_init.lasso' 
	? library(include_path + #file)
	| lassoapp_include(#file)
	
}	
?>