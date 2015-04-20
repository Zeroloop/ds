<?lassoscript
//---------------------------------------------------------------------------------------
//
// 	Alternative ds_row
//
//	2013-08-31 - Imported update methods from activerow
//
//---------------------------------------------------------------------------------------

define ds_row => type{

	data
		private ds::ds,						//	Reference to ds
		private cols,						//	Reference to columns::staticarray
		private row,						//	Reference to row::staticarray
		private index::trait_searchable,	//	Reference for fast lookups::map
		private dsinfo::dsinfo 				//	Reference to dsinfo
	
	data public modified_data::trait_searchable = map	//	Used to store modified values

	public database => .'dsinfo'->databasename
	public table 	=> .'dsinfo'->tablename
	public ds 		=> .'ds'

	public keycolumn => {
		! .'dsinfo' ? return ''
		local(cols) = .'dsinfo'->keycolumns
		#cols->size 
		? return #cols->get(1)->get(1)
		| return 'id'
	}
	
	public keyvalue => .raw(.keycolumn) 
	
	public keyvalue=(p::any)  	=> {
		local(i) := .'index'->find(.keycolumn)
		? .'row'->get(#i) = #p
	}

	public keyvalues => {
		local(
			out = array,
			col	
		)
		.'dsinfo'->keycolumns->foreach => {
			#col = #1->get(1)
			#out->insert((:#col,#1->get(2),.raw(#col->asstring)))
		}
		return #out->asstaticarray
	}

	public table=(p::tag) => {
		.table = #p->asstring
	}
	
	public table=(p::string) => {
		.'dsinfo'->tablename = #p	
	}

	public asstring => {
		return(
			.type->asstring + '(' +
			.cols->size + ' columns, ' +
			.row->join->size+' chars)'
		)
	}
	
	public oncreate => {
		.'index'= sequential
		.'cols'	= staticarray
		.'row'	= staticarray
	}
	
	public oncreate(index::trait_searchable,cols::trait_positionallykeyed,row::staticarray,dsinfo::null=null,ds::null=null)=>{
		.'index'= #index
		.'cols' = #cols
		.'row'	= #row
	}

	public oncreate(index::trait_searchable,cols::trait_positionallykeyed,row::staticarray,dsinfo::dsinfo)=>{
		.'index'	= #index
		.'cols' 	= #cols
		.'row'	 	= #row
		.'dsinfo' 	= #dsinfo
	}

	public oncreate(index::trait_searchable,cols::trait_positionallykeyed,row::staticarray,dsinfo::dsinfo,ds::ds)=>{
		.'index'	= #index
		.'cols' 	= #cols
		.'row'	 	= #row
		.'ds' 		= #ds
		.'dsinfo' 	= #dsinfo
	}

	
	public columns	=> .cols
	public cols		=> .'cols'
	public keys		=> .'modified_data'->keys

	public col(p::string) => .find(#p)

	public invoke(col::tag) 	=> .find(#col->asstring)
	public invoke(col::string) 	=> .find(#col)

	//	Get integer support			
	public get(i::integer) => {
		#i <= .'row'->size ? return .'row'->get(#i)
	}
	public get=(val,i::integer) => {
		local(col=.'cols'->get(#i))
		.'modified_data'->insert(#col=#val)
	}

	//	Unmodified values
	public raw(col::string) => {
		local(i) =.'index'->find(#col)
		#i ? return .'row'->get(#i)
	}

	//	Map behaviour
	public find(col::string) => {
		.'modified_data'->size ? {#1->isnota(::void) ? return #1}(.'modified_data'->find(#col))
		return .raw(#col)
	}
	public find(col::tag) => {
		return .find(#col->asstring)
	}	
	public find=(val,col::string) => {
		.'modified_data'->insert(#col=#val)
	}
	public find=(val,col::tag) => {
		.'modified_data'->insert(#col->asstring = #val)
	}
	public insert(pair::pair) => {
		.'modified_data'->insert(#pair)
	}

//---------------------------------------------------------------------------------------
//
// 	Update internal data
//
//---------------------------------------------------------------------------------------

	public invoke=(val,col::tag) 	=> .insert(#col = #val)
	public invoke=(val,col::string) => .insert(#col = #val)

	public updatedata(data::trait_keyedForEach) => .updatedata(#data->eachPair->asstaticarray)

	public updatedata(p::pair,...) => {	
		.insert(#p)
		#rest ? #rest->foreach => { .updatedata(#1) } 
	}
	public updatedata(values::trait_positionallyKeyed) => {
		#values->foreach => {
			#1->isa(::pair) ? .insert(#1) 
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
	
	public update(data::trait_keyedForEach) => .update(#data->eachPair->asstaticarray)

	public update(p::pair,...) => {	
		.updatedata(:params)
		.update
	}
	public update(values::trait_positionallyKeyed) => {
		.updatedata(#values)
		.update
	}
	public update => {
		if(.modified_data->size) => {
			.ds->update(self)
			.storeModified
		}		
	}

	// Clear out the modified_data store
	public storemodified => {
		.modified_data->forEachNode2 => {
			local(
				key   = #1->key,
				value = #1->value,
				index = .index->find(#key->asstring)
			)

			// Update data if item is there
			#index ? .row->get(#index) = #value
		}

		.modified_data = map
	}

//---------------------------------------------------------------------------------------
//
// 	delete row
//
//---------------------------------------------------------------------------------------
	
	public delete => .ds->delete(self)

//---------------------------------------------------------------------------------------
//
// 	Retun self as map or array (includes modified data)
//
//---------------------------------------------------------------------------------------	
	
	public asmap => {
		local(
			map 		= map,
			modified 	= .modified_data,
			cols 		= .'cols',
			row 		= .'row'
		)

		//	Build map
		with i in #cols->size to 1 by -1 do {
			#map->insert(
				#cols->get(#i)=#row->get(#i)
			)
		}

		//	Include any modified values
		with key in #modified->keys do {
			#map->insert(#key = #modified->find(#key))
		}
		
		return #map
	}
	
	public asarray => {
		local(
			array = array,
			cols = .'cols',
			row = .'row',
			i = 1
		)
		
		//	Don't forget modified		
		{	#array->insert(#cols->get(#i)=#row->get(#i))
			#i++ < #cols->size ? currentcapture->restart
		}()
		
		return #array
	}
	
}

// Work around for older versions of 9.2
// map->forEachNode should be public in 9.2.7
protect => {\map}
define map->forEachNode2 => .forEachNode => givenBlock

define json_serialize(p::ds_row) => json_serialize(#p->asmap)


?>
