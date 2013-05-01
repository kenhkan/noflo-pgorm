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
    receive.data("template", "SELECT DISTINCT ON (id) users.* FROM users, things WHERE username = &username AND age > &age;").
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
  discuss("construct the SQL").
    receive.data("template", "SELECT DISTINCT ON (uuid) users.* FROM users, things WHERE username = &username AND age > &age;").
    receive.beginGroup("out", "username").
    receive.data("out", "elephant").
    receive.endGroup("out").
    receive.beginGroup("out", "age").
    receive.data("out", 30).
    receive.endGroup("out").

export module
