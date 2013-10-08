<?lassoscript
//=======================================================================================
//
//	DS for Lasso 9 — Free to use, license TBD
//
//..All rights reserved — K Carlton 2013.................................................

//---------------------------------------------------------------------------------------
//
// 	SQL Select Statement Constructor 
//
//---------------------------------------------------------------------------------------

define statement => type {
	data
		public ds,
		copyself = false 

	public oncreate => {}
	public oncreate(ds::ds) => {
		.'ds' = #ds 
		.'copyself' = true
		return .from(#ds->dsinfo->tablename)
	}
	
	public ds 		=> .'ds'
	public copyself => .'copyself'
	public copy 	=> self

	public ascopy	=> {
		local(c) = ..ascopy
		#c->ds = .ds->ascopy		
		return #c
	}

//---------------------------------------------------------------------------------------
//
// 	These methods invoke the datasource
//
//---------------------------------------------------------------------------------------

	public invoke => {
		return .ds->sql(.statement) => givenblock
	}

	public invoke(ds::ds) => {
		return #ds->sql(.statement) => givenblock
	}

	public invokeifblock => {
		if(givenblock) => {
			return .invoke => givenblock
		else
			return self
		}
	}
	
	public asstring => {
		if(.ds) => {
			return .rows->join('')
		else
			return .statement
		}
	}

	/*	Invoke DS */
	public rows 				=> .invoke->rows => givenblock
	public rows(type::tag) 		=> .invoke->rows(#type) => givenblock
	public as(type::tag) 		=> .invoke->rows(#type) => givenblock

	public do					=> .invoke => givenblock
	public do(c::capture)		=> #c(.invoke->last)
	
//---------------------------------------------------------------------------------------
//
//	Replace values
//
//---------------------------------------------------------------------------------------

	public switch(target::tag,value::trait_foreach) => {
		(.escape_member(tag(`'`+#target->asstring+`'=`)))->invoke(#value)
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
//	SQL encoder (leaves ints & decimals untouched, supports IN )
//
//---------------------------------------------------------------------------------------

	public encode(val::any) => {
		match(#val->type) => {
			case(::decimal)
				return #val
			case(::integer)
				return #val
			case(::date)
				return #val->format('%q')
			case(::null)
				return 'NULL'
			case(::void)
				return 'NULL'
			case(::array)
				local(out) = ''
				#out->append('IN(')
				#val->foreach => {
					#out->append(
						.encode(#1) + ','
					)
				}
				#out->removetrailing(',')
				#out->append(')')
				return #out		
			case
				return `'`+string(#val)->encodesql+`'`
		}
	}
	
	public encodecol(col::tag) => '`' + #col->asstring + '`'
	public encodecol(col::string) => {
		#col = #col->ascopy
		#col->replace(';','')
		#col->replace('`','')
		return '`' + #col + '`'
	}
	
//---------------------------------------------------------------------------------------
//
// 	Methods to output statement
//
//---------------------------------------------------------------------------------------

	public ifsize(p::null,...) => ''
	public ifsize(p::trait_foreach,pre::string,join::string='',suf::string='') => {
		if(#p->size) => {
			return #pre + #p->join(#join) + #suf + '\n'
		else
			return ''
		}
	}
}

//---------------------------------------------------------------------------------------
//
// 	SQL Select Statement Constructor 
//
//---------------------------------------------------------------------------------------

define select_statement => type {
	parent statement

	data
		public	select::trait_foreach 	= array,
		public	from::trait_foreach 	= array,
		public	join::trait_foreach 	= array,
		public	where::trait_foreach 	= array,
		public	groupby::trait_foreach 	= array,
		public	having::trait_foreach 	= array,
		public	orderby::trait_foreach 	= array,
		public	limit::trait_foreach 	= array

	public oncreate => {}
	public oncreate(ds::ds) => {
		.'ds' = #ds 
		.'copyself' = true
		return .from(#ds->dsinfo->tablename)
	}
	
//---------------------------------------------------------------------------------------
//
// 	Parse queries
//
//---------------------------------------------------------------------------------------

	public select(column::tag,...) 		=> .switch(::select,params) => givenblock
	public select(columns::array) 		=> .switch(::select,#columns) => givenblock
	public select(columns::string,...) 	=> .switch(::select,params) => givenblock

	public from(tables::array) 			=> .switch(::from,#tables) => givenblock
	public join(tables::array) 			=> .switch(::join,#tables) => givenblock
	public where(expr::array)			=> .switch(::where,#expr) => givenblock
	public groupby(columns::array) 		=> .switch(::groupby,#columns) => givenblock
	public having(expr::array)			=> .switch(::having,#expr) => givenblock
	public orderby(columns::array) 		=> .switch(::orderby,#columns) => givenblock

	public orderby(reset::boolean) => {
		! #reset
		? return .switch(::orderby,array) => givenblock 
		| return .invokeifblock => givenblock
	}

	public limit(expr::array) 			=> .switch(::limit,#expr) => givenblock

	public limit(reset::boolean) => {
		! #reset
		? return .switch(::limit,array) => givenblock 
		| return .invokeifblock => givenblock
	}

	public from(table::tag,...) 		=> .switch(::from,params->asarray) => givenblock
	public from(table::string,...) 		=> .switch(::from,params->asarray) => givenblock

	public join(table::string,...) 		=> .merge(::join,params) => givenblock
	public where(expr::string,...)		=> .merge(::where,params) => givenblock
	public where(expr::pair,...)		=> {
		local(out) = .copy
	
		with item in params do {
			#item->isanyof(::pair,::keyword)
			? #out = #out->where(#item->name->asstring + ' = ' + .encode(#item->value))
			| #out = #out->where(#item)
		}	
		
		return #out->invokeifblock => givenblock
	}
	public orderby(columns::string) 	=> .merge(::orderby,params) => givenblock
	public groupby(columns::string,...) => .merge(::groupby,params) => givenblock
	public having(expr::string,...)		=> .merge(::having,params) => givenblock
	public having(expr::pair,...)		=> {			
		local(out) = .copy

		with item in params do {
			#item->isanyof(::pair,::keyword)
			? #out = #out->merge(::having,#item->name->asstring+' = '+.encode(#item->value))
			| #out = #out->having(#item)
		}
		return #out->invokeifblock => givenblock
	}
	
	public limit(expr::string) 					=> .switch(::limit,array(#expr)) => givenblock
	public limit(max::integer) 					=> .switch(::limit,array('0,'+#max)) => givenblock
	public limit(start::integer,max::integer) 	=> .switch(::limit,array('0,'+#max)) => givenblock

//---------------------------------------------------------------------------------------
//
// 	Count results — best practice to establish found count in large result sets
//
//---------------------------------------------------------------------------------------

	public count =>	{
		local(s) = .ascount
		if(.ds) => {
			return #s->invoke->firstrow(::count)->asinteger
		else	// Or fail?
			return 0
		}				
	} 

	public ascount => .ascopy->select('COUNT(*) as count')
						->orderby(false)
						->limit(false)

//---------------------------------------------------------------------------------------
//
// 	Switch to an update_statement
//
//---------------------------------------------------------------------------------------
	
	public update(...) => {
		local(
			ds = .ds,
			update = update_statement,
			table = .'from'
		)
		
		#ds ? #update->oncreate(#ds)
		
		#update->update(#table)
		#update->set(:#rest || staticarray)
		#update->where(.'where')
		
		return #update(!givenblock) => givenblock
	}
	
//---------------------------------------------------------------------------------------
//
// 	Methods to output statement
//
//---------------------------------------------------------------------------------------
		
	public select	=> .ifsize(.'select',	'SELECT ',	',') || 'SELECT * '
	public from		=> .ifsize(.'from',		'FROM ',	', ')
	public join		=> .ifsize(.'join',		'JOIN ',	'\nJOIN ')
	public where	=> .ifsize(.'where',	'WHERE ',	' AND ')
	public groupby	=> .ifsize(.'groupby',	'GROUP BY ',	', ')
	public having	=> .ifsize(.'having',	'HAVING ',	' AND ')
	public orderby	=> .ifsize(.'orderby',	'ORDER BY ',	', ')
	public limit	=> .ifsize(.'limit',	'LIMIT ',)

	public merge(target::tag,values::staticarray) => {

		match(#target) => {
			case(::select)
				.'select'->insertfrom(#values)
			case(::from)
				.'from'->insertfrom(#values)
			case(::join)
				.'join'->insertfrom(#values)
			case(::where)
				.'where'->insertfrom(#values)
			case(::groupby)
				.'groupby'->insertfrom(#values)
			case(::orderby)
				.'orderby'->insertfrom(#values)
			case(::having)
				.'having'->insertfrom(#values)
			case(::limit)
				.'limit'->insertfrom(#values)
		}
		
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
// 	Stitch it all together
//
//---------------------------------------------------------------------------------------

	public statement => .select + .from + .join + .where + .groupby + .having + .orderby + .limit

}


define insert_statement => type {

	parent statement

	data
		public
			into::array 	= array, // table
			columns::array 	= array,
			values::array 	= array,
			update::array 	= array,
			onduplicate		= array,
		public
			insertevery			= 0		

	public oncreate => {}
	
	public oncreate(ds::ds) => {
		.'ds' = #ds 
		.'copyself' = true
		return .into(#ds->dsinfo->tablename)
	}

	public into(table::string,...) 	=> .switch(::into,array(#table))->merge(::columns,#rest || staticarray) => givenblock	
	public into(table::tag,...) 	=> .switch(::into,array(#table->asstring))->merge(::columns,#rest || staticarray) => givenblock

	public columns(column::tag,...) 	=> .merge(::columns,params) => givenblock
	public columns(column::string,...) 	=> .merge(::columns, params) => givenblock
	public columns(columns::trait_foreach) 		=> .switch(::columns,#columns->asarray) => givenblock
	
	public merge(target::tag,values::staticarray) => {	
		match(#target) => {
			case(::into)
				.'into'->insertfrom(#values)
			case(::columns)
				.'columns'->insertfrom(#values)
			case(::values)
				.'values'->insertfrom(#values)
			case(::update)
				.'update'->insertfrom(#values)
		}
		return .invokeifblock => givenblock
	}

	public into			=> .ifsize(.'into',			'INSERT INTO ',	',')
	public columns		=> .ifsize(.'columns',		'(', ',', ')')
	public values		=> .ifsize(.'values',		'VALUES ',',\n')
	public onduplicate	=> .ifsize(.'onduplicate',	'ON DUPLICATE KEY UPDATE ',',\n')

	public insertevery(rows::integer) => {
		.insertevery = #rows
		return .invokeifblock => givenblock
	}


//---------------------------------------------------------------------------------------
//
// 	Useful addrow sigs
//
//---------------------------------------------------------------------------------------
	
	public addrow(p::pair,...) => {
		local(r) = map
		with p in params do {
			#p->isa(::pair) ? #r->insert(#p)
		}
		return .invokeifblock => givenblock
	}

	public addrow(p1::any,p2::any,...) => {
		local(r) = array
		
		with p in params do {
			#r->insert(#p)
		}
		
		.addrow(#r)
		
		return .invokeifblock => givenblock
	}

	public addrow(p::map) => {
		local(r) = array
		
		with col in .'columns' do {
			#r->insert(#p->find(#col))
		}
		.addrow(#r)	
		return .invokeifblock => givenblock
	}
	

//---------------------------------------------------------------------------------------
//
//	Main addrow mechanism
//
//---------------------------------------------------------------------------------------
	
	public addrow(p::array) => {
		fail_if(#p->size != .'columns'->size && .'columns'->size,'Row columns to not match specified columns: '+.'columns'->join(', '))
		
		local(r) = array
		
		with v in #p do {
			#r->insert(.encode(#v))		
		}
		
		.'values'->insert('('+#r->join(',')+')')
		
		if(.'ds' && .'insertevery' && .'values'->size >= .'insertevery' && !givenblock) => {
			handle => {
				.'values'->removeall 
			}
			.invoke => givenblock	
		}
	
		return .invokeifblock => givenblock
		
	}

//---------------------------------------------------------------------------------------
//
// 	Add multiple rows
//
//---------------------------------------------------------------------------------------
	
	public addrows(rows::trait_foreach) => {
		#rows->foreach => {
			.addrow(#1)
		}
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
// 	On duplicate key, MySQL only
//
//---------------------------------------------------------------------------------------

	public onduplicate(keyupdateall::boolean) => {
		local(on) = .'onduplicate'
	
		if(#keyupdateall) => {
			with col in .'columns' do {
				#on->insert(.encodecol(#col)+' = VALUES('+.encodecol(#col)+')')
			}
		else
			.'onduplicate' = array
		}
		return .invokeifblock => givenblock
	}

	public onduplicate(p1,p2,...) => {
		with p in params do {
			.onduplicate(#p)
		}
		return .invokeifblock => givenblock
	}

	public onduplicate(p::pair) => {
		.'onduplicate'->insert(
			.encodecol(#p->name) + ' = ' + #p->value
		)			
		return .invokeifblock => givenblock
	}

	public onduplicate(p::tag) => .onduplicate(#p->asstring)

	public onduplicate(p::string) => {
		.'onduplicate'->insert(
			.encodecol(#p)+' = VALUES('+.encodecol(#p)+')'			
		)			
		return .invokeifblock => givenblock
	}

	public onduplicate(keyupdate::array) => {
		with p in #keyupdate do {
			.onduplicate(#p)
		}
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
// 	Stitch it all together
//
//---------------------------------------------------------------------------------------

	public statement => .into + .columns + .values + .onduplicate

}


define update_statement => type {
	parent statement

	data
		public	update::trait_foreach 	= array,
		public	join::trait_foreach 	= array,
		public	set::trait_foreach 		= array,
		public	where::trait_foreach 	= array 

	public oncreate => {}
	public oncreate(ds::ds) => {
		.'ds' = #ds 
		.'copyself' = true
		return .update(#ds->dsinfo->tablename)
	}

//---------------------------------------------------------------------------------------
//
// 	Set params
//
//---------------------------------------------------------------------------------------

	public update(table::tag,...) 		=> .switch(::update,params->asarray) => givenblock
	public update(table::string,...) 	=> .switch(::update,params->asarray) => givenblock
	public update(tables::array) 		=> .switch(::update,#tables) => givenblock
	public where(expr::array)			=> .switch(::where,#expr) => givenblock
	public join(tables::array) 			=> .switch(::join,#tables) => givenblock
	public join(tables::array) 			=> .switch(::join,#tables) => givenblock

//---------------------------------------------------------------------------------------
//
// 	Merge params
//
//---------------------------------------------------------------------------------------

	public set(expr::string,...)		=> .merge(::set,params) => givenblock
	public set(expr::pair,...)		=> {
		with item in params do {
			#item->isanyof(::pair,::keyword)
			? .set(#item->name->asstring + ' = ' + .encode(#item->value))
			| .set(#item)
		}		
		return .invokeifblock => givenblock
	}
	
	public join(table::string,...) 		=> .merge(::join,params) => givenblock
	public where(expr::string,...)		=> .merge(::where,params) => givenblock
	public where(expr::pair,...)		=> {
		with item in params do {
			#item->isanyof(::pair,::keyword)
			? .where(#item->name->asstring + ' = ' + .encode(#item->value))
			| .where(#item)
		}		
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
// 	Methods to output statement
//
//---------------------------------------------------------------------------------------
		
	public update	=> .ifsize(.'update',	'UPDATE ',	',')
	public join		=> .ifsize(.'join',		'JOIN ',	'\nJOIN ')
	public set		=> .ifsize(.'set',		'SET ',		', ')
	public where	=> .ifsize(.'where',	'WHERE ',	' AND ')

	public affected => .invoke->affected

	public merge(target::tag,values::staticarray) => {
		match(#target) => {
			case(::select)
				.'update'->insertfrom(#values)
			case(::join)
				.'join'->insertfrom(#values)
			case(::set)
				.'set'->insertfrom(#values)
			case(::where)
				.'where'->insertfrom(#values)
		}
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
// 	Stitch it all together
//
//---------------------------------------------------------------------------------------

	public statement => .update + .join + .set + .where 

}

//---------------------------------------------------------------------------------------
//
//	Extend null (ninja style lasso extension)
//
//---------------------------------------------------------------------------------------

define null->asinteger => integer(self)
define null->asdecimal => decimal(self->asstring)

?>