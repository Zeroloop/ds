<?lassoscript
//============================================================================
//
//	result handles
//
//............................................................................

define result					=> thread_var_get(::__ds_results)
define result_push(p::any) 		=> thread_var_push(::__ds_results,#p)
define result_pop 				=> thread_var_pop(::__ds_results)
define result(setnum::integer)	=> ds_result(#setnum)

//============================================================================
//
//	ds_result
//
//............................................................................

define ds_result => type {
	data 
		public index::trait_searchable,
		public cols::trait_foreach,
		public rows::staticarray,
		public found::integer=0,
		public affected::integer=0,
		public num::integer=0,
		
		private error::staticarray=(:0,'',''),
		private dsinfo,	
		private dsrows

//---------------------------------------------------------------------------------------
//
//	oncreate sigs
//
//---------------------------------------------------------------------------------------

	public oncreate(
		set::staticarray,
		ds::dsinfo,
		error::staticarray,
		num::integer
	) => {
		.dsinfo = #ds
		.oncreate(#set,#error,#num)
	}

	public oncreate(
		set::staticarray,		
		error::staticarray,
		num::integer

	) => {
	
		local(
			index 		= hashtable,
			rows 		= #set->get(INLINE_RESULTROWS_POS),
			found 		= #set->get(INLINE_FOUNDCOUNT_POS),
			affected 	= 0,
			cols 		= array,
			i = 1,
			col
		)
		
		
		#set->get(INLINE_COLUMNINFO_POS)->foreach => {
			#cols->insert(#col := #1->get(INLINE_COLINFO_NAME_POS))
			#index->insert(#col = #i++)
		}

		#cols = #cols->asstaticarray
		
		.'cols'			= #cols
		.'index'		= #index
		.'rows' 		= #rows
		.'found'		= #found
		.'affected' 	= #affected
		.'error' 		= #error
		.'num' 			= #num
			
	}

	public oncreate(
		index::trait_searchable,
		cols::trait_foreach,
		rows::staticarray,
		found::integer=0,
		affected::integer=0,
		error::staticarray=.error_current,
		num::integer=0
	) => {
		.'cols'			= #cols
		.'index'		= #index
		.'rows' 		= #rows
		.'found'		= #found
		.'affected' 	= #affected
		.'error' 		= #error
		.'num' 			= #num
	}
	
	public oncreate => {	
		//	Support standard inlines
		local(set) = (inline_scopeGet ? inline_scopeGet->find(::currentset))
		#set->size ? .oncreate(#set,.error_current) 
		.'error' = .error_current
	}

	public oncreate(num::integer) => {	
		//	Support standard inlines
		local(
			scope = inline_scopeget,
			set = #scope ? #scope->find(::currentinline)->dsinfo->getset(#num)
		)
		#set->size ? .oncreate(#set,.error_current) 

		.'error' = .error_current
		.'num'	 = #num
	}

//---------------------------------------------------------------------------------------
//
// 	
//
//---------------------------------------------------------------------------------------

	public error_code 		=> .'error'->get(1)
	public error_msg 		=> .'error'->get(2)
	public error_stack 		=> .'error'->get(3)
	public error_current	=> (:error_code,error_msg,error_stack)

	public columns => .cols->asstaticarray
	public found_count => .found 
	
	public rows => {
		
		local(
			gb = givenblock,
			rows = .'dsrows'
		)
		
		if(not #rows) => {
			#rows = array
			.'rows'->foreach => {
				#rows->insert(
					ds_row(.'index',.'cols',#1,.'dsinfo')
				)
			}
		}
		
		if(#gb) => {
			result_push(self)
			#rows->foreach => {
				#gb(#1)
			}
			result_pop
		}

		return .'dsrows' := #rows		
	}	

	public rows(type::tag) => {
		local(
			gb = givenblock,
			out = array,
			row
		) 
		
		.rows->foreach => {
			#row = \#type()
			#row->oncreate(#1)
			#out->insert(#row)
		}
		if(#gb) => {
			result_push(self)
			#out->foreach => {
				#gb(#1)	
			}
			result_pop
		}		
		return #out
	}

	public row(row::integer) => {
		.'dsrows' ? return .'dsrows'->get(#row)
		return dsrow(.'index',.'cols',.'rows'->get(#row))
	}

	public asstring => {
		return(
			.type->asstring+'('+
			.'cols'->size + ' columns, '+
			.'rows'->size + ' rows, '+
			.found +' found, '+
			.affected +' affected)'
		)
	}

	
}


?>