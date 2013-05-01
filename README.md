PostgreSQL ORM on top of noflo-pg [![Build Status](https://secure.travis-ci.org/kenhkan/noflo-pgorm.png?branch=master)](https://travis-ci.org/kenhkan/noflo-pgorm)
===============================

This is an Object-Relational Mapping interface to
[noflo-pg](https://github.com/kenhkan/noflo-pg).

This ORM does not actively manage your schema, meaning that all checks
happen on the server. This simply translates what is given into pgSQL.
The basic workflow would be something like:

  1. Provide the URL to the PostgreSQL server.
  2. Provide an alternative primary key column if it is not the column
     'id'.
  3. It fetches table and column information from the server at
     initiation.
  4. You may either 'Read' or 'Write' from/to the database.

Feel free to contribute new components and graphs! I'll try to
incorporate as soon as time allows.


Lower Level Read/Write API
------------------------------


### Reading from Database

Reading is as simple as sending the target table name and constraints to
the 'Read' component. Each time the connection disconnects on the 'IN'
port the ORM would translate the SQL.

The 'IN' port accepts a series of packets. Each packet is a tuple as an
array, in the form of `[column_name, operator, value]`.  It is the
equivalent to the SQL construct of `column_name operator value`, as in
`username = elephant`. Note that the value does not need to be quoted as
the ORM would sanitize it for you.

You must group this series of packets with an ID, which would be used to
group the output, since this is an asynchronous operation. Inside the ID
group, you must also group the packets with a number of groups
representing the tables to fetch from.

You may optionally pass no packets but simply group(s) to fetch
everything in the said tables.

Example:

    'id' -> GROUP Id(Group)
    'users' -> GROUP PrimaryTable()
    'things' -> GROUP SecondaryTable()
    'username,=,elephant' -> IN Arrayify(adapters/TupleToArray)
    Arrayify() OUT -> IN SecondaryTable()
    SecondaryTable() OUT -> IN PrimaryTable()
    PrimaryTable() OUT -> IN Id()
    Id() OUT -> IN Read(pgorm/Read)
    Read() TOKEN -> IN PrintToken(Output)
    Read() TEMPLATE -> IN PrintTemplate(Output)
    Read() OUT -> IN PrintOut(Output)

If the requested table uses a primary key that is not 'id', send the
proper primary key to the 'ID' port. This only needs to be done once at
initialization.

The connection right before `Read()` receives it should be like:

    BEGINGROUP: 'id'
    BEGINGROUP: 'users'
    BEGINGROUP: 'things'
    DATA: 'username,=,elephant'
    ENDGROUP: 'id'
    ENDGROUP: 'users'
    ENDGROUP: 'things'

`PrintTemplate()` should receive:

    DATA: SELECT users.* FROM users, things WHERE username = &username;

while `PrintOut()` should receive:

    BEGINGROUP: 'id'
    BEGINGROUP: 'username'
    DATA: 'elephant'
    ENDGROUP: 'username'
    ENDGROUP: 'id'


### Writing to Database

Writing is handled by the 'Write' component. The 'IN' port expects a
series of packets, each of which is an object to be translated into SQL.
It filters out all keys that do not have corresponding columns, *but
only* when it has been provided table and column information via the
'DEFINITION' port. For example:

    BEGINGROUP: 'users'
    DATA: 'id'
    DATA: 'name'
    ENDGROUP: 'users'

The above would filter out all properites that are not 'id' or 'name'
and only allow table with the name 'users' to be constructed as SQL. If
nothing is passed to 'DEFINITION', everything is allowed.

The packets, like `Read()`, must also be grouped by the table name,
except in this case, there can be multiple groups, such as:

    BEGINGROUP: 'users'
    DATA: { "id": 1, "name": "elephant" }
    ENDGROUP: 'users'
    BEGINGROUP: 'things'
    DATA: { "id": 3, "type": "person" }
    ENDGROUP: 'things'

#### The Template

The above would write to the 'users' and the 'things' tables. The
translated SQL would be:

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

This template uses dirty upsert for PostgreSQL, stolen from [bovine's
answer on this StackOverflow
question](http://stackoverflow.com/questions/1109061/insert-on-duplicate-update-postgresql).
This dirty solution is good enough for most cases unless you use
autoincrement on the primary key and your transaction is large, or in any
scenario where ID collision upon row creation is frequent. It is
recommended that you use UUID to avoid any problem. Upserting is a
[complicated
problem](http://www.depesz.com/2012/06/10/why-is-upsert-so-complicated/)
so some compromises must be made.

#### The Values

Just like 'Read', 'Write' produces a template with values to be fed into
'pg/Postgres'. The above template would be accompanied by the values as
output to the 'OUT' port:

    BEGINGROUP: 'users_id_1'
    DATA: '1'
    ENDGROUP: 'users_id_1'
    BEGINGROUP: 'users_name_1'
    DATA: 'elephant'
    ENDGROUP: 'users_name_1'
    BEGINGROUP: 'things_id_1'
    DATA: '3'
    ENDGROUP: 'things_id_1'
    BEGINGROUP: 'things_type_1'
    DATA: 'person'
    ENDGROUP: 'things_type_1'

And just like 'Read', 'Write' assumes the primary key to be 'id'. Pass
another primary key to the 'ID' port of 'Write' to change it.


Higher Level API
------------------------------

If you don't need to manage the `pg/Postgres` yourself, it is encouraged
to use the high level API. The API works basically the same as using
'Read' and 'Write' directly, except that queries are sent via the
'READIN', 'READOUT', 'WRITEIN', and 'WRITEOUT' ports.

Example:

    'tcp://localhost:5432/postgres' -> SERVER Database(pgorm/Database)
    '2' -> THRESHOLD Merge(flow/CountedMerge)
    'token' -> GROUP Token(Group)

    'users' -> GROUP TableA(Group)
    '{ "id": "x", "a": 1, "b": 2 }' -> IN ParseA(ParseJson) OUT -> IN TableA()

    'things' -> GROUP TableB(Group)
    '{ "id": "y", "c": 3 }' -> IN ParseB(ParseJson) OUT -> IN TableB()

    TableA() OUT -> IN Merge()
    TableB() OUT -> IN Merge()

    Merge() OUT -> IN Token() OUT -> WRITEIN Database()
    Database() WRITEOUT -> IN Output(Output)

Of course, if your query is already well-formed, it simply looks like:

    'tcp://localhost:5432/postgres' -> SERVER Database(pgorm/Database)
    <<YOUR QUERIES HERE>> -> WRITEIN Database()
    Database() WRITEOUT -> IN Output(Output)

Use 'READIN' and 'READOUT' ports as specified above specified in the
"Reading from Database" section.
