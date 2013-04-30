_ = require("underscore")
_s = require("underscore.string")
noflo = require("noflo")

class ConstructRead extends noflo.Component

  description: _s.clean "Construct SQL template and values from provided
  tables and constraints"

  constructor: ->
    @id = "id"
    @tables = []
    @constraints = []

    @inPorts =
      in: new noflo.Port
      table: new noflo.Port
      id: new noflo.Port
    @outPorts =
      template: new noflo.Port
      out: new noflo.Port

    @inPorts.id.on "data", (@id) =>

    @inPorts.table.on "connect", =>
      @tables = []

    @inPorts.table.on "data", (table) =>
      @tables.push table if _.isString table

    @inPorts.in.on "connect", (group) =>
      @constraints = []

    @inPorts.in.on "data", (data) =>
      @constraints.push data if _.isArray data

    @inPorts.in.on "disconnect", =>
      template = @constructTemplate()
      @outPorts.template.send template
      @outPorts.template.disconnect()

      @outPorts.out.connect()
      for constraint in @constraints
        [column, operator, value] = constraint
        @outPorts.out.beginGroup column
        @outPorts.out.send value
        @outPorts.out.endGroup()
      @outPorts.out.disconnect()

  constructTemplate: ->
    primary = _.first @tables
    tables = @tables.join ", "
    firstClause = "SELECT DISTINCT ON (#{@id}) #{primary}.* FROM #{tables}"
    secondClause = ""

    constStrings = []
    for constraint in @constraints
      [column, operator, value] = constraint
      constStrings.push "#{column} #{operator} &#{column}"

    if constStrings.length > 0
      secondClause = " WHERE #{constStrings.join(" AND ")}"

    "#{firstClause}#{secondClause};"

exports.getComponent = -> new ConstructRead
