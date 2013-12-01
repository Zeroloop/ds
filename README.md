#Datasource

Datasource (ds) — a modern high performance replacement for Lasso inline

To install export to your LassoApp folder:

	git clone https://github.com/zeroloop/ds /var/lasso/home/LassoApps/ds

or:
	
	svn export https://github.com/zeroloop/ds /var/lasso/home/LassoApps/ds

or:

	wget https://github.com/zeroloop/ds/archive/master.zip /var/lasso/home/LassoApps/ds.zip

Full documentation online here: http://goo.gl/CYiKzX

# Working with Datasource — the ds type

The primary component of Datasource is the ds type, this is used to connect to and interact with data sources.

## Connecting to a data source

When using ds to connect to a data source there are a number of approaches you can take. 
The most convenient way is with the below signature which leverages Lasso Admin and the configuration specified there:

```lasso
	ds(::database.table) or datasource(::database.table)
```

The first part of the tag specifies the database name and the second part the default table. These details are then used to lookup the host details using an optimised sqlite query. ::tags are used throughout Datasource due to the input restrictions they enforce (encouraging good naming conventions) and the clean distinct style they provide. That said, you can also use the below:

```lasso
	ds('database','table')
```

The fastest method to specify the data source is to do so directly and bypass Lasso admin:

```lasso
	ds(::mysqlds,'127.0.0.1',::database.table,'user','pass')
```

This is effectively one less database call (the host information search in Lasso Admin) and allows you to skip configuring your database in Lasso Admin completely. You don't need to specify a table, but when one is specified the table becomes the default table for the data source.

You can also use -named parameters:

```lasso
ds(
  -host = '127.0.0.1',
  -database = 'database',
  -table = 'table',
  -username = 'username', -password = 'password'
)
```

The full list of natively supported -params and defaults are:

```lasso
	-datasource::string='mysqlds',
	-database::string=''
	-table::string=''
	-keycolumn::string='id'
	-sql::string=''
	-host::string=''
	-port::integer=3306
	-username::string=''
	-password::string=''
	-schema::string=''
	-key::string=''
	-encoding::string='UTF-8'
	-maxrows::integer=50
```

## Inline support

Datasource supports classic inlines in two ways. 

Inline query syntax. 
Firstly, classic inline commands are supported — so substituting inline with dsinline will allow you to take advantage of connection pooling and faster host lookups:

```lasso
dsinline(
 -database = 'db',
 -table ='table', 
 'this' = 'apple', 
 -search
) => {...}
```

Result handler.
Secondly, if you prefer to use inline for the database connection then you can still leverage the result handler to work with the results.

```lasso
inline(...) => {
	with row in result->rows do {
		// do stuff with #row
	}
}
```

Using ds in either manner will lead to improvements — more so when combined. The degree of improvements depend the number of columns and rows you're working with and the response time of the data source.

## Making ds connections convenient

As opposed to specifying the connection details for each call, it makes sense to define ds connections for reuse. If a table is specified then this becomes the default table for the data source.

```lasso
	define store_ds => ds(::store.products)
```

This approach allows you to manage all of your connections within a single file independent of Lasso Admin and the current Lasso Instance. From then on you can reference the ds anywhere in your code:

```lasso
	with row in store_ds->all->rows do {
		// do something with each #row
	}
```

You can also assign it to a local to work with:

```lasso
	local(store_ds) = ds(::store.products)
```

## Specifying tables

You can reference alternative tables via the ->table(::tag) method — it returns a reference to the ds making all of the standard methods applicable to that table:

```lasso
with row in store_ds->table(::users)->all->rows do {
	// do something with each user
}
```

There's also no harm in stacking multiple ds definitions like so:

```lasso
	define store_ds   => ds(::store.products)
	define product_ds => store_ds->table(::products)
	define user_ds    => store_ds->table(::users)
```

