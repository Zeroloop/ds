<?lassoscript
//=======================================================================================
//
//	Activerow for Lasso 9 — Free to use, license TBD
//
//..All rights reserved — K Carlton 2013.................................................

define activerow_pluralise_tables => true
define activerow_default_timestamp_format => 'yyyy-MM-dd HH:mm:ss'
define activerow_default_created_column => ''
define activerow_default_modified_column => ''

define activerow_mysqlds_lazy_mode => 0

// When enabled DS will get the row using a select statement
define activerow_mysqlds_lazy_select => activerow_mysqlds_lazy_mode 

// When enabled DS will not reload the row after a ->save (update)
// This results in signifigant performance gains however auto populated columns 
define activerow_mysqlds_lazy_update => activerow_mysqlds_lazy_mode

// When enabled DS will not reload the row after a ->save (create)
// This can result in a signigant performance boost — only the LAST_INSERT_ID will be retrieved (not the rest of the row)
define activerow_mysqlds_lazy_create => activerow_mysqlds_lazy_mode 

define activerow => type {
	
	data
		private ds,
		public database,
		public table,
		public row,
				
		// allow support for basic preferences
		public created_column     = activerow_default_created_column,
		public modified_column    = activerow_default_modified_column,
		public timestamp_format   = activerow_default_timestamp_format,
		public timestamp_timezone = '',
		public generate_uuid      = false,

		public allow_lazy_select = 0, 
		public allow_lazy_create = 0, 
		public allow_lazy_update = 0

//---------------------------------------------------------------------------------------
//
// 	Oncreate
//
//---------------------------------------------------------------------------------------

	public oncreate => {}

	public oncreate(p::void) => {}

	public oncreate(row::ds_row) => {
		.row = #row
		return self
	}

	public oncreate(keyvalue::string) => {
		.getrow(#keyvalue)
		return self
	}

	public oncreate(keyvalue::integer) => {
		.getrow(#keyvalue)
		return self
	}

	public oncreate(key::pair,...) => {
		.getrow(:params)
		return self
	}

	public oncreate(ds::ds,...keyvalues) => {
		.ds = #ds
		#keyvalues ? .getrow(:#keyvalues)
		return self
	}

	public oncreate(databasetable::tag,...keyvalues) => {
		local(s) = #databasetable->asstring->splitextension('.')

		if(#s->value) => {
			// Set a new ds connection
			.ds = ds(#databasetable)
			#keyvalues ? .getrow(:#keyvalues)
			return self
		else
			// Force a ::database.table signature
			fail(-1,'Table not specified, format is active_row(::database.table)')
		}
	}
	
	public getrow(key::pair,...) => {

		local(params) = params

		// Deal with MySQL casting string columns as integers on comparison
		if(.allow_lazy_select) => {
			
			local(where) = (
				with p in #params 
				where #p->isa(::pair)
				select pair(#p->name, #p->value->isa(::integer) ? #p->value->asstring | #p->value)
			)->asstaticarray 

			.row = .ds->select->where(: #where )->limit(0, 1)->rows->first

		else
			.row = .ds->getrow(: #params )
		}

		.updatedata(: #params )

		return self
	}

	public getrow(keyvalues::staticarray) => {
		.row = .ds->getrow(:#keyvalues)
		.updatedata(:#keyvalues)		
	}

	public getrow(keyvalue::string) => .getrow(.keycolumn = #keyvalue)

	public getrow(keyvalue::integer) => .getrow(.keycolumn = #keyvalue)

	public getrow => {
		if(.modified_data->size) => {
			return .getrow(:
						( with pair in .modified_data->eachpair 
						  select #pair 
						)->asstaticarray
					)

		}

		return self 
	}

	// support blindly relayed params
	public getrow(key::void) => {}
	
//---------------------------------------------------------------------------------------
//
// 	Reserved
//
//---------------------------------------------------------------------------------------

	public id       => .row->keyvalue
	public keyvalue => .row->keyvalue
	public created  => .created_column		? .find(.created_column)
	public modified => .modified_column		? .find(.modified_column)

	public columns  => {
		local(cols) = .row->columns
		
		#cols->size ? return #cols
		
		return .ds->columns || #cols

	}
	
	public isnew => not .keyvalue
	
	public isnotnew => ! .isnew

	public allow_lazy_select => (.'allow_lazy_select' || activerow_mysqlds_lazy_select && .ds->datasource == 'mysqlds')

	public allow_lazy_create => (.'allow_lazy_create' || activerow_mysqlds_lazy_create && .ds->datasource == 'mysqlds')
	
	public allow_lazy_update => (.'allow_lazy_update' || activerow_mysqlds_lazy_update && .ds->datasource == 'mysqlds')

	public asnew => {
		local(out) = self->ascopy
		#out->row->keyvalue = null
		#out->updatedata(#out->row->asmap)
		return #out
	}
	
	public table => {
		//	Use specified table
		.'table' 	          
		? return .'table'		
		
		//	Default to DS table
		.ds && .ds->table
		? return .'table' := .ds->table		

		//	Determin table based on type
		local(t) = .type->asstring->lowercase &

		! #t->endswith('s') && activerow_pluralise_tables
		? #t->append('s')

		// Set from name
		return .'table' := #t
	}

	public row => .'row' || .'row' := .ds->blankrow

//---------------------------------------------------------------------------------------
//
// 	Return relevant ds
//
//---------------------------------------------------------------------------------------

	public ds => {

		// Return internal ds
		.'ds'->isa(::ds) 
		? return .'ds'
		
		// Return rows ds
		.'row'->isa(::ds_row) && .'row'->ds->isa(::ds) 
		? return .'ds' := .'row'->ds

		// Use specified .table 
		if(.database && .'table') => {
			return .'ds' := ds(.database,.'table')
		else(.database)
			fail('.table not specified')
		else
			fail('.database not specified')
		}
	}
	
//---------------------------------------------------------------------------------------
//
// 	row accessors
//
//---------------------------------------------------------------------------------------

	public keycolumn		=> .row->keycolumn
	public keyvalue			=> .row->keyvalue
	public modified_data	=> .row->modified_data

//---------------------------------------------------------------------------------------
//
// 	delete row
//
//---------------------------------------------------------------------------------------
	
	public delete => {
		local(row) = .row 

		// Force row table
		#row->table = .table 		

		not .isnew ? #row->delete
		
	}

//---------------------------------------------------------------------------------------
//
// 	Update internal data
//
//---------------------------------------------------------------------------------------

	public updatedata(data::trait_keyedForEach) => .updatedata(#data->eachPair->asstaticarray)
	public updatedata(p::pair,...) => {	
		.row->insert(#p)
		#rest ? #rest->foreach => { .updatedata(#1) } 
	}
	public updatedata(data::trait_positionallyKeyed) => {	
		local(row) = .row			
		#data->foreach => {
			#1->isa(::pair) ? #row->insert(#1) 
		}
	}

//---------------------------------------------------------------------------------------
//
// 	Update internal data and row
//
//---------------------------------------------------------------------------------------

	public keyvalue=(p::any) => {
		if(.row) => {
			.row->keyvalue = #p 
		else(.keycolumn)
			.insert(
				.keycolumn = #p
			)
		}
	}

	public set(pair::pair) 			=> .update(#pair)
	public set=(val,col::tag) 		=> .update(#col = #val)
	public set=(val,col::string) 	=> .update(#col = #val)
	
	public update(data::trait_keyedforeach) => .update(#data->eachpair->asstaticarray)

	public update(pair::pair,...) => {
		.updatedata(:params)
		.update
	}
	public update(values::trait_positionallyKeyed) => {
		.updatedata(#values)
		.update 
	}
	
	public update => {

		local(
			now = date,
			row = .row
		)

		// Do nothing when new
		.isnew ? return

		//	Check for specific timezone (ie. UTC)
		.timestamp_timezone ? #now->timezone = .timestamp_timezone

		// Force row table
		#row->table = .table 

		// Nothing has changed so do nothing
		not #row->modified_data->size ? return

		// Add timestamp when column specified
		.modified_column ? #row->insert(
			.modified_column = #now->format(.timestamp_format)
		)

		// Patch lost rows — normally from ds(::database)->rows
		! #row->table && .table ? #row->table = .table 

		if(.allow_lazy_update && .row->keyvalues->size) => {
			// Only execute the update, don't retrieve the changed row
			.ds->update_statement->set( .modified_data )->where( .row->keyvalues )->do_when_where 

			// Merge the modified stack
			#row->merge_after_lazy(.ds)
		else 	
			// Only update when modified (perhaps the above shouldn't be considered)
			#row->update
		}
	}

	public update_lazy(...) => {

		local(
			params = params
		)

		.do_lazy => {
			// Call standard save
			return .update(: #params )
		}
	}	

//---------------------------------------------------------------------------------------
//
// 	Create row
//
//---------------------------------------------------------------------------------------

	public create => {
		local( 
			keycolumns = .ds->dsinfo->keycolumns,
			row        = .row,
			now        = date,
			key  
		)

		// Key values should not be used on add (::mysqlds can return random rows)
		handle => { .ds->dsinfo->keycolumns = #keycolumns }
		.ds->dsinfo->keycolumns = staticarray
  
		//	Should we create a row when no data? — it should probably cause an error
		.generate_uuid ? #row->insert(
			.keycolumn = lasso_uniqueid
		)

		//	Check for specific timezone (ie. UTC)
		.timestamp_timezone ? #now->timezone = .timestamp_timezone

		#key = .find(.keycolumn)

		// Add timestamp when column specified
		.created_column ? #row->insert(
			.created_column = #now->format(.timestamp_format)
		)

		// Add timestamp when column specified
		.modified_column ? #row->insert(
			.modified_column = #now->format(.timestamp_format)
		)
		
		//	Allow for empty rows insert would normally fail if no data supplied 
		'mysqlds,sqliteds' >> .ds->datasource && not #key && ! #row->modified_data->size 
		? #row->insert(
			#row->keycolumn = null
		)		

		if(.allow_lazy_create) => {
			
			// Store the blank row
			.row = #row 

			// Only execute the insert, don't retrieve the new row
			local(keyvalue) = .ds->sql(
				.ds->insert_statement->values( .modified_data )->statement + '; SELECT LAST_INSERT_ID() as ID'
					)->lastrow(::ID)

			// Add the new keyvalue
			#row->insert(
				.keycolumn = #keyvalue
			)

			// Merge the modified stack
			#row->merge_after_lazy(.ds) 

		else 	
			#row = .ds->addrow(.table, #row->modified_data)

			// If keyvalue is forced we must load the row
			if(!#row && #key && !.keyvalue) => {
				#row = .ds->getfrom(.table, .keycolumn = #key)->first
			}

			#row ? .'row' := #row | fail('Unable to create row (ensure correct ->keycolumn(\'name\') is specified)')
		}

	}


	public create_lazy(...) => {

		local(
			params = params
		)

		.do_lazy => {
			// Call standard save
			return .create(: #params )
		}
	}	
		
//---------------------------------------------------------------------------------------
//
// 	Save modified data
//
//---------------------------------------------------------------------------------------

	public save(data::trait_keyedForEach) => {
		.updatedata(#data)
		return .save 
	}

	public save(pair::pair,...) => {
		.updatedata(:params)
		return .save
	}
 
	public save(ds::ds=.ds) => {
		local(row) = .row
	
		if(#row->keyvalue) => {
			.update
		else
			.create
		}
		return self
	}

	public save_lazy(...) => {

		local(
			params = params
		)

		.do_lazy => {
			// Call standard save
			return .save(: #params )
		}
	}	

//---------------------------------------------------------------------------------------
//
// 	Force lazy behaviour
//
//---------------------------------------------------------------------------------------

	public do_lazy => {

		local(
			// Set locals to restore
			allow_lazy_create = .'allow_lazy_create',
			allow_lazy_update = .'allow_lazy_update',
			gb                = givenblock
		)

		handle => {
			// Restore data attributes
			.allow_lazy_create = #allow_lazy_create
			.allow_lazy_update = #allow_lazy_update
		}

		// Override data attributes
		.allow_lazy_create = 1
		.allow_lazy_update = 1	

		return #gb()	

	}

//---------------------------------------------------------------------------------------
//
// 	Friendly accessors
//
//---------------------------------------------------------------------------------------

	public invoke(col::tag) 		=> .row->find(#col->asstring)
	public invoke(col::string) 		=> .row->find(#col)
	public invoke=(val,col::tag) 	=> { .row->find(#col->asstring) = #val }
	public invoke=(val,col::string) => { .row->find(#col) = #val }

	
	public find(col::tag) 			=> .row->find(#col->asstring)
	public find(col::string) 		=> .row->find(#col)
	public find=(val,col::tag) 		=> { .row->find(#col->asstring) = #val }
	public find=(val,col::string) 	=> { .row->find(#col) = #val }

	//	Unmodified values
	public raw(col::string) => .row->raw(#col)
	public raw(col::tag) => .row->raw(#col->asstring)

//---------------------------------------------------------------------------------------
//
// 	Retun self as map or array (includes modified data)
//
//---------------------------------------------------------------------------------------
	
	public asmap => .row->asmap
	public asarray => .row->asarray

}

define json_serialize(p::activerow) => json_serialize(#p->asmap)

::json_encode->istype
? define json_encode->encodeValue(p::activerow) => .encodeValue(#p->asmap)

::json_encode_utf8->istype
? define json_encode_utf8->encode(p::activerow) => .encode(#p->asmap)


?>
