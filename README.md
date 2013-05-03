PostgreSQL ORM on top of noflo-pg [![Build Status](https://secure.travis-ci.org/kenhkan/noflo-pgorm.png?branch=master)](https://travis-ci.org/kenhkan/noflo-pgorm)
===============================

This is an Object-Relational Mapping interface to
[noflo-pg](https://github.com/kenhkan/noflo-pg). This ORM tries to be a
thin layer on top of noflo-pg's raw access to a pgSQL server. It
contains two usable components, one for `Read`ing and another for
`Write`ing. A basic workflow would be something like:

  1. Provide the URL to either the 'Read' or 'Write' component.
  2. Provide an alternative primary key column if it is not the column
     'id'.
  3. It fetches table and column information from the server at
     initiation.
  4. You may then 'Read' or 'Write' from/to the database.

Feel free to contribute new components and graphs! I'll try to
incorporate as soon as time allows.


API
------------------------------

### Reading from PostgreSQL

Reading is as simple as sending the target table name and constraints to
the 'Read' component.

First set up a component with a server URL.

    'tcp://default@localhost:5432/postgres' -> SERVER Read(pgorm/Read)

The 'IN' port accepts a series of packets. Each packet is a tuple as an
array, in the form of `[column_name, operator, value]`. It is the
equivalent to the SQL construct of `column_name operator value`, as in
`username = elephant`. Note that the value does not need to be quoted as
the ORM would sanitize it for you.

    'username,=,elephant' -> IN Arrayify(adapters/TupleToArray)
    Arrayify() OUT -> IN Read()

You must group this series of packets with an TOKEN, which would be used
to group the output, since this is an asynchronous operation. Inside the
TOKEN group, you must also group the packets with a number of groups
representing the tables to fetch from.

    'token' -> GROUP Token(Group)
    'username,=,elephant' -> IN Arrayify(adapters/TupleToArray)
    Arrayify() OUT -> IN Token() OUT -> IN Read()

You may optionally pass no packets but simply group(s) to fetch
everything in the said tables.

    'token' -> GROUP Token(Group)
    '_' -> IN Empty(Kick) OUT -> IN Token() OUT -> IN Read()

A more complete example:

    'token' -> GROUP Token(Group)
    ',' -> DELIMITER SplitTables(SplitStr)
    'users,things' -> IN SplitTables() OUT -> GROUP Tables(Group)
    'username,=,elephant' -> IN Arrayify(adapters/TupleToArray)
    Arrayify() OUT -> IN Tables() OUT -> IN Token()
    Token() OUT -> IN Read(pgorm/Read) OUT -> IN Rows(Output)

`Read()` receives:

    BEGINGROUP: 'token'
    BEGINGROUP: 'users'
    BEGINGROUP: 'things'
    DATA: 'username,=,elephant'
    ENDGROUP: 'things'
    ENDGROUP: 'users'
    ENDGROUP: 'token'

The executed SQL should be something like:

    SELECT users.* FROM users, things WHERE username = 'elephant';

while `Rows()` should receive something similar to:

    BEGINGROUP: 'token'
    DATA: {
        ...
        username: 'elephant'
        ...
      }
    ENDGROUP: 'token'


### Writing to PostgreSQL

Writing is handled by the 'Write' component, very similar to the 'Read'
component except it fetches table and column information from the
PostgreSQL server at initialization so that it can filter out invalid
tables and columns when executing SQL.

First set up a component with a server URL.

    'tcp://default@localhost:5432/postgres' -> SERVER Write(pgorm/Write)

The 'IN' port expects a series of packets, each of which is an object to
be translated into SQL. It filters out all keys that do not have
corresponding columns.

The packets, like `Read()`, must also be grouped by the table name:

    BEGINGROUP: 'users'
    DATA: { "id": 1, "name": "elephant" }
    ENDGROUP: 'users'
    BEGINGROUP: 'things'
    DATA: { "id": 3, "type": "person" }
    ENDGROUP: 'things'

#### Note on ORM's attempt to upsert

The above would write to the 'users' and the 'things' tables. The
executed SQL would be something like:

    BEGIN;
      SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

      UPDATE users SET id=&users_id_1, name=&users_name_1
        WHERE id = &users_id_1;
      INSERT INTO users (id, name)
        SELECT &users_id_1, &users_name_1
        WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = &users_id_1);

      UPDATE things SET id=&things_id_3, type=&things_type_3
        WHERE id = &things_id_3;
      INSERT INTO things (id, type)
        SELECT &things_id_3, &things_type_3
        WHERE NOT EXISTS (SELECT 3 FROM things WHERE id = &things_id_3);
    END;

It uses dirty upsert for PostgreSQL, stolen from [bovine's answer on
this StackOverflow
question](http://stackoverflow.com/questions/1109061/insert-on-duplicate-update-postgresql).
This dirty solution is good enough for most cases unless you use
autoincrement on the primary key and your transaction is large, or in
any scenario where primary key collision upon row creation is frequent.
It is recommended that you use UUID to avoid any problem. Upserting is a
[complicated
problem](http://www.depesz.com/2012/06/10/why-is-upsert-so-complicated/)
so some compromises must be made.

#### The return values

'Write' returns whatever the server returns wrapped in the provided
token. Most likely nothing would be returned because it's a write
operation. In this case (most cases), it'd be an empty connection with
just the token as a wrapping group.


### Automatic table/column existence check

The 'Write' component also automatically filter incoming queries for
invalid tables and columns. This is possible as 'Write' fetches
table/column information from the server on initialization. The
downside, of course, is when the schema has changed on the PostgreSQL
server the NoFlo network needs to be refreshed.

Another note when using 'Write' is to remember to pipe the 'READY' port
to your initialization process that activates anything that would run a
query against 'Write'. The component emits an empty connection to the
'READY' port when it has finished fetching table/column information.

    'tcp://default@localhost:5432/postgres' -> SERVER Write(pgorm/Write)
    Write() READY -> ...


### Different primary key

This ORM is a simple wrapper around noflo-pg so it assumes many things,
including that all tables have the same primary key. By default, this is
'id'. If the tables use a primary key that is not 'id', send the
proper primary key to the 'PKEY' port. This only needs to be done once at
initialization.

    'tcp://default@localhost:5432/postgres' -> SERVER Write(pgorm/Write)
    'uuid' -> PKEY Write()


### Error handling

Errors from the PostgreSQL server are emitted to the 'ERROR' port.
Attach a process to it to handle any server-side error.

    'tcp://default@localhost:5432/postgres' -> SERVER Write(pgorm/Write)
    Write() ERROR -> IN Error(Output)


### Shutting down

You may shut down the connection to the PostgreSQL server by sending a
null packet to the 'QUIT' port.

    'tcp://default@localhost:5432/postgres' -> SERVER Write(pgorm/Write)
    '_' -> IN Kick(Kick) OUT -> QUIT Write()

All connections in a single program are pooled for efficiency. Sending a
null packet would kill all pgSQL connections. Pass the URL that was used
to initialize the connection to 'QUIT' in order to kill just that one
connection.
