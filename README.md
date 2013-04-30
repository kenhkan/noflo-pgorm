Provide a basic ORM on top of noflo-pg [![Build Status](https://secure.travis-ci.org/kenhkan/noflo-pg-orm.png?branch=master)](https://travis-ci.org/kenhkan/noflo-pg-orm)
===============================

This is an Object-Relational Mapping interface to
[noflo-pg](https://github.com/kenhkan/noflo-pg).

Feel free to contribute new components and graphs! I'll try to
incorporate as soon as time allows.


API
------------------------------

Aside from table and column information fetched from the server at
initialization, this ORM does not actively manage your schema, meaning
that all checks happen on the server. This simply translates what is
given into pgSQL.

  1. Provide the URL to the PostgreSQL server.
  2. It fetches table and column information from the server at
     initiation.
  3. You may either 'Read' or 'Write' from/to the database.

#### Reading from Database

Reading is as simple as sending the target table name and constraints to
the 'Read' component. Each time the connection disconnects on the 'IN'
port the ORM would translate and execute the SQL.

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
    'username,=,'elephant'' -> IN Arrayify(adapters/StringToArray)
    Arrayify() OUT -> IN SecondaryTable()
    SecondaryTable() OUT -> IN PrimaryTable()
    PrimaryTable() OUT -> IN Id()
    Id() OUT -> IN Read(pg-orm/Read) OUT -> IN Print(Output)

The connection right before `Read()` receives it should be like:

    BEGINGROUP: 'id'
    BEGINGROUP: 'users'
    BEGINGROUP: 'things'
    DATA: 'username,=,elephant'
    ENDGROUP: 'id'
    ENDGROUP: 'users'
    ENDGROUP: 'things'

`Read()` should execute:

    SELECT users.* FROM users, things WHERE username = 'elephant';

`Print()` should receive:

    BEGINGROUP: 'id'
    DATA: a row
    DATA: another row
    DATA: yet another row
    ENDGROUP: 'id'

#### Writing to Database

Writing is handled by the 'Write' component. The 'IN' port expects a
series of packets, each of which is an object to be translated into SQL.
For instance:

   DATA: { "a": 1, "b": 2 }
   DATA: { "a": 3, "b": 4 }

It filters out all keys that do not have corresponding columns. The
packets, like `Read()` must also be grouped by the table name, except
in this case, there can be multiple groups, such as:

   BEGINGROUP: 'users'
   DATA: { "a": 1, "b": 2 }
   DATA: { "a": 3, "b": 4 }
   ENDGROUP: 'users'
   BEGINGROUP: 'things'
   DATA: { "a": 1, "b": 2 }
   DATA: { "a": 3, "b": 4 }
   ENDGROUP: 'things'

The above would write to the 'users' table with a record of column 'a'
and 'b'. The executed SQL would be:

    INSERT INTO users (a,b) VALUES (1,2);
    INSERT INTO users (a,b) VALUES (3,4);
    INSERT INTO things (a,b) VALUES (1,2);
    INSERT INTO things (a,b) VALUES (3,4);

Upon initialization, the ORM fetches unique indexes from the server and
when writing to the database, records with matching columns and values
would become an 'upsert' rather than insert.

Using the previous example, assume that there is a unique constraint on
column 'a', but only on table 'users', the executed SQL would look
something like:

    UPDATE users SET b=2 WHERE a=1;
    UPDATE users SET b=4 WHERE a=3;
    INSERT INTO things (a,b) VALUES (1,2);
    INSERT INTO things (a,b) VALUES (3,4);

This is the simplistic view, as the ORM would insert the 'users' records
if they're not found. This is done by injecting an 'upsert' CTE at
initialization.

At the moment, only simple unique constraints are detected (i.e. unique
constraints that are applied on only one column).
