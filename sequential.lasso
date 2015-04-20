<?lassoscript
//-----------------------------------------------------------------------------------------
//
// 	Simple linked list
//
//-----------------------------------------------------------------------------------------

define sequential_node => type {
	data
		public name, 
		public value, 
		public next, 
		public prev
		
	public oncreate(p::pair) => {
		.name = #p->name
		.value = #p->value
	}
	
	public asstring => 'node('+.name+', next = '+(.next ? .next->name)+', prev = '+(.prev ? .prev->name)+')'
	public oncompare(rhs::sequential_node) => .'name'->oncompare(#rhs->name)
	public oncompare(rhs) => .'name'->oncompare(#rhs)
	
}

define sequential => type {
	
	trait {
		import	trait_contractible, trait_searchable, trait_expandable, trait_keyed, trait_foreach, trait_positionallykeyed, trait_keyedforeach 
	}

	data
		private first,
		private last,
		private node,
		private size = 0

	public insert(p::pair) => {
		local(
			node = .'node',
			key = #p->name,
			new,
			prev
		)	
		
		#node ? {
		
			if(#node == #key) => {
				//	Perfect
				#node->value = #p->value
				return
				
			else
				#prev = #node
			}
			
		}()

		#new = sequential_node(#p)
		#new->prev = #prev
			
		#prev ? #prev->next = #new | .'first' = #new
		
		.'last' = #new
		.'node' = #new
		.'size'++
	}

	public size => .'size'
	public first => .'first'->value
	public last => .'last'->value
	
	public get(key) => {
		{#1->isnota(::void) ? return #1}(.find(#key))
		fail(-1,'The specified key was not found')
	}
	
	public find(key) => {
		local(
			node = .'first'
		)

		#node ? {	
			#node->'name' == #key ? return #node->'value'		
			#node = #node->next
			#node ? currentCapture->restart
		}()
	}
	

	public remove(key) => {
		local(
			node = .'first'
		)

		#node ? {	
			if(#node->'name' == #key) => {
			
				#node->next ? #node->next->prev = #node->prev
				#node->prev ? #node->prev->next = #node->next
				
				.'node' = #node->next || #node->prev || void
				.'first' == #node ? .'first' = #node->next
				.'last' == #node ? .'last' = #node->prev
				.'size'--

				return 
			}	
			#node = #node->next
			#node ? currentCapture->restart
		}()
	}
	
	public removeall => {
		.'node'  = void
		.'first' = void
		.'last'  = void
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

	public foreach => {
		local(
			node = .'first',
			gb = givenblock
		)

		#node ? {	
			#gb(#node->value)
			#node = #node->next
			#node ? currentCapture->restart
		}()
	}
	
	public foreachkey => .keys->foreach => givenblock

	public foreachpair => {
		local(
			node = .'first',
			gb = givenblock
		)

		#node ? {	
			#gb(#node->name = #node->value)
			#node = #node->next
			#node ? currentCapture->restart
		}()
	}
}

//-----------------------------------------------------------------------------------------
//
// 	Sorted linked list / sorted map like object
//
//-----------------------------------------------------------------------------------------

define sortedpairs => type {
	parent sequential

	public insert(p::pair) => {
		local(
			node = .'node',
			key = #p->name,
			new,
			next,
			prev
		)	
		
		#node and not #next and not #prev ? {
		
			if(#node == #key) => {
				//	Perfect
				#node->value = #p->value
				return
				
			else(#node < #key && #node->next > #key) 
				//	Not to hot not too cold
				#prev = #node
				#next = #node->next
				
			else(#node < #key)
				//	Move to next node
				#node->next
				?	#node = #node->next
				|	#prev = #node

			else(#node > #key)
				//	Move to previous node
				#node->prev
				?	#node = #node->prev
				|	#next = #node
			}
			
			#node and not #next and not #prev 
			? currentCapture->restart
		}()

		#new = sequential_node(#p)
		#new->next = #next
		#new->prev = #prev
			
		#next ? #next->prev = #new | .'last' = #new
		#prev ? #prev->next = #new | .'first' = #new
		
		.'node' = #new
		.'size'++
	}	
		
}


?>