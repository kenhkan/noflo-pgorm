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
    @offset = 0
    @limit = 50
    @orderBy = "id ASC"
    @includeType = false

    @inPorts =
      in: new noflo.Port
      table: new noflo.Port
      pkey: new noflo.Port
      limit: new noflo.Port
      offset: new noflo.Port
      orderby: new noflo.Port
      includetype: new noflo.Port
    @outPorts =
      template: new noflo.Port
      out: new noflo.Port

    @inPorts.pkey.on "data", (@pkey) =>
      @orderBy = "#{@pkey} ASC" if @orderBy is "id ASC"
    @inPorts.limit.on "data", (@limit) =>
    @inPorts.offset.on "data", (@offset) =>
    @inPorts.orderby.on "data", (@orderBy) =>
    @inPorts.includetype.on "data", (includetype) =>
      @includeType = true if includetype is "true"

    @inPorts.table.on "connect", =>
      @tables = []

    @inPorts.table.on "data", (table) =>
      @tables.push table if _.isString table

    @inPorts.in.on "connect", =>
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
        # Pad values for list just in case of list of one
        value.push "" if operator.toUpperCase() is "IN"
        @outPorts.out.beginGroup column
        @outPorts.out.send v for v in value
        @outPorts.out.endGroup()

      @outPorts.out.disconnect()

  constructTemplate: ->
    primary = _.first @tables
    tables = @tables.join ", "
    typeSegment = if @includeType then ", '#{primary}' AS type" else ""
    fields = "#{primary}.*#{typeSegment}"
    baseClause = "SELECT DISTINCT ON (#{@pkey}) #{fields} FROM #{tables}"
    constraintClause = ""
    optionsClause = " ORDER BY #{@pkey}, #{@orderBy}"
    optionsClause += " LIMIT #{@limit} OFFSET #{@offset}"

    constStrings = []
    for constraint in @constraints
      [column, operator, value...] = constraint
      constStrings.push "#{column} #{operator.toUpperCase()} &#{column}"

    if constStrings.length > 0
      constraintClause = " WHERE #{constStrings.join(" AND ")}"

    "#{baseClause}#{constraintClause}#{optionsClause};"

exports.getComponent = -> new ConstructRead
