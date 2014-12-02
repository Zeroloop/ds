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
		public generate_uuid      = false

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

	// getrow should be perhaps renamed here

	public getrow(key::pair,...) => {
		.row = .ds->getrow(:params)
		.updatedata(:params)
		return self
	}

	public getrow(keyvalues::staticarray) => {
		.row = .ds->getrow(:#keyvalues)
		.updatedata(:#keyvalues)		
	}

	public getrow(keyvalue::string) => {
		if(#keyvalue) => {
			.row = .ds->getrow(#keyvalue)
			.updatedata(.keycolumn = #keyvalue)
		}
		return self
	}

	public getrow(keyvalue::integer) => {
		if(#keyvalue) => {
			.row = .ds->getrow(#keyvalue)
			.updatedata(.keycolumn = #keyvalue)
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
	public asnew => {
		local(out) = self->ascopy
		#out->row->keyvalue = null
		#out->updatedata(#out->row->asmap)
		return #out
	}
	
	public table => {
		.'table' 	? return .'table'		//	Use specified table
		.ds->table	? return .ds->table		//	Default to DS table

		//	Determin table based on type
		local(t) = .type->asstring->lowercase &

		! #t->endswith('s') && activerow_pluralise_tables
		? #t->append('s')
		
		return .'table' := #t
	}

	public row => .'row' || .'row' := .ds->blankrow

//---------------------------------------------------------------------------------------
//
// 	Return relevant ds
//
//---------------------------------------------------------------------------------------

	public ds => {
	//	handle => { debug('.ds->type' = .'ds'->type)}
	
		.'ds'->isa(::ds) 	? return .'ds'
		.row->ds->isa(::ds) ? return .'ds' := .row->ds
		
		if(.database && .table) => {
			return .'ds' := ds(.database,.table)
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
	
	public delete => not .isnew ? .row->delete

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

		local(row) = .row

		// Do nothing when new
		.isnew ? return
		
		// Nothing has changed so do nothing
		not #row->modified_data->size ? return

		// Add timestamp when column specified
		.modified_column ? #row->insert(
			.modified_column = date->format(.timestamp_format)
		)
		
		// Only update when modified (perhaps the above shouldn't be considered)/
		#row->update

		// alt approach, update via row
		// #row->modified_data->size ? #row->update(#row->modified_data)
	}

//---------------------------------------------------------------------------------------
//
// 	Create row
//
//---------------------------------------------------------------------------------------

	public create => {
		local(
			row = .row,
			now = date,
			key 
		)
		
		//	Should we create a row when no data? — it should probably cause an error
		.generate_uuid ? #row->insert(
			.keycolumn = lasso_uniqueid
		)

		//	Check if should use UTC
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

		#row = .ds->addrow(.table,#row->modified_data)

		// If keyvalue is forced we must load the row
		if(!#row && #key && ! .keyvalue) => {
			#row = .ds->getfrom(.table,.keycolumn = #key)->first
		}

		#row ? .'row' := #row | fail('Unable to create row (ensure correct ->keycolumn(\'name\') is specified)')
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


?>