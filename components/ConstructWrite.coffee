_ = require("underscore")
_s = require("underscore.string")
noflo = require("noflo")

class ConstructWrite extends noflo.Component

  description: _s.clean "Construct SQL template and values from provided
  objects"

  constructor: ->
    @id = "id"
    @table = null

    @inPorts =
      in: new noflo.Port
      id: new noflo.Port
    @outPorts =
      template: new noflo.Port
      out: new noflo.Port

    @inPorts.id.on "data", (@id) =>

    @inPorts.in.on "connect", =>
      @objects = {}

    @inPorts.in.on "begingroup", (group) =>
      @table = group
      @objects[@table] = []

    @inPorts.in.on "data", (object) =>
      @objects[@table].push object if @table?

    @inPorts.in.on "endgroup", (group) =>
      @table = null

    @inPorts.in.on "disconnect", =>
      @outPorts.template.send @constructTemplate()

      @outPorts.out.connect()

      for table, objects of @objects
        for object in objects
          id = object[@id]

          for key, value of object
            @outPorts.out.beginGroup @constructPlaceholder table, key, id, ""
            @outPorts.out.send value
            @outPorts.out.endGroup()

      @outPorts.out.disconnect()
      @outPorts.template.disconnect()

  constructPlaceholder: (table, key, id, prefix = "&") ->
    "#{prefix}#{table}_#{key}_#{id}"

  constructTemplate: ->
    templates = []

    for table, objects of @objects
      for object in objects
        id = object[@id]
        keys = _.keys object

        idTemplate = "#{@id} = #{@constructPlaceholder(table, @id, id)}"

        selects = _.map keys, (key) =>
          @constructPlaceholder table, key, id
        selectTemplate = selects.join ", "

        sets = _.map keys, (key, i) =>
          "#{key}=#{selects[i]}"
        setTemplate = sets.join ", "

        templates.push """
          UPDATE #{table} SET #{setTemplate}
            WHERE #{idTemplate};
          INSERT INTO #{table} (#{keys.join(", ")})
            SELECT #{selectTemplate}
            WHERE NOT EXISTS
            (SELECT 1 FROM #{table} WHERE #{idTemplate});
        """

    _s.clean """
      BEGIN;
        SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

        #{templates.join("\n")}
      END;
    """

exports.getComponent = -> new ConstructWrite