The above approach allows you to relocate databases and tables without having to update your working code. Your code will still refer to product_ds even after it's been moved to a different server, database or has been simply renamed. The above definitions would only be loaded once at startup (unless being redefined).

## Specifying key columns

The default key column is id — you can also specify an alternative key columns:

```lasso
	ds(::store.products)->keycolumn(::guid)
	ds(::store.products)->keycolumn('guid')
```

Or like this:

	ds(
	   -database = 'store',
	   -table = 'products',
	   -keycolumn = 'guid'
	)

## Searching the data source

The following methods invoke the data source and stores the results internally within Datasource. They also return a self reference allowing chainability and convenient querying of the ds type.

####-> sql(statement::string,max::integer=50)::ds
Execute the specified sql statement/s — if the string contains multiple SQL statements multiple result sets are stored. Multiple result sets can be accessed via the ->results method. By default ->rows returns the rows from the first result set.

```lasso
	with row in product_ds->sql(`
		SELECT *
		FROM products 
		WHERE brand = "example"
	`)->rows do {
		// do something with #row
	}
```

Once working with rows you can also use Lasso's query syntax:

```lasso
	with row in product_ds->sql(...)->rows
	where #row(::name) >> 'example' do {
		// do something with #row
	}
```

####-> search(...)::ds
This allows for search input using classic inline parameters.

####-> all(max::integer=-1)::ds
Finds all rows from the table limited.

## Methods that return rows

The following invoke the data source and return a static array containing the found rows.

####-> findrows(...)::staticarray
This allows for search input using classic inline parameters using classic inline parameters.

####-> allrows(max::integer=-1)::staticarray
Returns all rows from the table limited to all rows by default.

## Methods that return active_statements.

####-> where(equals::pair,,..), where(query::string,...)
Initialises the select_statement constructor — see the relevant portion of this document.

```lasso
    product_ds->where('brand' = 'example')
    product_ds->where('brand LIKE "example"')
```
####-> select(column::tag,column::tag,..), select(columns::trait_foreach)
Also, initialises the select_statement constructor — see the relevant portion of this document.

```lasso
    product_ds->select(::id,::description)->where('brand' = 'example')
```

## Retrieving rows using key values

By default ds assumes that the key column is id. This can be overridden by providing a pair to ->getrow or by specifying -keycolumn or ->keycolumn(::thecolumn)when defining the ds.

## Get single row matching key value

Return the first (and typically only) row matching the supplied key value:

####-> getrow(keyvalue::integer)::ds_row or ::void
####-> getrow(keyvalue::string)::ds_row or ::void 
####-> getrow(keyvalue::pair)::ds_row or ::void

```lasso
	// Get one row with an id of 3
	local(row) = store_ds->getrow(3)

	// Get one row where keycolumn uuid matchings 
	local(row) = store_ds->getrow(
	    'guid' = '8df6cff4-34f5-46b5-84d1-abe0e960cee0'
	)
```

## Get multiple rows matching multiple key values

You can retrieve multiple rows matching the supplied key values. A staticarray is returned containing any matched rows. If it is empty no rows were matched.

