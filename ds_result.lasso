<?lassoscript
//============================================================================
//
//	result handles
//
//............................................................................

define result					=> result(1) 
define result(setnum::integer)	=> {
	local(results) = results
	
	if(#results->isa(::staticarray)) => {
		#setnum > #results->size || #setnum < 1 
		? fail('Invalid setnum: ' + #setnum)
		return #results->get(#setnum)
	else
		return ds_result(#setnum)		
	}
}

define results					=> thread_var_get(::__ds_results)
define result_push(p::any) 		=> thread_var_push(::__ds_results,#p)
define result_pop 				=> thread_var_pop(::__ds_results)

//============================================================================
//
//	ds_result
//
//............................................................................

define ds_result => type {
	data 
		public index::trait_searchable,
		public cols::trait_foreach,
		public types::trait_foreach,
		public rows::staticarray,
		public set::staticarray,
		public found::integer=0,
		public affected::integer=0,
		public num::integer=0,
		
		private error::staticarray=(:0,'',''),
		private ds,	
		private dsinfo,	
		private dsrows

//---------------------------------------------------------------------------------------
//
//	oncreate sigs
//
//---------------------------------------------------------------------------------------

	public oncreate(
		set::staticarray,
		dsinfo::dsinfo,
		affected::integer,
		error::staticarray,
		num::integer
	) => {
		.dsinfo = #dsinfo
		.affected = #affected
		
		.oncreate(#set,#error,#num)
	}

	public oncreate(
		ds::ds,
		set::staticarray,
		dsinfo::dsinfo,
		affected::integer,
		error::staticarray,
		num::integer
	) => {
		.ds = #ds
		.dsinfo = #dsinfo
		.affected = #affected
		
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
		.'set' 			= #set
		.'found'		= #found
		.'affected' 	= #affected
		.'error' 		= #error
		.'num' 			= #num
			
	}

	public oncreate(
		index::trait_searchable,
		cols::trait_foreach,
		rows::staticarray,
		set::staticarray,
		found::integer=0,
		affected::integer=0,
		error::staticarray=.error_current,
		num::integer=0
	) => {
		.'cols'			= #cols
		.'index'		= #index
		.'rows' 		= #rows
		.'set' 			= #set
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
		local(
			scope = inline_scopeget,
			set = #scope ? #scope->find(::currentinline)->dsinfo->getset(#num)
		)
		#set->size ? .oncreate(#set,.error_current,#num) 

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

	public columntype(i::integer)::tag => {
		match(#i) => {
			case(lcapi_datasourcetypestring)
				return ::string
			case(lcapi_datasourcetypeinteger)
				return ::integer
			case(lcapi_datasourcetypeboolean)
				return ::boolean
			case(lcapi_datasourcetypeblob)
				return ::bytes
			case(lcapi_datasourcetypedecimal)
				return ::decimal
			case(lcapi_datasourcetypedate)
				return ::date
			case
				return
		}
	}

	public columntypes => {
		.'types' ? return .'types'
 
		local(types) = map

		.'set'->get(INLINE_COLUMNINFO_POS)->foreach => {
			#types->insert(
				#1->get(INLINE_COLINFO_NAME_POS) = .columntype(
					#1->get(INLINE_COLINFO_TYPE_POS)
				)
			)
		}

		return .'types' := #types 
	}

	public rows => {
		
		local(
			gb = givenblock,
			rows = .'dsrows'
		)
		
		if(not #rows) => {
			#rows = array
			.'rows'->foreach => {
				#rows->insert(
					ds_row(.'index',.'cols',#1,.'dsinfo',.'ds')
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

	public rows(type::tag) => .rows(\#type,true) => givenblock
	
	public rows(creator::memberstream,useoncreate::boolean=false) => {
		local(
			gb = givenblock,
			out = array,
			row
		) 		
		if(#useoncreate) => { 
			.rows->foreach => {
				#row = #creator()
				#row->oncreate(#1)
				#out->insert(#row)
			}		
		else
			.rows->foreach => {
				#out->insert(
					#creator(#1)
				)
			}
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
		return ds_row(.'index',.'cols',.'rows'->get(#row),.'dsinfo',.'ds')
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
		
//---------------------------------------------------------------------------------------
//
// 	Result iterator
//
//---------------------------------------------------------------------------------------

	public foreach => {
		local(gb) = givenblock
		.rows->foreach => {#gb(#1)}
	}

	public do(gb::capture) => {
		.rows->foreach => {
			#gb(#1)
		}
	}
		
//---------------------------------------------------------------------------------------
//
// 	Shortcuts
//
//---------------------------------------------------------------------------------------

	public first => .rows->first
	public firstrow(...) => .first(:#rest || staticarray)
	
	public first(col::string) => .first->find(#col)
	public first(col::tag) 	  => .first->find(#col->asstring)

	public last => .rows->last
	public lastrow(...) => .first(:#rest || staticarray)
	public last(col::string) => .last->find(#col)
	public last(col::string) => .last->find(#col)



//---------------------------------------------------------------------------------------
//
// 	Find rows within result set
//
//---------------------------------------------------------------------------------------

	public find(p::pair) => (
		with row in .rows 
		where #row->find(#p->name) == #p->value
		select #row
	)->asstaticarray	

	public find(p1::pair,p2::pair) => (
		with row in .rows 
		where #row->find(#p1->name) == #p1->value &&  #row->find(#p2->name) == #p2->value 
		select #row
	)->asstaticarray	
	
}
?>