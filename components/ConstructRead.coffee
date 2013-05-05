_ = require("underscore")
_s = require("underscore.string")
noflo = require("noflo")

class ConstructRead extends noflo.Component

  description: _s.clean "Construct SQL template and values from provided
  tables and constraints"

  constructor: ->
    @pkey = "id"
    @tables = []
    @constraints = []

    @inPorts =
      in: new noflo.Port
      table: new noflo.Port
      pkey: new noflo.Port
    @outPorts =
      template: new noflo.Port
      out: new noflo.Port

    @inPorts.pkey.on "data", (@pkey) =>

    @inPorts.table.on "connect", =>
      @tables = []

    @inPorts.table.on "data", (table) =>
      @tables.push table if _.isString table

    @inPorts.in.on "connect", (group) =>
      @constraints = []

    @inPorts.in.on "data", (data) =>
      @constraints.push data if _.isArray data

    @inPorts.in.on "disconnect", =>
      @outPorts.template.send @constructTemplate()
      @outPorts.template.disconnect()

      @outPorts.out.connect()
      @outPorts.out.send null if _.isEmpty @constraints

      for constraint in @constraints
        [column, operator, value...] = constraint
        @outPorts.out.beginGroup column
        @outPorts.out.send v for v in value
        @outPorts.out.endGroup()

      @outPorts.out.disconnect()

  constructTemplate: ->
    primary = _.first @tables
    tables = @tables.join ", "
    firstClause = "SELECT DISTINCT ON (#{@pkey}) #{primary}.* FROM #{tables}"
    secondClause = ""

    constStrings = []
    for constraint in @constraints
      [column, operator, value...] = constraint
      constStrings.push "#{column} #{operator.toUpperCase()} &#{column}"

    if constStrings.length > 0
      secondClause = " WHERE #{constStrings.join(" AND ")}"

    "#{firstClause}#{secondClause};"

exports.getComponent = -> new ConstructRead
