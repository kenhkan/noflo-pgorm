test = require "noflo-test"
_s = require "underscore.string"

expected = _s.clean """
  BEGIN;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; --

    UPDATE users SET id=&users_id_1234, name=&users_name_1234
      WHERE id = &users_id_1234; --
    INSERT INTO users (id, name)
      SELECT &users_id_1234, &users_name_1234
      WHERE NOT EXISTS (SELECT 1 FROM users WHERE id = &users_id_1234); --

    UPDATE things SET id=&things_id_4321, type=&things_type_4321
      WHERE id = &things_id_4321; --
    INSERT INTO things (id, type)
      SELECT &things_id_4321, &things_type_4321
      WHERE NOT EXISTS (SELECT 1 FROM things WHERE id = &things_id_4321); --

    SELECT row_to_json(rows) AS out FROM (
      (SELECT rows FROM
        (SELECT *, 'users' AS _type FROM users
          WHERE id IN (&users_id_1234)) AS rows)
      UNION
      (SELECT rows FROM
        (SELECT *, 'things' AS _type FROM things
          WHERE id IN (&things_id_4321)) AS rows)
    ) AS rows; --
  END;
"""

test.component("pgorm/ConstructWrite").
  discuss("send in some objects grouped in table names").
    send.connect("in").
    send.beginGroup("in", "users").
    send.data("in", { id: "1234", name: "panda", blah: null }).
    send.endGroup("in", "users").
    send.beginGroup("in", "things").
    send.data("in", { id: "4321", type: "mammal", bleh: undefined }).
    send.endGroup("in", "things").
    send.disconnect("in").
  discuss("construct the SQL").
    receive.data("template", expected).
    receive.beginGroup("out", "users_id_1234").
    receive.data("out", "1234").
    receive.endGroup("out").
    receive.beginGroup("out", "users_name_1234").
    receive.data("out", "panda").
    receive.endGroup("out").
    receive.beginGroup("out", "things_id_4321").
    receive.data("out", "4321").
    receive.endGroup("out").
    receive.beginGroup("out", "things_type_4321").
    receive.data("out", "mammal").
    receive.endGroup("out").

export module
