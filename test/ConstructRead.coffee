test = require "noflo-test"

prefix = "SELECT row_to_json(rows) AS out FROM ("
postfix = ") AS rows;"

test.component("pgorm/ConstructRead").
  discuss("send in some constraints").
    send.connect("in").
      send.beginGroup("in", "users").
        send.beginGroup("in", "things").
          send.data("in", ["username", "=", "elephant"]).
          send.data("in", ["age", ">", 30]).
        send.endGroup("in", "things").
      send.endGroup("in", "users").
    send.disconnect("in").
  discuss("construct the SQL").
    receive.data("template", "#{prefix} (SELECT rows FROM (SELECT DISTINCT ON (id) users.*, 'users' AS _type FROM users, things WHERE username = &users_username_ AND age > &users_age_ ORDER BY id, id ASC LIMIT 50 OFFSET 0) AS rows) #{postfix}").
    receive.beginGroup("out", "&users_username_").
    receive.data("out", "elephant").
    receive.endGroup("out").
    receive.beginGroup("out", "&users_age_").
    receive.data("out", 30).
    receive.endGroup("out").

  next().
  discuss("send in constraints in multiple tables").
    send.connect("in").
      send.beginGroup("in", "users").
        send.data("in", ["username", "=", "elephant"]).
      send.endGroup("in", "users").
      send.beginGroup("in", "things").
        send.data("in", ["age", ">", 30]).
      send.endGroup("in", "things").
    send.disconnect("in").
  discuss("construct the SQL to fetch records from multiple tables").
    receive.data("template", "#{prefix} (SELECT rows FROM (SELECT DISTINCT ON (id) users.*, 'users' AS _type FROM users WHERE username = &users_username_ ORDER BY id, id ASC LIMIT 50 OFFSET 0) AS rows) UNION (SELECT rows FROM (SELECT DISTINCT ON (id) things.*, 'things' AS _type FROM things WHERE age > &things_age_ ORDER BY id, id ASC LIMIT 50 OFFSET 0) AS rows) #{postfix}").
    receive.beginGroup("out", "&users_username_").
    receive.data("out", "elephant").
    receive.endGroup("out").
    receive.beginGroup("out", "&users_age_").
    receive.data("out", 30).
    receive.endGroup("out").

  next().
  discuss("set a different primary key").
    send.data("pkey", "uuid").
  discuss("send in some constraints").
    send.connect("in").
      send.beginGroup("in", "users").
        send.beginGroup("in", "things").
          send.data("in", ["username", "=", "elephant"]).
          send.data("in", ["age", ">", 30]).
        send.endGroup("in", "things").
      send.endGroup("in", "users").
    send.disconnect("in").
  discuss("construct the SQL, where the order-by is also changed to the primary key").
    receive.data("template", "#{prefix} (SELECT rows FROM (SELECT DISTINCT ON (uuid) users.*, 'users' AS _type FROM users, things WHERE username = &users_username_ AND age > &users_age_ ORDER BY uuid, uuid ASC LIMIT 50 OFFSET 0) AS rows) #{postfix}").
    receive.beginGroup("out", "&users_username_").
    receive.data("out", "elephant").
    receive.endGroup("out").
    receive.beginGroup("out", "&users_age_").
    receive.data("out", 30).
    receive.endGroup("out").

  next().
  discuss("set some limit and sort order").
    send.data("limit", 30).
    send.data("offset", 5).
    send.data("orderby", "name DESC").
  discuss("with no constraints").
    send.connect("in").
      send.beginGroup("in", "users").
        send.data("in", null).
      send.endGroup("in", "users").
    send.disconnect("in").
  discuss("construct the SQL").
    receive.data("template", "#{prefix} (SELECT rows FROM (SELECT DISTINCT ON (id) users.*, 'users' AS _type FROM users ORDER BY id, name DESC LIMIT 30 OFFSET 5) AS rows) #{postfix}").
    receive.data("out", null).

export module
