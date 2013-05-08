test = require "noflo-test"

test.component("pgorm/ConstructRead").
  discuss("send in some tables").
    send.data("table", "users").
    send.data("table", "things").
  discuss("send in some constraints").
    send.connect("in").
    send.data("in", ["username", "=", "elephant"]).
    send.data("in", ["age", ">", 30]).
    send.disconnect("in").
  discuss("construct the SQL").
    receive.data("template", "SELECT DISTINCT ON (id) users.* FROM users, things WHERE username = &username AND age > &age ORDER BY id, id ASC LIMIT 50 OFFSET 0;").
    receive.beginGroup("out", "username").
    receive.data("out", "elephant").
    receive.endGroup("out").
    receive.beginGroup("out", "age").
    receive.data("out", 30).
    receive.endGroup("out").

  next().
  discuss("set a different primary key").
    send.data("pkey", "uuid").
  discuss("send in some tables").
    send.data("table", "users").
    send.data("table", "things").
  discuss("send in some constraints").
    send.connect("in").
    send.data("in", ["username", "=", "elephant"]).
    send.data("in", ["age", ">", 30]).
    send.disconnect("in").
  discuss("construct the SQL, where the order-by is also changed to the primary key").
    receive.data("template", "SELECT DISTINCT ON (uuid) users.* FROM users, things WHERE username = &username AND age > &age ORDER BY uuid, uuid ASC LIMIT 50 OFFSET 0;").
    receive.beginGroup("out", "username").
    receive.data("out", "elephant").
    receive.endGroup("out").
    receive.beginGroup("out", "age").
    receive.data("out", 30).
    receive.endGroup("out").

  next().
  discuss("set some limit and sort order").
    send.data("limit", 30).
    send.data("offset", 5).
    send.data("orderby", "name DESC").
  discuss("send in some tables").
    send.data("table", "users").
  discuss("with no constraints").
    send.connect("in").
    send.disconnect("in").
  discuss("construct the SQL").
    receive.data("template", "SELECT DISTINCT ON (id) users.* FROM users ORDER BY id, name DESC LIMIT 30 OFFSET 5;").
    receive.data("out", null).

  next().
  discuss("include the table's name in output").
    send.data("includetype", "true").
  discuss("send in some tables").
    send.data("table", "users").
  discuss("with no constraints").
    send.connect("in").
    send.disconnect("in").
  discuss("construct the SQL with the table's name as a column").
    receive.data("template", "SELECT DISTINCT ON (id) users.*, 'users' AS type FROM users ORDER BY id, id ASC LIMIT 50 OFFSET 0;").
    receive.data("out", null).

export module
