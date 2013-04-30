test = require "noflo-test"
_s = require "underscore.string"

test.component("pgorm/SanitizeObjects").
  discuss("pass table and column definitions").
    send.connect("definition").
    send.beginGroup("definition", "users").
    send.data("definition", "id").
    send.data("definition", "name").
    send.endGroup("definition", "users").
    send.beginGroup("definition", "things").
    send.data("definition", "id").
    send.data("definition", "type").
    send.endGroup("definition", "things").
    send.disconnect("definition").
  discuss("pass some objects").
    send.connect("in").
    send.beginGroup("in", "users").
    send.data("in", { id: "1234", name: "panda", bloodType: "A" }).
    send.data("in", { id: "5678", name: "whale" }).
    send.endGroup("in", "users").
    send.beginGroup("in", "animals").
    send.data("in", { id: "4321", type: "mammal", ancestor: "reptile" }).
    send.endGroup("in", "animals").
    send.disconnect("in").
  discuss("only forward the objects with proper tables (i.e. groups) extraneous properties removed").
    receive.beginGroup("out", "users").
    receive.data("out", { id: "1234", name: "panda" }).
    receive.data("out", { id: "5678", name: "whale" }).
    receive.endGroup("out", "users").

  next().
  discuss("pass some objects").
    send.connect("in").
    send.beginGroup("in", "users").
    send.data("in", { id: "1234", name: "panda", bloodType: "A" }).
    send.data("in", { id: "5678", name: "whale" }).
    send.endGroup("in", "users").
    send.disconnect("in").
  discuss("forward everything when there's no definition").
    receive.beginGroup("out", "users").
    receive.data("out", { id: "1234", name: "panda", bloodType: "A" }).
    receive.data("out", { id: "5678", name: "whale" }).
    receive.endGroup("out", "users").

export module