####-> getrows(keyvalue::integer,...)::staticarray
####-> getrows(keyvalue::string,...)::staticarray
####-> getrows(keyvalues::trait_foreach)::staticarray

	// Get rows with id of 1, 2 or 3
	local(rows) = ds(::store.users)->getrows(1,2,3)

	// Get rows with id of 1, 2 or 3
	local(ids) = array(1,2,3,7,9)
	local(rows) = ds(::store.users)->getrows(#ids)

## Modifying the data source

The most straightforward way of modifying rows is either via rows themselves, with activerow or an update_statement — all of which are outlined later in this document. It more convenient to work directly with ds_row and activerow which leverage these methods.

## Update row

####-> updaterow(data::map / array,key::integer)
####-> updaterow(data::map / array,key::string)
####-> updaterow(data::map / array,key::pair)

## Update the specified row and table with the supplied data.

####-> updaterow(intable::tag,data::map / array,key::integer)
####-> updaterow(intable::tag,data::map / array,key::string)
####-> updaterow(intable::tag,data::map / array,key::pair)

Update the specified row and table with the supplied data.

##Add row

####-> addrow(p::pair,p2::pair,...)
####-> addrow(p::map)

Add a row to the current table.

####-> addrow(totable::string,data::map / array)
####-> addrow(totable::tag,data::map / array)

Add a row to the specified table.

##Delete row

####-> deleterow(key::integer)
####-> deleterow(key::string)
####-> deleterow(key::pair,...)

Delete the specified row from the current table.

####-> deleterow(fromtable::tag,key::integer), deletefrom…

Delete the specified row from the specified table.

#Working with result sets — ds_result

Each result set returned by the data source is encapsulated by the ds_result type. The ds_result type provides access to information about the the result set and rows returned by the data source. 

Typically when a data source is invoked one ds_result is generated. For convenience ds replicates most of the methods ds_result provides and directs them to the most recent ds_result. 

Once invoked, the ds type can be queried directly as by default any ds_result sets are iterated:

```lasso
	with result in my_ds->sql('
	    UPDATE products SET status = 2 WHERE status = 1;
	') do {
	    #result->affected   // Number of rows affected
	    #result->found 	// Number of rows found
	}
```

##Result set information

####-> columns::staticarray
Returns the columns names returned by the data source.

####-> found::integer
Returns the number of rows found.

####-> affected::integer
Returns the number of rows affected by an update, insert or delete.

####-> num::integer
Returns the result sets number within the current set.

Accessing result set rows

####-> rows::staticarray
Returns staticarray containing the ::ds_rows returned by the data source.

####-> rows(astype::tag)::staticarray
Returns staticarray containing the specified type created with each ds_row — this is a really fast efficient approach to OOP (the overhead is minimal).

```lasso
with product in result->rows(::product) do {
   #product->isa(::product) // true
}
```

In the above example each row will be encapsulated by the product type — a custom type which inherits activerow. This is achieved by specifying activerow as the parent of the product type. From there you can modify and extend the product type as required. 

##Working with multiple result sets

However some data sources can generate multiple ds_result sets depending on the number of result sets returned by the data source. 

```lasso
	with result in my_ds->sql('
	    UPDATE products SET status = 2 WHERE status = 1;
	    SELECT * FROM products WHERE status = 2;
	') do {
	    #result->affected     // Number of rows affected
	    #result->found 	  // Number of row found
	}
```

ds_result sets can also be accessed and stored by calling ->results. 

```lasso
	local(
	    ds = ds(::store.products),
	    sql = 'UPDATE products SET status = 2 WHERE status = 1;
		   SELECT * FROM products WHERE status = 2',
	    results = #ds->sql(#sql)->results
	)
	with result in #results do {
	    #result->affected ? #ds->do_something
	    #result->found    ? #ds->do_something_else
	}
```

##Result set helper

When ds is provided a capture in a similar fashion to inline the result helper returns either the current ds_result or a specified ds_result if multiple result sets are available. Simply call result within the supplied capture like so:

```lasso
	ds(::store.products)->all => {
	    result->found // found count
	    result->rows  // rows to work with
	}

	inline(-database='store',-table='products',-findall) => {
	    result->found // found count
	    result->rows  // rows to work with
	}
```

Specific ds_result sets can retrieved by the helper by specifying an integer:

```lasso
	ds(::store.products)->sql('
	    UPDATE products SET status = 2 WHERE status = 1;
	    SELECT * FROM products WHERE status = 2;
	') => {
	    result(1)->affected // number of rows affected by UPDATE
	    result(2)->rows 	// rows returned by SELECT
	}
```

#Working with rows — ds_row

Each returned row is wrapped within ds_row, a map like data type designed to allow you to work with row data in a fast convenient fashion. Each ds_row represents a row in the data source.

##Accessing row data

(column::tag), find(column::tag), find(column::string)
Return the value of the specified column:

```lasso
	#row(::mycolumn)
	#row->find('mycolumn')
```

####-> get(::column), ->get('column')
Returns the value of specified columns fails if not a current column.

####-> get(integer)
Returns the column value at the specified index

####-> asmap
Returns row data as an map.

####-> asarray
Returns row data as an array

##Accessing data source information

####-> database
Database name the row belongs to.

####-> table
Table name the row belongs to.

####-> columns
Columns used by the current row.

####-> keycolumn
Return the rows key column

####-> keyvalue
Return the rows key value

####-> keyvalues
Return the rows key columns and values (useful if multiple key columns)

##Modifying internal data

The below methods can be used to modify the ds_row internal data. None of these methods affect the data source, although it is useful to be able work with a row as if it was a map or similar.

####-> find(column) = value, get(column) = value
Set the specified column

####-> insert(pair)
Insert / update the specified column and value

####-> modified
Returns a map of any modified values.

####-> keys
Returns list of modified keys.

## Modifying the data source

The ds_row type provides a number of methods that directly modify the row at the data source although generally it's more flexible and efficient to update rows with active_statements.

####-> update(data::trait_foreach), update(p::pair,...)
Updates internal data and writes modified values to the data source.

####-> (column::tag) = value, (column::string) = value 
Updates internal data and writes specified value to the data source.

####-> set(column = value), set(column::tag) = value, set(column::string) = value 
Updates internal data and writes specified value to the data source.

####-> save
Write any modified values to the data source.

####-> delete
Delete the row from the data source.

#Active Row

activerow is a hybrid implementation of the Active Record design pattern. Unlike ds_row which typically represents an existing row, activerow may not yet exist as a row in the data source. It is designed to be the parent type for your own types and expands on the functionality of ds_row. 

Rows returned from ds can be cast as activerows (or other types based on it) like so:

```lasso
	with row in product_ds->rows(::activerow) do { 
	    #row->isa(::activerow) // true
	}
```

This allows you to work with your own type definitions in an OOP fashion with minimal overhead and is one of the key strengths of the Datasource suite of tools.

The activerow type can be created with the following creators:

####-> oncreate(row::ds_row)
####-> oncreate(keyvalue,::database.table)
####-> oncreate(keyvalue,ds::ds)

Alternatively, the subtype should provide either the database name or ds definition via .database 
and .ds respectively. When using either approach you can also specify the table with .table

```lasso
	define product => type {
	   parent activerow
	   public ds => ds(::store.product)
	}
```

Or:

```lasso
	define product => type {
	    parent activerow
	    data
		public database = 'store',
		public table = 'products'
	}
```

When .table is blank activerow will use the types name suffixed with "s" as the table.

##Accessing row data — activerow

Data can be accessed in the same fashion as ds_row with the added benefit of being able leverage your own methods defined in your types. This allows you to format the data in a particular way or create another accessor for the data.

(column::tag), find(column::tag), find(column::string)
Return the value of the specified column:

```lasso
#activerow(::mycolumn)
#activerow->find('mycolumn')
```

When used in your own types you can create one to one methods like so:

```lasso
public mycolumn => .find(::mycolumn)
```

Or you can use methods with different names like so:

```lasso
public firstname => .find(::user_firstname)
public lastname  => .find('user_lastname') // also valid
```

Bringing it all together:
```
public qty => .find(::item_qty)
public price => .find(::item_price)
public subtotal => .price * .qty
```

##Modifying row data — activerow

####-> updatedata(data::trait_foreachpair), updatedata(p::pair,...)
Update internal data only — does not write to data source.

```lasso
#activerow->updatedata(map('price' = 9.95, 'qty' = 3))
```

####-> update(data::trait_foreachpair), update(p::pair,...)
Updates internal data and writes to data source.

```lasso
#activerow->update(::price = 9.95, ::qty = 3)
```

####-> (column::tag) = value, ->(column::string) = value 
Updates internal data and writes specified value to the data source.

####-> set(column = value), set(column::tag) = value, set(column::string) = value 
Updates internal data and writes specified value to the data source.

####-> create
Creates new row in the data source and assigns the newly created row to the type.

####-> save
Either updates or creates a row depending if it's new or not (based on keyvalue).

####-> delete
Clears row data and deletes the row from the data source.

####-> revert
Reverts unsaved changes.

Other activerow methods

####-> isnew
Returns true if new.

####-> asnew 
Returns copy of type with a null key value (considered new).

##Changing activerow behavior

You can change the default behaviour of the above by redefining them in your type. For example you may want to perform additional tasks on save or disable deleting by replacing it with an update.  

```lasso
	define example => type {
		parent activerow

		// Extend default save method
		public save => {
			// Do something else
			log(.type + ' saved by ' + current_user->name)

			// Now actually save
			..save
		}

		// Override default delete method
		public delete => .update(::status = -1)
	}
```

#Active Statements

Active statements allow you to construct and modify SQL statements on the fly. When tied to a ds connection these statements can be invoked at the results worked with. These are only compatible to data sources supporting SQL statements.

Active Statements do not invoke the data source until they are either queried or invoked with a given block of code. This means they are extremely efficient and flexible by being reusable.

The below chart measures statement construction time, select represents active_statements. 

##Select Statement Constructor — select_statement

The select_statement constructor allows you compose SELECT SQL statements. It can be called via ds with either the ->select or the ->where methods.

```lasso
// Set the products (data source is not invoked)
define products = ds(::store.products)->where('status =1')

// Work with products (retrieved from data source)
with row in products do {
    #row // 200 rows with status of 1
}

// Work with sub set of products (subset retrieved from data source)
with row in products->where('brand'='lasso') do {
   #row // 10 rows matching Lasso and status = 1
}

// Work with products again (retrieved from data source)
with row in products do {
    #row // 200 rows with status of 1
}
```

###Methods that return a select statement from ds

The below methods return a select_statment bound to a data source. When invoked the select_statement is executed on the the data source.

ds->select(...)
ds->where(...)

###Methods that construct / modify the statement

All of these methods will invoke the data source if supplied a given block. 

####-> select
####-> from
####-> join
####-> where
####-> group
####-> having
####-> order
####-> limit

####-> update
This returns a update_statement that corresponds to the current select_statement.  It inherits the select_statements where clause and table — allowing bulk updates on matching rows.

Methods that invoke the Data source

####-> do
####-> rows
####-> rows(astype::tag)
####-> asstring (if tied to a datasource)
####-> invoke

###Calculating found count

Often when working with large datasets we want to use the LIMIT clause to limit the amount of data returned by the data source. This has implications on calculating the number of rows found. The count method executes the SQL statement without the LIMIT or ORDER BY elements and only requests COUNT(*) in terms of data. The select_statement must be bound to a ds for this to work.

####-> count
This executes the SQL statement and returns an integer representing the found count.

####-> ascount
This returns the select_statement used by the count method.

##OOP and Select Statements

Active statements can also automatically cast objects as an activerow, types which inherit activerow or support ->oncreate(row::ds_row). This is a very efficient to work with types 
in an OOP fashion.

	// Define products (typically at startup)
	define products => ds(::store.products)->where('status = 1')->as(::product)

	// Work with live products
	with product in products do {
		#product // ::product type where status = 1
	}

##Update Statement Constructor — update_statement

You can update multiple rows and generate UPDATE SQL statements with this constructor.

Methods that construct / modify the statement
All of these methods will also invoke the data source if supplied with a given block.

####-> update(table::tag), update(table::string)
####-> set(pair,..), set(::string,...)
####-> where(::pair,...), where(::string,...)

Methods that invoke the data source

####-> do
####-> affected
####-> invoke

##Insert Statement Constructor — insert_statement

The insert_statement contrustructor allows you compose INSERT statements. The advantage they provide is the ability to insert multiple rows sourced from different data types. They support automatic batch inserting and duplicate key handling with MySQL.

Like the select_statement the insert_statment can be bound to a ds.

###Methods that return a select statement from ds

The below methods return a select_statment bound to a data source. When invoked the insert_statement is executed by the the data source.

ds->insert(...)

###Methods that construct / modify the statement

All of these methods will invoke the data source if supplied a given block. 

####-> into(table::tag, column1, column2, ...), into(table::string, column1, column2, ...)
The into method allows you to specify both the table and optionally the columns.

####-> columns(::column1,::column2,...), columns('column1','column2',...)
Specify the columns based on the supplied paramters:

```lasso
	insert_statement->columns(::brand,::description,::price)
```

####-> columns(array(::column1,::column2)), columns(array('column1','column2'))
Specify columns based on a supplied array of columns.

```lasso
	insert_statement->columns(
		array('brand','description','price')
	)
```

####-> addrow(row_values::array)
Add the supplied row to the insert queue, number of array elements must match the sequence and number of columns specified.

```lasso
	#ds->insert->into(::mytable)
	->columns(::description,::price)
	->addrow(
		array(
           	::description='from a map',
            ::price = 9.95
        	)
	)->do
```

####-> addrow(row::map)
Add the supplied row to the insert queue, the map will be queried for each column specified and any non existent values will be inserted as null values:

```lasso
	#ds->insert->into(::mytable)
		->columns(::description,::price)
		->addrow(
			map(
            	::notthere = 'OK',
            	::price = 9.95
            	::description='from a map',
			)
		)->do
```

####-> addrow(column::pair.column::pair,...)
Add a row based on the supplied parameters. The number of should match each column specified and any non existent values will be inserted as null values:

```lasso
	#ds ->insert->into(::mytable)
		->columns(::description,::price)
		->addrow(
			::description='from a map',
			::price = 9.95
		)->do
```

####-> addrows(row::trait_foreach)
Add multiple rows to be inserted, each specified row can either be a map or an array:

```lasso
	#ds ->insert->into(::mytable)
		->columns(::description,::price)
		->addrows(
			array(
				array('row1',9.98),
				array('row2',9.98),
			)
		)->do
```

###Automatic Inserting

When ->insertevery is specified, the insert statement will automatically be invoked once the number of added rows reaches the supplied value (the inserted rows are then cleared from the queue). This allows flexible batch inserting of rows. It's important to invoke / execute the statement even when specified to insert an outstanding rows.

####-> insertevery(numberofrows::integer) 

```lasso
	local(insert) = example_ds->insert->into(::products,::col1,::col2)

	#insert->insertevery(50)

	with item in #newproducts do {
		#insert->addtrow(#item->get(1),#item->get(2))
	}
	#insert->do
```

###On duplicate key update

The insert_statement supports on duplicate key handling when working with MySQL (and it's variants / flavours).

####-> onduplicate(keyupdate::boolean)
All inserted columns will be updated with the new values on duplicate key:

```lasso
	insert_statement->onduplicate(true)
```

####-> onduplicate(p::tag), onduplicate(p::string)
Add this column to the list of columns to update with the new value on duplicate key:

```lasso
	insert_statement->onduplicate(::column)
```
	
####-> onduplicate(p::pair)
The specified column will be updated with the supplied value or expression:

```lasso
	insert_statement->onduplicate(
		::column = 'IF(column < 20,column + 1,values(column))'
	)
```

####-> onduplicate(p1, p2, ...)
Update the specified column or pairs on duplicate key:

```lasso
	insert_statement->onduplicate(::column1,::column2,::column3 = 1)
```

####-> onduplicate(keyupdate::array)
Update these columns on duplicate key:

```lasso
	insert_statement->onduplicate(array('column1','column2' = 1))
```
