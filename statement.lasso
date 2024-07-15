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

	public asstring => .statement

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
	// Allows all rows ro be set here
	public all => {
		.ds->all
		return .invokeifblock => givenblock
	}

	
	/*	Invoke DS */
	public rows 					=> .invoke->rows => givenblock
	public rows(type::tag) 			=> .invoke->rows(#type) => givenblock
	public rows(meth::memberstream)	=> .invoke->rows(#meth) => givenblock
	public as(type::tag) 			=> .invoke->rows(#type) => givenblock
	public as(meth::memberstream)	=> .invoke->rows(#meth) => givenblock


	public do             => .invoke => givenblock
	public do(c::capture) => #c(.invoke->last)
	
//---------------------------------------------------------------------------------------
//
//	Replace values
//
//---------------------------------------------------------------------------------------

	public switch(target::tag,value::trait_positionallykeyed) => {
		(.escape_member(tag(`'`+#target->asstring+`'=`)))->invoke(#value)
		return .invokeifblock => givenblock
	}

	public get(target::tag) => {
		return (.escape_member(tag(`'`+#target->asstring + `'`)))->invoke()
	}

//---------------------------------------------------------------------------------------
//
//	SQL encoder (leaves ints & decimals untouched, supports IN )
//
//---------------------------------------------------------------------------------------

	public encode(val::any) => {
		match(#val->type) => {
			case(::decimal)
				return #val->asstring
			case(::integer)
				return #val->asstring
			case(::date)
				return `'` + #val->asstring->encodesql+`'`
			case(::null)
				return 'NULL'
			case(::void)
				return 'NULL'
			case(::bytes)
				return '0x' + #val->encodehex
			case(::array,::staticarray)
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

	public encode(item::pair) => {
		local(delim) = (#item->value->isanyof(::array,::staticarray) ? ' ' | (#item->value->isa(::null) ? ' IS ' | ' = '))
		return .encodecol(#item->name->asstring) + #delim + .encode(#item->value)
	}
	
	public encodecol(col::tag) => .encodecol(#col->asstring)

	public encodecol(col::string) => {
		#col = #col->ascopy
		#col->replace(';','')
		
		.ismysql ? #col = '`' + #col->replace('`','') & replace('.','`.`')& + '`'
		return #col
	}

	public ismysql => protect => {
		return .'ds'->dsinfo->hostdatasource->asstring >> 'mysql'
	}
	
//---------------------------------------------------------------------------------------
//
// 	Methods to output statement
//
//---------------------------------------------------------------------------------------

	public ifsize(p::null,...) => ''
	public ifsize(p::trait_positionallykeyed,pre::string,join::string='',suf::string='') => {
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
		public	select::trait_positionallykeyed 	= array,
		public	from::trait_positionallykeyed 	= array,
		public	join::trait_positionallykeyed 	= array,
		public	where::trait_positionallykeyed 	= array,
		public	groupby::trait_positionallykeyed 	= array,
		public	having::trait_positionallykeyed 	= array,
		public	orderby::trait_positionallykeyed 	= array,
		public	limit::trait_positionallykeyed 	= array

	public oncreate => {}
	public oncreate(ds::ds) => {
		.'ds' = #ds 
		.'copyself' = true
		return .from('`' + #ds->dsinfo->tablename + '`')
	}


	// This has been deemed too confusing
	/*
	public asstring => {
		if(.ds) => {
			return .rows->join('')
		else
			return .statement
		}
	}
	*/

	public asstring => .type->asstring 

	
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
//	public where(expr::array)			=> .switch(::where,#expr) => givenblock
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

	public groupby(reset::boolean) => {
		! #reset
		? return .switch(::groupby,array) => givenblock 
		| return .invokeifblock => givenblock
	}


	public from(table::tag,...) 		=> .switch(::from,params->asarray) => givenblock
	public from(table::string,...) 		=> .switch(::from,params->asarray) => givenblock

	public join(table::string,...) => .merge(::join,params) => givenblock

	public where(expr::string,...) => .where(params) => givenblock
	public where(expr::pair,...)   => .where(params) => givenblock
	public where(p::array)         => .where(#p->asstaticarray) => givenblock
	public where(p::staticarray)   => {

		with item in #p do {
			if(#item->isanyof(::pair,::keyword)) => {	
				.'where'->insert(
					.encode(pair(#item->name,#item->value))
				)
			else(#item->isa(::string) && #item)
				.'where'->insert(
					#item
				)
			}
		}		
		return .invokeifblock => givenblock
	}

	public orderby(columns::string) 	=> .merge(::orderby,params) => givenblock
	public groupby(columns::string,...) => .merge(::groupby,params) => givenblock
	public having(expr::string,...)		=> .merge(::having,params) => givenblock
	public having(expr::pair,...)		=> {			
		local(out) = .copy

		with item in params do {
			#item->isanyof(::pair,::keyword)
			? .merge(::having,#item->name->asstring+' = '+.encode(#item->value))
			| .having(#item)
		}
		return .invokeifblock => givenblock
	}
	
	public limit(expr::string) 					=> .switch(::limit,array(#expr)) => givenblock
	public limit(max::integer) 					=> .switch(::limit,array('0,'+#max)) => givenblock
	public limit(start::integer,max::integer) 	=> .switch(::limit,array(#start + ','+#max)) => givenblock

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
						->groupby(false)
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
		public 
			ignore::boolean  = false, 
		public 
			delayed::boolean = false, 
			columns::array   = array,
			values::array    = array,
			update::array    = array,
			onduplicate      = array,
		public
			insertevery = 0		

	public oncreate => {}
	
	public oncreate(ds::ds) => {
		.'ds' = #ds 
		.'copyself' = true


		return .into('`' + #ds->dsinfo->tablename + '`')
	}
	
	public into(table::string,...columns)             => .switch(::into,array(#table))->merge(::columns,#columns || staticarray) => givenblock	
	public into(table::tag,...columns)                => .switch(::into,array(#table->asstring))->merge(::columns,#columns || staticarray) => givenblock
	public into(table::string,columns::trait_positionallykeyed) => .switch(::into,array(#table))->merge(::columns,#columns->asstaticarray) => givenblock	
	public into(table::tag,columns::trait_positionallykeyed)    => .switch(::into,array(#table->asstring))->merge(::columns,#columns->asstaticarray) => givenblock

	public columns(column::tag,...) 	=> .merge(::columns,params) => givenblock
	public columns(column::string,...) 	=> .merge(::columns, params) => givenblock
	public columns(columns::trait_positionallykeyed) 		=> .switch(::columns,#columns->asarray) => givenblock
	
	public merge(target::tag,values::staticarray) => {	
		match(#target) => {
			case(::into)
				.'into'->insertfrom(#values)
			case(::columns)
				.'columns'->insertfrom(#values)
				.'columns'->removeall(void)
			case(::values)
				.'values'->insertfrom(#values)
			case(::update)
				.'update'->insertfrom(#values)
		}
		return .invokeifblock => givenblock
	}

	public into			=> .ifsize(.'into',			'INSERT'  + (.delayed ? ' DELAYED ') + (.ignore ? ' IGNORE ') + ' INTO ',	',')


	public columns		=> {
		return .'columns'->size
		? '(' + (with col in .'columns'
					select .encodecol(#col)
						)->asstaticarray->join(',') + ')'
		| ''
	}

	public values		=> .ifsize(.'values',		' VALUES ',',\n')
	public onduplicate	=> .ifsize(.'onduplicate',	' ON DUPLICATE KEY UPDATE ',',\n')

	public insertevery(rows::integer) => {
		.insertevery = #rows
		return .invokeifblock => givenblock
	}
	
	public do => .'values'->size || givenblock ? .invoke => givenblock

//---------------------------------------------------------------------------------------
//
// 	Useful addrow sigs
//
//---------------------------------------------------------------------------------------
	
	public addrow(p::pair,...) => {
		local(r) = map
		with p in params do {
			#p->isa(::pair) 
			? #r->insert(#p)
		}
		return .addrow(#r) => givenblock
	}

	public addrow(p::map) => {
		local(r) = array

		// If no columns specified use the maps keys
		.'columns'->size == 0
		? with col in #p->keys do {
			.'columns'->insert(#col)
		}

		// Only use data from specified columns
		with col in .'columns' do {
			#r->insert(#p->find(#col))
		}
		return .addrow(#r) => givenblock
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
	
	public addrows(rows::trait_positionallykeyed) => {
		#rows->foreach => {
			.addrow(#1)
		}
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
//	Values (array sig)
//
//---------------------------------------------------------------------------------------

	public values(rows::array) => {
		.addrows(#rows)
		return .invokeifblock => givenblock
	}

	public values(row::map) => {
		.addrow(#row)
		return .invokeifblock => givenblock
	}

	public values(p::pair, ...) => {
		.addrow(: params)
		return .invokeifblock => givenblock
	}


//---------------------------------------------------------------------------------------
//
// 	Ignore support
//
//---------------------------------------------------------------------------------------

	public ignore(shouldignore::boolean) => {
		.ignore = #shouldignore
		return .invokeifblock => givenblock
	}

//---------------------------------------------------------------------------------------
//
// 	Delayed support
//
//---------------------------------------------------------------------------------------

	public delayed(shoulddelay::boolean) => {
		.delayed = #shoulddelay
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
		public	update::trait_positionallykeyed = array,
		public	join::trait_positionallykeyed   = array,
		public	set::trait_positionallykeyed    = array,
		public	where::trait_positionallykeyed  = array 

	public oncreate => {}
	public oncreate(ds::ds) => {
		.'ds' = #ds 
		.'copyself' = true
		return .update('`' + #ds->dsinfo->tablename + '`')
	}

//---------------------------------------------------------------------------------------
//
// 	Set params
//
//---------------------------------------------------------------------------------------

	public update(table::tag,...where)    => .switch(::update,array(#table->asstring))->where(#where || staticarray) => givenblock	
	public update(table::string,...where) => .switch(::update,array(#table))->where(#where || staticarray) => givenblock	
	public update(tables::array)          => .switch(::update,#tables) => givenblock
	public join(tables::array)            => .switch(::join,#tables) => givenblock
	public join(tables::array)            => .switch(::join,#tables) => givenblock

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
	public set(expr::trait_keyedForEach) => .set(: #expr->eachpair->asstaticarray )
	public set(expr::array)              => .set(: #expr->asstaticarray )
	public set(expr::staticarray)        => .set(: #expr)


	public join(table::string,...) 		=> .merge(::join,params) => givenblock
	public where(expr::string,...)		=> .where(params) => givenblock
	public where(expr::pair,...)		=> .where(params) => givenblock

	public where(p::staticarray)		=> {

		with item in #p do {

			// pair and keywords
			if(#item->isanyof(::pair,::keyword)) => {
				.'where'->insert(
					.encode(#item)
				)

			// raw sql
			else(#item->isa(::string) && #item)
				.'where'->insert(#item)

			// ds_row->keyvalues 
			else(#item->isa(::staticarray) && #item->size == 3) 
				.'where'->insert(
					.encode(
						#item->get(1) = #item->get(3)
					)
				)
			}
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

	public do_when_where  => .'where'->size ? .invoke => givenblock	

}

//---------------------------------------------------------------------------------------
//
//	Extend null (ninja style lasso extension)
//
//---------------------------------------------------------------------------------------

define null->asinteger => integer(self)
define null->asdecimal => decimal(self->asstring)

?>
