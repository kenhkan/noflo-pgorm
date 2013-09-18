_ = require("underscore")
_s = require("underscore.string")
noflo = require("noflo")

class SanitizeObjects extends noflo.Component

  description: _s.clean "Remove undefiend properties in incoming objects
  as well as strip groups that are not defined."

  constructor: ->
    @inPorts =
      in: new noflo.Port
      definition: new noflo.Port
    @outPorts =
      out: new noflo.Port
      error: new noflo.Port

    @inPorts.definition.on "connect", =>
      @definitions = {}

    @inPorts.definition.on "begingroup", (table) =>
      @table = table
      @definitions[@table] ?= []

    @inPorts.definition.on "data", (def) =>
      error = new Error 'There must be a group indicating which table'
      if @table?
        @definitions[@table].push def
      else if @outPorts.error.isAttached()
        @outPorts.error.send error
        @outPorts.error.disconnect()
      else
        throw error

    @inPorts.definition.on "disconnect", =>
      @table = null

    @inPorts.in.on "connect", =>
      @definitions ?= {}
      @table = null

    @inPorts.in.on "begingroup", (table) =>
      if @definitions[table]?
        @table = table
        @outPorts.out.beginGroup table

      # Simply forward as-is if nothiing has been defined
      else if _.isEmpty @definitions
        @outPorts.out.beginGroup table

    @inPorts.in.on "data", (object) =>
      if @definitions[@table]? and _.isObject(object)
        for key, value of object
          if @definitions[@table].indexOf(key) < 0
            delete object[key]

        @outPorts.out.send object

      # Simply forward as-is if nothiing has been defined
      else if _.isEmpty @definitions
        @outPorts.out.send object

    @inPorts.in.on "endgroup", (table) =>
      if @definitions[table]?
        @table = null
        @outPorts.out.endGroup()

      # Simply forward as-is if nothiing has been defined
      else if _.isEmpty @definitions
        @outPorts.out.endGroup()

    @inPorts.in.on "disconnect", =>
      @outPorts.out.disconnect()

exports.getComponent = -> new SanitizeObjects
