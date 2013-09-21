<?lassoscript
//=======================================================================================
//
//	Activerow for Lasso 9 — Free to use, license TBD
//
//..All rights reserved — K Carlton 2013.................................................

define activerow_pluralise_tables => true
define activerow_default_timestamp_format => 'YYYY-mm-dd HH-MM-SS'
define activerow_default_created_column => ''
define activerow_default_modified_column => ''
	
define activerow => type {
	
	data
		private ds,
		public database,
		public table,
		public row,
				
		// allow support for basic preferences
		public created_column 	= activerow_default_created_column,
		public modified_column 	= activerow_default_modified_column,
		public timestamp_format = activerow_default_timestamp_format,
		public generate_uuid	= false

//---------------------------------------------------------------------------------------
//
// 	Oncreate
//
//---------------------------------------------------------------------------------------

	public oncreate => {}
	public oncreate(row::ds_row) => {
		.row = #row
		return self
	}
	public oncreate(ds::ds) => {
//!		debug('oncreate ds')
		.'ds' = #ds
		return self
	}

	public oncreate(keyvalue::string) => {
		.row = .ds->getrow(#keyvalue)
//!		debug('oncreate keyvalue::string' = .isnew)
		return self
	}

	public oncreate(keyvalue::integer) => {
		.row = .ds->getrow(.table,#keyvalue) 
//!		debug('oncreate keyvalue::integer' = .isnew)
		return self
	}

	public oncreate(key::pair,...) => {
		.row = .ds->getrow(.table,#key)
		.updatedata(params)
//!		debug('oncreate keyvalue::integer' = .isnew)
		return self
	}
	
//---------------------------------------------------------------------------------------
//
// 	Reserved
//
//---------------------------------------------------------------------------------------

	public id 		=> .row->keyvalue
	public keyvalue => .row->keyvalue
	public created	=> .creation_column		? self(.creation_column)
	public modified => .modification_column	? self(.modification_column)
	public columns	=> {
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

	public updatedata(pair::pair,...) => .updatedata(
		tie(staticarray(#pair),#rest || staticarray)->asstaticarray
	)
	public updatedata(data::trait_keyedForEach) => .updatedata(#data->eachPair->asstaticarray)
	public updatedata(data::staticarray) => {	
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

	public invoke=(val,col::tag) 	=> .update(#col = #val)
	public invoke=(val,col::string) => .update(#col = #val)

	public set(pair::pair) 			=> .update(#pair)
	public set=(val,col::tag) 		=> .update(#col = #val)
	public set=(val,col::string) 	=> .update(#col = #val)
	
	public update(pair::pair,...) => .update(params)
	public update(data::trait_keyedforeach) => .update(#data->eachpair->asstaticarray)
	public update(values::staticarray) => {
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
		local(row) = .row
		
		//	Should we create a row when no data? — it should probably cause an error
		//	Inline just fails at the data source

		.generate_uuid ? #row->insert(
			.keycolumn = lasso_uniqueid
		)

		// Add timestamp when column specified
		.created_column ? #row->insert(
			.created_column = date->format(.timestamp_format)
		)

		// Add timestamp when column specified
		.modified_column ? #row->insert(
			.modified_column = date->format(.timestamp_format)
		)
		
		//	Allow for empty rows insert would normally fail if no data supplied 
		'mysqlds,sqliteds' >> .ds->datasource && not .find(.keycolumn) 
		? #row->insert(
			#row->keycolumn = null
		)
		#row = .ds->addrow(.table,#row->modified_data)
		#row ? .'row' := #row | fail('Unable to create row')
	}
		
//---------------------------------------------------------------------------------------
//
// 	Save modified data
//
//---------------------------------------------------------------------------------------

	public save(pair::pair,...) => {
		.updatedata(params)
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

	public invoke(col::tag) 		=> .'row'->find(#col->asstring)
	public invoke(col::string) 		=> .'row'->find(#col)
	public invoke=(val,col::tag) 	=> { .'row'->find(#col->asstring) = #val }
	public invoke=(val,col::string) => { .'row'->find(#col) = #val }
	
	
	public find(col::tag) 			=> .'row'->find(#col->asstring)
	public find(col::string) 		=> .'row'->find(#col)
	public find=(val,col::tag) 		=> { .'row'->find(#col->asstring) = #val }
	public find=(val,col::string) 	=> { .'row'->find(#col) = #val }


}


?>
