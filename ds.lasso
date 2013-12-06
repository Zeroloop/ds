<?lassoscript
//=======================================================================================
//
//	DS Suite for Lasso 9 — Free to use, license TBD
//
//..All rights reserved — K Carlton 2013.................................................

//---------------------------------------------------------------------------------------
//
// 	Connections stored on thread level
//
//---------------------------------------------------------------------------------------

define ds_connections => {
	if(var(::__ds_connections__)->isnota(::map)) => {
		$__ds_connections__ = map
		web_request ? define_atend({
			ds_connections->foreach => {				
				//stdout(#1->key+': ')
				#1->close
				//stdoutnl('closed')	
			}
		})
	} 
	return $__ds_connections__
}

//---------------------------------------------------------------------------------------
//
// 	datasource — english relay
//
//---------------------------------------------------------------------------------------

define datasource(...) => ds(:#rest || staticarray)

define ds => type{

	data
		public	dsinfo::dsinfo,
		public	key::string = '',
		private	keycolumn::string = 'id',	
		private results = staticarray,

		// Legacy: support action_params
		public	actionparams = staticarray,

		//	Connector
		public capi

	//	Thread safe copy
	public ascopy => {
		local(ds) = ds
		
		#ds->dsinfo = .dsinfo->makeinheritedcopy
		#ds->key = .key
		#ds->capi = .capi
		
		return #ds
	
	}
	public ascopydeep 	=> .ascopy

//---------------------------------------------------------------------------------------
//
// 	Oncreate
//
//---------------------------------------------------------------------------------------
	
	//	Look up details from lasso admin (overhead)

	public oncreate(
		database::string,
		table::string = ''
	) => .oncreate(
		-database 	= #database,
		-table 		= #table
	) => givenblock

	//	Slick db.table accessor ds(::database.table)

	public oncreate(databasetable::tag) => {
		local(s) = #databasetable->asstring->splitextension('.')
		
		.oncreate(
			-database 	= #s->first,
			-table 		= #s->second || '' 
		) => givenblock
	}

	//	Fast host accessor — ds(::mysqlds,'127.0.0.1',::product.list)

	public oncreate(
		datasource::tag,
		host::string,
		databasetable::tag,
		username::string='',
		password::string='',
		port::integer=3306
	) => {
	
		local(s) = #databasetable->asstring->splitextension('.')
	
		.oncreate(
			-datasource = #datasource->asstring,
			-database 	= #s->first,
			-table 		= #s->second || '',	
			-host 		= #host,
			-username 	= #username,
			-password 	= #password,
			-port 		= #port 		
		) => givenblock
		
	}
	
	//	Fast host accessor — ds(::mysqlds,'127.0.0.1','product','list')
	
	public oncreate(
		datasource::tag,
		host::string,
		database::string,
		table::string,
		username::string='',
		password::string='',
		port::integer=3306
	) => .oncreate(
		-datasource = #datasource->asstring,
		-database 	= #database,
		-table 		= #table,
		-host 		= #host,
		-username 	= #username,
		-password 	= #password,
		-port 		= #port 		
	) => givenblock
	
//------------------------------------------------------------------------
//
//	Duplicate a connection (legacy inline support bundled here)
//
//------------------------------------------------------------------------
	
	public oncreate(dsinfo::dsinfo,
		useinfo::boolean=false,
		params::staticarray=staticarray
	) => {
		
		//	Legacy: store action params
		.actionparams = #params 
		
		#useinfo ? handle => {.keycolumn = ''}
				
		return .oncreate(
			-datasource = #dsinfo->hostdatasource || 'mysqlds',
			-database 	= #dsinfo->databasename,
			-table 		= #dsinfo->tablename,
			-host 		= #dsinfo->hostname,
			-hostschema	= #dsinfo->hostschema,
			-username 	= #dsinfo->hostusername,
			-password 	= #dsinfo->hostpassword,
			-port 		= integer(#dsinfo->hostport),	
			-encoding	= #dsinfo->hosttableencoding || 'UTF-8',
			-maxrows	= #dsinfo->maxrows || 50,
			-dsinfo		= #dsinfo,	//	Legacy: leverage dsinfo constructor
			-useinfo	= #useinfo	//	Legacy: switch to trigger legacy mode
		) => givenblock 
	}
	

//------------------------------------------------------------------------
//
// 	Support core inline params
//
//------------------------------------------------------------------------

	public oncreate(
		-datasource::string='mysqlds',
		-database::string='',
		-table::string='',
		-keycolumn::string='',
		-maxrows::integer=50,
		
		// Host params
		-host::string='',
		-port::integer=3306,
		-username::string='',
		-password::string='',
		-schema::string='',
		-encoding::string='UTF-8',
				
		// Perhaps this should be culled (legacy support for old version of ds)
		-sql::string='', 
		
		// Legacy: support classic inline
		-dsinfo::dsinfo=dsinfo,
		-useinfo::boolean=false,
		
		// Allow key override
		-key::string = #host + #database + #username + #port 
		
	) => {
	
		// Work round oncreate givenblock bug.
		.'dsinfo' = #dsinfo
		
		local(
			active 	= ds_connections->find(#key),
			dsinfo 	= .'dsinfo',
			hostinfo,
			gb = givenblock
		)
	
		//	Store key
		.key = #key

		handle => { 
			//	Set keycolumn info
			.keycolumn = #keycolumn || .keycolumn	
		}
		
		if(#active) => { 
		
			//	Check for existing connection
			.'capi' 	= #active->capi
			
			//	Ensure thread safe
			//.'dsinfo' = #active->dsinfo//->makeinheritedcopy

			local(d) = #active->dsinfo
			
			//.'dsinfo' = #active->dsinfo->makeinheritedcopy
			#dsinfo->hostdatasource 	= #d->hostdatasource
			#dsinfo->hostid 			= #d->hostid
			#dsinfo->hostname 			= #d->hostname
			#dsinfo->hostport 			= #d->hostport
			#dsinfo->hostusername 		= #d->hostusername
			#dsinfo->hostpassword 		= #d->hostpassword
			#dsinfo->hosttableencoding 	= #d->hosttableencoding
			#dsinfo->hostschema 		= #d->hostschema

			#dsinfo->connection 		= #d->connection
			#dsinfo->prepared 			= #d->prepared
			#dsinfo->refobj 			= #d->refobj

		else(#host)			
	
			//	Host specified, skip look up — fast
	
			#dsinfo->hostdatasource 	= #datasource
			#dsinfo->hostid 			= 0
			#dsinfo->hostname 			= #host
			#dsinfo->hostport 			= #port->asstring
			#dsinfo->hostusername 		= #username
			#dsinfo->hostpassword 		= #password
			#dsinfo->hosttableencoding 	= #encoding
			#dsinfo->hostschema 		= #schema
	
			.'capi' = \#datasource
			
		else(#database) 	
	
			//	Look up database info (slow due to extra db call)
		
			#table // if table specified check for specific encoding
			?	#hostinfo = .get_dsinfo(#database,#table)
			|	#hostinfo = .get_dsinfo(#database)
						
			fail_if(!#hostinfo,'Unable to determine host for: '+#database+'.'+#table)
			
			//	Set properties from found info
			#dsinfo->hostdatasource 	= #hostinfo->get(1)
			#dsinfo->hostid 			= #hostinfo->get(2)	
			#dsinfo->hostname 			= #hostinfo->get(3)
			#dsinfo->hostport 			= #hostinfo->get(4)
			#dsinfo->hostusername 		= #hostinfo->get(5)
			#dsinfo->hostpassword		= #hostinfo->get(6)
			#dsinfo->hostschema 		= #hostinfo->get(7)
			#dsinfo->hosttableencoding 	= #hostinfo->get(8)||#encoding	

			.'capi' = \#datasource
		}

		//	Replace database and table (most likely the same unless key)
		#dsinfo->databasename		= #database
		#dsinfo->tablename			= #table
		#dsinfo->maxrows 			= #maxrows

		//	Legacy: leverage clasic inlie constructor
		if(#useinfo) => {
		
			.'dsinfo'->action 			= #dsinfo->action
			.'dsinfo'->statement 		= #dsinfo->statement
			.'dsinfo'->statementonly 	= #dsinfo->statementonly
			.'dsinfo'->skiprows 		= #dsinfo->skiprows
			
			#dsinfo->keycolumns 	? .'dsinfo'->keycolumns  = #dsinfo->keycolumns 	
			#dsinfo->inputcolumns 	? .'dsinfo'->inputcolumns = #dsinfo->inputcolumns
			#dsinfo->returncolumns 	? .'dsinfo'->returncolumns = #dsinfo->returncolumns
			#dsinfo->sortColumns 	? .'dsinfo'->sortColumns 	= #dsinfo->sortColumns
		}

		//	Cheeky sql short cut — should be killed.
		if(#sql) => {
			#dsinfo->action 	= lcapi_datasourceExecSQL
			#dsinfo->statement 	= #sql
		}
			
		#gb ? return .invoke => #gb
		
	}

//---------------------------------------------------------------------------
//
// 	Bypass Lasso's database_registry for performance gains (350ms vs 5000ms)
//
//---------------------------------------------------------------------------

	//	Cache database_registry registry
	private reg => {
		var(::__ds_reg__)->isnota(::sqlite_db)
		? $__ds_reg__ = sqlite_db(database_database)
		return $__ds_reg__
	}

	//	Faster lookup than database_registry
	private get_dsinfo(
		database::string
	) => .reg->executeLazy(
		'SELECT 
			ds.name AS datasource,
			h.id 	AS id,
			h.name	AS host,
			h.port 	AS port,
			h.username,
			h.password,
			h.schema,
			"" as encoding
			
		FROM 	datasources AS ds,
				datasource_hosts AS h, 
				datasource_databases AS db
				
		WHERE h.id = db.id_host
		AND db.id_datasource = ds.id 
		AND db.alias = ' + database_qs(#database) + '
		LIMIT 0,1'
	)->foreach => {return #1}
	
	//	Faster lookup table specific
	private get_dsinfo(
		database::string,
		table::string
	) => .reg->executeLazy(
		'SELECT 
			ds.name AS datasource,
			h.id 	AS id,
			h.name	AS host,
			h.port 	AS port,
			h.username,
			h.password,
			h.schema,
			tb.encoding
			
		FROM 	datasources AS ds,
				datasource_hosts AS h, 
				datasource_databases AS db, 
				database_tables AS tb
		WHERE  h.id = db.id_host
		AND db.id_datasource = ds.id 
		AND tb.id_database = db.id
		AND db.alias = ' + database_qs(#database) + '
		AND tb.alias = ' + database_qs(#table) + '
		LIMIT 0,1'
	)->foreach => {return #1}
	
//-----------------------------------------------------------
//
// 	Issue SQL command
//
//-----------------------------------------------------------
	
	public sql(
		statement::string,maxrows::integer = .dsinfo->maxrows || 50
	) => {
		
		//	Clear old results
		.removeall
		
		local(dsinfo) =.'dsinfo'
		
		// Set to execute SQL
		#dsinfo->maxrows 	= #maxrows
		#dsinfo->action 	= lcapi_datasourceExecSQL
		#dsinfo->statement 	= #statement
		return .invoke => givenblock
	}

	public lazysql(statement::string) => {
		.sql = #statement
		return self
	}
	
	public sql=(statement::string) => {
		local(dsinfo) =.'dsinfo'
		#dsinfo->action 	= lcapi_datasourceExecSQL
		#dsinfo->statement 	= #statement
	}

	private store => {
		ds_connections->insert(.'key' = self)
	}

	public close => {
		.dsinfo->action = lcapi_datasourcetickle
		.'capi'->invoke(.dsinfo)

		.dsinfo->action = lcapi_datasourceCloseConnection
		.'capi'->invoke(.dsinfo)
	}
	
	public notyet => {
		local(w) = (givenblock ? givenblock->methodname->asstring)
		not #w ? #w = 'this'
		fail('Oops — '+#w+' still needs to be implemented')
	}
	
//-----------------------------------------------------------
//
// 	Invoke connector
//
//-----------------------------------------------------------	

	public invoke => {
	
		//	Close connection when not web_request not ideal, but safe.
		not web_request ? handle => {.close}
		
		//	Remove old results
		.removeall
	
		local(
			gb 		= givenblock,
			capi 	= .'capi',
			dsinfo 	= .'dsinfo',
			results	= array,
			s = 1,
		
			set,
			result,
			error,
			affected,
			
			index,
			cols,
			col 
		)
	
		fail_if(not #capi, 'No datasource: check -database, -table or -datasource')
		
		//	Store connection for re-use
		.store

		protect => {
			handle => {
				//	shared error per request
				#error = (: error_code, error_msg, error_stack)
				
				if(error_code) => {
					protect => {
						debug(#dsinfo->statement)
					}
					stdoutnl('\nds error: '+error_msg+'\n')
				}
			}
			#result = #capi->invoke(#dsinfo)			
			#result ? return #result
		}
		
		#error->get(1) ? fail(#error->get(1),#error->get(2))
		
		//! Set keycolumns now? Need by row for updates.
		.keycolumn = .keycolumn
				
		{
			#set = #dsinfo->getset(#s)
			#affected = integer(var(::__updated_count__))
			
			#set
			? #result = ds_result(self,#set,#dsinfo,0,#error,#s->ascopy)
			| #result = ds_result(indextable,staticarray,staticarray,staticarray,0,#affected,#error,#s->ascopy)

			//	Set result number
			#result->num = #s->ascopy
			
			#results->insert(#result)

			#s++ < #dsinfo->numsets 
			? currentcapture->restart  
		}()

		#gb ? .push(#results->asstaticarray)		
		#gb ? handle => {
			.pop
		}

		.'results' = #results->asstaticarray

		return (#gb ? #gb(#results->first)) or self

	}
	
	public results => .'results' 
	public removeall => { .'results' = staticarray }
	public first => .'results'->first || ds_result
	public last => .'results'->last || ds_result
	
//---------------------------------------------------------------------------------------
//
// 	legacy method support, perhaps should just be dropped.
//	supports all except: action_params and keycolumn_name (due to 'workingkeyfield_name' accessor)
//
//---------------------------------------------------------------------------------------

	public push(results::staticarray) => {
		local(scope) = map(
			::currentinline	= self, 
			::currentset 	= ((#results->size ? #results->first->set) || (:(:),(:),0))
		)
		inline_scopepush(#scope)
		result_push(#results)
	}
	
	public pop => {
		inline_scopepop
		result_pop 
	} 
		
//---------------------------------------------------------------------------------------
//
// 	Result iterator
//
//---------------------------------------------------------------------------------------

	public foreach => {
		local(gb) = givenblock
		.'results'->foreach => {#gb(#1)}
	}

	public do(gb::capture) => {
		.results->foreach => {
			#gb(#1)
		}
	}

//---------------------------------------------------------------------------------------
//
// 	inline support
//
//---------------------------------------------------------------------------------------

	public workingkeyfield_name => .keycolumn

//---------------------------------------------------------------------------------------
//
// 	key column setter
//
//---------------------------------------------------------------------------------------
	
	public keycolumn => {
		.'dsinfo'->keycolumns->size
		?	return .'dsinfo'->keycolumns->get(1)->get(1)
		|	return .'keycolumn'
	}
	public keycolumn=(col::string) 	=> {
		#col
		? .'dsinfo'->keycolumns = (:(:#col, lcapi_datasourceopeq, null))
		| .'dsinfo'->keycolumns = (:)

		return #col
	}

	public keycolumn(col::tag) => .keycolumn(#col->asstring)
	public keycolumn(col::string) => {
		.keycolumn = #col
		return self
	}
	

	private keyvalues => .keyvalues(.keycolumn = null)

	private keyvalues(p::pair) 		=> (:.keyvalue(#p))
	private keyvalues(p::integer) 	=> .keyvalues(.keycolumn = #p)
	private keyvalues(p::string) 	=> .keyvalues(.keycolumn = #p)
	private keyvalues(keys::trait_foreach) => {
		return (with p in #keys select .keyvalue(#p))->asstaticarray
	}
	
	private keyvalue(p::pair) => (:#p->name, lcapi_datasourceopeq,#p->value)

	private inputcolumns(p::trait_foreach) => {
		local(input) = array

		#p->foreach => {
			#input->insert((:#1->first, 0, .filterinput(#1->second)))
		}
		return #input->asstaticarray			
	}	

	private filterinput(p::any) => #p
	private filterinput(p::date) => #p->asstring 

//---------------------------------------------------------------------------------------
//
// 	Table operators
//
//---------------------------------------------------------------------------------------

	public tickle => {	
		.dsinfo->action = lcapi_datasourcetickle
		return .invoke
	}

	public info => {
		.dsinfo->maxrows = -1
		.dsinfo->action = lcapi_datasourceinfo
		return .invoke->last
	}
	
	public datasource	=> .dsinfo->hostdatasource
	public database 	=> .dsinfo->databasename
	public table 		=> .dsinfo->tablename
	public columns		=> .info->columns
	
	public database(name::tag) => .database(#name->asstring)
	public database(name::string) => {
		.dsinfo->databasename = #name->asstring
		return self
	}
	public table(name::tag) => .table(#name->asstring)
	public table(name::string) => {
		.dsinfo->tablename = #name->asstring
		return self
	}

	public maxrows => .dsinfo->maxrows
	public maxrows(max::integer) => {
		.dsinfo->maxrows = #max
		return self
	}

	public affected => .'results'->size ? .'results'->last->affected | 0
	public found	=> .'results'->size ? .'results'->last->found | 0
	
	
//---------------------------------------------------------------------------------------
//
// 	Execute
//
//---------------------------------------------------------------------------------------

	public execute(
		action::tag,
		table::string,
		keyvalues::staticarray,
		values::staticarray,
		firstrow::boolean=false
	) => {
		
		//	New dsinfo
		.dsinfo = .dsinfo->makeinheritedcopy

		//	Determine action
		match(#action) => {
			case(::add)		.dsinfo->action = lcapi_datasourceadd
			case(::update)	.dsinfo->action = lcapi_datasourceupdate
			case(::search)	.dsinfo->action = lcapi_datasourcesearch
			case(::delete)	.dsinfo->action = lcapi_datasourcedelete
			case return self
		}
		
		//	Set values
		.dsinfo->tablename 		= #table
		.dsinfo->keycolumns 	= (#keyvalues->size ? #keyvalues | .keyvalues)
		.dsinfo->inputcolumns 	= .inputcolumns(#values)
		
		//!debug('update keys' = .dsinfo->keycolumns)
		//!debug('update input' = .dsinfo->inputcolumns)
		
		local(out) = .invoke => givenblock 
				
		return #firstrow ? .firstrow | #out
	}

//---------------------------------------------------------------------------------------
//
// 	addrow
//
//---------------------------------------------------------------------------------------

	public addrow(p::pair,...) => .execute(::add,.table,staticarray,params,true) => givenblock
	public addrow(p::trait_keyedforeach) => .execute(::add,.table,staticarray,#p->eachpair->asstaticarray,true) => givenblock

	public addrow(totable::string,data::trait_keyedforeach) => .execute(::add,
		#totable,
		staticarray,
		#data->eachpair->asstaticarray,
		true
	) => givenblock

	public addrow(totable::tag,data::trait_keyedforeach) => .execute(::add,
		#totable->asstring,
		staticarray,
		#data->eachpair->asstaticarray,
		true
	) => givenblock

	public addrow(totable::string,data::staticarray) => .execute(::add,#totable,staticarray,#data,true) => givenblock

	public addrow(totable::tag,data::staticarray) => .execute(::add,#totable->asstring,staticarray,#data,true) => givenblock

//---------------------------------------------------------------------------------------
//
// 	Update row
//
//---------------------------------------------------------------------------------------
	
	public update(row::ds_row) => .execute(::update,
		#row->table,
		#row->keyvalues,
		#row->modified_data->eachpair->asstaticarray
	) => givenblock

	public updaterow(table::tag,data::trait_keyedforeach,key::any) => .updaterow(#table->asstring,#data,#key)

	public updaterow(table::string,data::trait_keyedforeach,key::any) => .execute(::update,
		#table,
		.keyvalues(#key),
		#data->eachpair->asstaticarray
	) => givenblock

	public updaterow(data::trait_keyedforeach,key::pair,...) => .execute(::update,
		.table,
		.keyvalues(tie((:#key), #rest || staticarray)->asstaticarray),
		#data->eachpair->asstaticarray
	) => givenblock

	public updaterow(data::trait_keyedforeach,key::any) => .execute(::update,
		.table,
		.keyvalues(#key),
		#data->eachpair->asstaticarray
	) => givenblock


//---------------------------------------------------------------------------------------
//
// 	Delete row
//
//---------------------------------------------------------------------------------------

	public delete(row::ds_row) => .execute(::delete,#row->table,#row->keyvalues,staticarray) => givenblock

	public deleterow(keyvalue::integer)	=> .execute(::delete,.table,.keyvalues(.keycolumn=#keyvalue),staticarray) => givenblock
	public deleterow(keyvalue::string)	=> .execute(::delete,.table,.keyvalues(.keycolumn=#keyvalue),staticarray) => givenblock
	public deleterow(keyvalue::pair)	=> .execute(::delete,.table,.keyvalues(#keyvalue),staticarray) => givenblock

	public deleterow(fromtable::string,keyvalue::integer) => .execute(::delete,#fromtable,.keyvalues(.keycolumn=#keyvalue)) => givenblock
	public deleterow(fromtable::string,keyvalue::string) => .execute(::delete,#fromtable,.keyvalues(.keycolumn=#keyvalue)) => givenblock
	public deleterow(fromtable::string,key::pair) => .execute(::delete,#fromtable,.keyvalues(#key)) => givenblock
	public deleterow(fromtable::string,keyvalues::staticarray) => .execute(::delete,#fromtable,#keyvalues) => givenblock

//---------------------------------------------------------------------------------------
//
// 	Get rows
//
//---------------------------------------------------------------------------------------

	public blankrow => ds_row(map,staticarray,staticarray,.dsinfo)

	public getrow(keyvalue) 					=> .getfrom(.table,#keyvalue)->first

	public getrows(keyvalue,...) 				=> .getfrom(.table,params)
	public getrows(keyvalues::trait_foreach) 	=> .getfrom(.table,#keyvalues)

	public getfrom(table::string,keyvalue::string) 		=> .execute(::search,#table,.keyvalues(.keycolumn=#keyvalue),staticarray)->rows
	public getfrom(table::string,keyvalue::integer) 	=> .execute(::search,#table,.keyvalues(.keycolumn=#keyvalue),staticarray)->rows
	public getfrom(table::string,key::pair) 			=> .execute(::search,#table,.keyvalues(#key),staticarray)->rows

	public getfrom(table::string,keyvalues::trait_foreach) 	=> {		
		local(
			params = array(
				-table = #table,
				-opbegin = 'or',
				-op = 'eq'
			)
		)

		with p in #keyvalues do {
			#p->isanyof(::pair,::keyword)			
			? #params->insert(#p)
			| #params->insert(.keycolumn = #p)
		}

		return .search(:#params->asstaticarray)->rows
		
	}

//---------------------------------------------------------------------------------------
//
// 	Search
//
//---------------------------------------------------------------------------------------	


	//public find(...) => .search(:#rest || staticarray)
	
	public search(...) => {
		.dsinfo->extend(:#rest || staticarray)
		.dsinfo->action = lcapi_datasourcesearch
		.keycolumn = ''		
		local(r) = .invoke => givenblock	
		return #r
	}

	public all(maxrows::integer=-1) => {
		.dsinfo->maxrows = #maxrows
		.dsinfo->action = lcapi_datasourcefindall
		return .invoke => givenblock		
	}

	public findrows(...) => .search(:#rest || staticarray)->rows

	public allrows(maxrows::integer=-1) => .all(#maxrows)->rows


//---------------------------------------------------------------------------------------
//
// 	Shortcuts
//
//---------------------------------------------------------------------------------------

	public first => .'results'->first
	public last	 => .'results'->last

	public firstrow => .rows->first
	public firstrow(col::string) => .rows->first->find(#col)
	public firstrow(col::tag) 	 => .rows->first->find(#col->asstring)

	public lastrow => .last->rows->last
	public lastrow(col::string) => .last->rows->last->find(#col)
	public lastrow(col::tag) 	=> .last->rows->last->find(#col->asstring)

	public rows => (.first->rows => givenblock) || staticarray
	public rows(type::tag) => (.first->rows(#type) => givenblock) || staticarray

//---------------------------------------------------------------------------------------
//
// 	SQL constructors
//
//---------------------------------------------------------------------------------------

	public select(...) 	=> select_statement(self)->select(:#rest || staticarray) => givenblock
	public where(...) 	=> select_statement(self)->where(:#rest || staticarray) => givenblock
	public insert(...)	=> insert_statement(self) => givenblock
	public update(...)	=> update_statement(self)->set(:#rest || staticarray) => givenblock

	public insertinto(table::string,row::map,update::boolean=false)	=> insert_statement(self)->into(#table)
																			->columns(#row->keys)
																			->onduplicate(#update)
																			->addrow(#row) => (givenblock || {})

	public updaterowin(table::string,row::map,keyvalue::any) => .update(self)->set(#row->keys)
																->where(.keycolumn = #keyvalue) => (givenblock || {})

}

//---------------------------------------------------------------------------------------
//
// 	Backwards compatibility parser
//	
//	Missing:
//		-inlinename	
//
//---------------------------------------------------------------------------------------

define dsinline(...) => {
	return ds(dsinfo->extend(:#rest || staticarray),true,params) => givenblock	
}

define dsinfo->extend(...) => {

	local(
		dsinfo 			= self,
		keycolumns 		= array,
		sortcolumns		= array,
		returncolumns	= array,
		columns 		= array,
		op 				= lcapi_datasourceopbw,
		name,val,keyvalue,isparam
	)

	with p in delve(#rest) do {
		//	Clean up legacy '-string' support
		if(#p->isa(::pair) && #p->first->isa(::string) && #p->first->beginswith('-')) => {
			#p->first->removeleading('-')
			#isparam = true
		else
			#isparam = false
		}
		
		//	Only evaluate params 
		if( #p->isa(::keyword) || #isparam) => {
			#name = #p->name
			#val = #p->value
			
			match(#name) => {
				case('keyvalue')
					#keycolumns->size 
					?	#keycolumns->last->get(3) = #val
					|	#keycolumns->insert((:null,lcapi_datasourceopeq,#val))
				case('keycolumn','keyfield')
					.keycolumn = #val
					#keycolumns->size 
					?	#keycolumns->last->get(1) = #val
					|	#keycolumns->insert((:#val,lcapi_datasourceopeq,null))						
				case('keyvalue')
					#keycolumns->size 
					?	#keycolumns->last->get(3) = #val
					|	#keycolumns->insert((:null,lcapi_datasourceopeq,#val))
				case('database')
					#dsinfo->databasename = #val
				case('table')
					#dsinfo->tablename = #val
				case('encoding')
					#dsinfo->hosttableencoding = #val
				case('host')
					#val->isa(::array)
					? #val->foreach => {
						#1->isanyof(::keyword,::pair) && #val := #1->value
						? match(#p->name) => {
							case('datasource')
								#dsinfo->hostdatasource 	= #val
							case('name')
								#dsinfo->hostname 			= #val
							case('port')
								#dsinfo->hostport 			= #val
							case('username')
								#dsinfo->hostusername 		= #val
							case('password')
								#dsinfo->hostpassword 		= #val			
							case('tableencoding')
								#dsinfo->hosttableencoding 	= #val
							case('schema')
								#dsinfo->hostschema 		= #val
							case('extra')
								#dsinfo->hostsextra 		= #val
						}
					}
											
				case('findall')
					#dsinfo->action = lcapi_datasourcefindall
				case('search')
					#dsinfo->action = lcapi_datasourcesearch
				case('add')
					#dsinfo->action = lcapi_datasourceadd
				case('random')
					#dsinfo->action = lcapi_datasourcerandom
				case('add')
					#dsinfo->action = lcapi_datasourceadd
				case('update')
					#dsinfo->action = lcapi_datasourceupdate
				case('delete')
					#dsinfo->action = lcapi_datasourcedelete
				case('show')
					#dsinfo->action = lcapi_datasourceinfo
				case('statementonly')
					#dsinfo->statementonly = true
				case('sql')
					#dsinfo->statement 	= #val
					#dsinfo->action 	= lcapi_datasourceExecSQL
				case('prepare')
					#dsinfo->statement 	= #val
					#dsinfo->action 	= lcapi_datasourcepreparesql
				case('skiprows','skiprecs','skiprecords')
					#dsinfo->skiprows 	= #val
				case('maxrecs','maxrecords')
					#val== 'all'
					?	#dsinfo->maxrows = -1
					|	#dsinfo->maxrows = integer(#val)
				case('sortcolumn','sortfield')
					#sortcolumns->insert(#val->asstring = lcapi_datasourcesortascending)
				case('sortorder')
					#sortcolumns->size 
					? match(#val) => {
						case('descending','desc')
							#sortcolumns->last->second = lcapi_datasourcesortdescending
						case('ascending','asc')
							#sortcolumns->last->second = lcapi_datasourcesortascending
						case('custom')
							#sortcolumns->last->second = lcapi_datasourcesortcustom
					}
				case('returncolumn','returnfield')
					#returncolumns->insert(#val)
				case('opbegin')
					#columns->insert((:'-opbegin',0,#val))
				case('opend')
					#columns->insert((:'-opend',0,'opend'))
				case('op','operator')
					match(#val) => {
						case('bw') 			#op = lcapi_datasourceopbw
						case('ew') 			#op = lcapi_datasourceopew
						case('cn','ct') 	#op = lcapi_datasourceopct
						case('ncn','nct') 	#op = lcapi_datasourceopnct
						case('lt') 			#op = lcapi_datasourceoplt
						case('lte') 		#op = lcapi_datasourceoplteq
						case('gt') 			#op = lcapi_datasourceopgt
						case('gte') 		#op = lcapi_datasourceopgteq
						case('eq') 			#op = lcapi_datasourceopeq
						case('neq') 		#op = lcapi_datasourceopnot
						case('ft') 			#op = lcapi_datasourceopft
						case('rx') 			#op = lcapi_datasourceoprx
						case('nrx') 		#op = lcapi_datasourceopnrx
					}
			}
		else(#p->isa(::pair))
			#columns->insert((:#p->name,#op,#p->value))
		}
	}
	
	#keycolumns->size		? #dsinfo->keycolumns 		= #keycolumns->asstaticarray
	#columns->size			? #dsinfo->inputcolumns	 	= #columns->asstaticarray
	#returncolumns->size	? #dsinfo->returncolumns 	= #returncolumns->asstaticarray
	#sortColumns->size		? #dsinfo->sortColumns 		= #sortColumns->asstaticarray
	
	return #dsinfo
	
}


?>