<?lassoscript
//-----------------------------------------------------------------------------------------
//
// 	base table — reduced functionality to a tree / map but better performance.
//
//-----------------------------------------------------------------------------------------

define table => type {
	
	trait { 
		import	trait_contractible, trait_searchable, trait_expandable, trait_keyed, trait_keyedforeach 
	}

	data
		private index = staticarray_join(256,void) // 256 table size
 
	public insert(p::pair) => {
		local(
			key = #p->name,
			i = .index(#key),
			node = .'index'->get(#i) || .newnode
		)
		
		#node->insert(#p)
		.'index'->get(#i) = #node
	}
	public get_index(key::any) => {
		return .'index'->get(.index(#key))
	}
	public set_index(key::any,node) => { 
		.'index'->get(.index(#key->asstring)) = #node 
	}	
	public size => {
		local(s = 0)
		.'index'->foreach => {
			#1 ? #s += #1->size
		}
		return #s
	}
	public keys => {
		local(
			keys = array
		)
		.foreachpair => {
			#keys->insert(#1->name)
		}
		return #keys->asstaticarray
	}
	public get(key) => {
		local(v) = .find(#key)
		
		#v->isa(::void) 
		? fail(-1,'The specified key does not exist')
		
		return #v
	}

	public find(key) => {
		local(
			node = .get_index(#key)
		)
		#node ? return #node->find(#key)
	}
	public remove(key) => {
		local(
			node = .get_index(#key)
		)
		#node ? return #node->remove(#key)
	}
	public removeall => {
		local(i) = 1
		.foreach => {
			if(#1) => {
				 .index->get(#i) = void
				 #1->removeall
			}
			#i++
		}
	}

	// Value this should work off values instead of pairs
	
	public foreach => {
		local(gb) = givenblock
		.'index'->foreach => {
			#1 ? #1->foreach => #gb
		}
	}
	public foreachkey => .keys->foreach => givenblock
		
	public foreachpair => {
		local(gb) = givenblock
		.'index'->foreach => {
			#1 ? #1->foreachpair => #gb
		}
	}
}

//-----------------------------------------------------------------------------------------
//
// 	hashtable — very fast for large number of keys (2 - 3x faster than map), 
//				slowish create time (16 micros vs 5 for map) namely due to index
//
//-----------------------------------------------------------------------------------------

define hashtable => type {

	data
		private index = staticarray_join(1024,void) // 1024 table size
			
	parent table
	
	public index(p::string) 	=> #p->hash->abs % .'index'->size + 1	
	public index(p::integer) 	=> #p % .'index'->size + 1
	public index(p::bytes) 		=> #p->crc % .'index'->size + 1
	public index(p::any) 		=> .index(bytes(#p))
	
	public newnode => sequential
	
}

//---------------------------------------------------------------------------------------
//
// 	indextable — indexes keys based soley on first character then straight scans
//				 extremely fast lookup outweighs collision issues, good for randomish
//				 keys < 100 typically faster than map, create time 8 micros or so.
//
//---------------------------------------------------------------------------------------

define indextable => type {

	parent table

	public index(p::string) 	=> #p->integer % .'index'->size + 1	
	public index(p::integer) 	=> #p % .'index'->size + 1
	public index(p::bytes) 		=> #p->crc % .'index'->size + 1
	public index(p::any) 		=> .index(#p->asstring)
		
	public newnode => sequential

}

?>