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
	
	// always return untouched value
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
			#out->insert((:#col,#1->get(2),.find(#col)))
		}
		return #out->asstaticarray
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
	
	public oncreate(index::trait_searchable,cols::trait_foreach,row::staticarray)=>{
		.'index'= #index
		.'cols' = #cols
		.'row'	= #row
	}

	public oncreate(index::trait_searchable,cols::trait_foreach,row::staticarray,dsinfo::dsinfo)=>{
		.'index'	= #index
		.'cols' 	= #cols
		.'row'	 	= #row
		.'dsinfo' 	= #dsinfo
	}

	public oncreate(index::trait_searchable,cols::trait_foreach,row::staticarray,dsinfo::dsinfo,ds::ds)=>{
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
		local(i) = .'index'->find(#col)
		#i ? return .'row'->get(#i)
	}
	public find(col::tag) => {
		return .find(#col->asstring)
	}	
	public find=(val,col::string) => {
		.'modified_data'->insert(#col=#val)
	}
	public insert(pair::pair) => {
		.'modified_data'->insert(#pair)
	}

//---------------------------------------------------------------------------------------
//
// 	Update internal data
//
//---------------------------------------------------------------------------------------

	public updatedata(pair::pair,...) => .updatedata(tie(staticarray(#pair),#rest || staticarray)->asstaticarray)
	public updatedata(data::trait_keyedForEach) => .updatedata(#data->eachPair->asstaticarray)
	public updatedata(values::staticarray) => {
		#values->foreach => {
			#1->isa(::pair) ? .insert(#1) 
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
	
	public update(pair::pair,...) => .update(tie(staticarray(#pair),#rest || staticarray)->asstaticarray)
	public update(data::trait_keyedForEach) => .update(#data->eachPair->asstaticarray)
	public update(values::staticarray) => {
		.updatedata(#values)
		.update
	}
	public update => {
		//!debug('ds_update' = .modified_data)
		.modified_data->size
		? .ds->update(self)
		
		//	? .ds->execute(::update,.table->asstring,.keyvalues,.modified_data->eachpair->asstaticarray)
	
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
			row 		= .'row',
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
?>