# Datasource (ds)
### A modern high performance replacement for Lasso inline.

The Datasource suite is a collection of types that work with any data source supported by Lasso 9. It has been designed to directly replace inline — offering improved performance and new productive ways of working with data.

## Features
* High performance (anywhere from 2x - 10x faster than inline)
* Hybrid active record implementation (low overhead OOP)
* Works directly with data source connectors
* Supports legacy inline expressions
* Automatic connection reuse
* Advance SQL query constructor
* Queriable types and clean simple syntax

## Quick Example

```lasso
// Connect to a data source
datasource(::database.table)

// Preferred short hand
ds(::database.table)

// Work with some rows
with row in ds(::store.products)->allrows do {
   #row(::column)
}
```

## Package contents

### ds
The main type. Wherever inline is used in your code it can directly be substituted with ds. All commands that inline supports are also supported by ds. Data source connections are automatically reused by ds resulting in increased performance. You can query ds directly and work with it in an object oriented fashion.

### ds_result
Result sets are enclosed by this type. ds_result typically resides in the background unless you need to work with multiple result sets.

### ds_row
Rows are enclosed by this type. ds_row provides quick access to row data and column information.

### activerow
A high performance hybrid implementation of the Active Record design pattern. When paired with ds activerow allows you to work in an object orientated fashion without the usual overheads incurred.

### active_statement
Active statements allow you to construct, modify and reuse SQL statements in an object oriented fashion. active_statements tied to a data source can directly return rows, activerows or your own types return from the resulting SQL statement.

## Performance vs inline

The degree of improvements depend on a number of factors; the number of columns and rows you work with through to the general response time of the data source. 

![a](https://docs.google.com/document/d/1GLMIZE3R3BFm6hki-eHahU5C6gyFsNiBjwiJHrpIOjI/pubimage?id=1GLMIZE3R3BFm6hki-eHahU5C6gyFsNiBjwiJHrpIOjI&image_id=1C2Pyrcag3JEPmgWtDyfZQWDH5zfkpmW_9QHZ1g)

![b](https://docs.google.com/document/d/1GLMIZE3R3BFm6hki-eHahU5C6gyFsNiBjwiJHrpIOjI/pubimage?id=1GLMIZE3R3BFm6hki-eHahU5C6gyFsNiBjwiJHrpIOjI&image_id=1GaoxgedmEmehK9mrd2HF_mOG9hwqHnN4RQpCOg)

## Installation

To install export to your LassoApp folder:

	git clone https://github.com/zeroloop/ds /var/lasso/home/LassoApps/ds

or:
	
	svn export https://github.com/zeroloop/ds /var/lasso/home/LassoApps/ds

or:

	wget https://github.com/zeroloop/ds/archive/master.zip /var/lasso/home/LassoApps/ds.zip

Full documentation [begins here](/zeroloop/ds/wiki/introduction).
