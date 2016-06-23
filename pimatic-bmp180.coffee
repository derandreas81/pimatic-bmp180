# #Plugin template

# This is an plugin template and mini tutorial for creating pimatic plugins. It will explain the 
# basics of how the plugin system works and how a plugin should look like.

# ##The plugin code

# Your plugin must export a single function, that takes one argument and returns a instance of
# your plugin class. The parameter is an envirement object containing all pimatic related functions
# and classes. See the [startup.coffee](http://sweetpi.de/pimatic/docs/startup.html) for details.
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  declapi = env.require 'decl-api'
  t = declapi.types

  # Include you own depencies with nodes global require function:
  #  
  #     someThing = require 'someThing'
  #  

  # ###MyPlugin class
  # Create a class that extends the Plugin class and implements the following functions:
  class BMP180Plugin extends env.plugins.Plugin
    prepareConfig: (config) ->
      if _.isNumber config.address
        config.address = "#{config.address}"

    # ####init()
    # The `init` function is called by the framework to ask your plugin to initialise.
    #  
    # #####params:
    #  * `app` is the [express] instance the framework is using.
    #  * `framework` the framework itself
    #  * `config` the properties the user specified as config for your plugin in the `plugins` 
    #     section of the config.json file 
    #     
    # 
    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("BMP180Sensor", {
        configDef: deviceConfigDef.BMP180Sensor,
        createCallback:(config, lastState) =>
          device = new BMP180Sensor(config, lastState)
          return device
      })

  class PressureSensor extends env.devices.Sensor

    attributes:
      pressure:
        description: "The measured barometric pressure"
        type: t.number
        unit: 'mbar'
      temperature:
        description: "The measured temperature"
        type: t.number
        unit: '°C'

    template: "temperature"   
    
  class BMP180Sensor extends PressureSensor
    _pressure: null
    _temperature: null

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @_pressure = lastState?.pressure?.value
      @_temperature = lastState?.temperature?.value
      BMP180 = require 'sensor_bmp085'
      @sensor = new BMP180({
        'address': @config.address,
        'device': @config.device,
        'sensorMode': 'ultraHighRes',
        'maxTempAge': 1
      });

      @sensor.init()
      
      Promise.promisifyAll(@sensor)
      super()

      @requestValue()
      @requestValueIntervalId = setInterval( ( => @requestValue() ), @config.interval)
    
    destroy: ->
      clearInterval @requestValueIntervalId if @requestValueIntervalId?
      super()
      
    requestValue: ->
      @sensor.getPressure( (error, value) =>
        if value > -50
          @_pressure = value
          @emit 'pressure', value
      )
      @sensor.getTemperature( (error, value) =>
        if value > -50
          @_temperature = value
          @emit 'temperature', value
      )

    getPressure: -> Promise.resolve(@_pressure)
    getTemperature: -> Promise.resolve(@_temperature)

  # ###Finally
  # Create a instance of my plugin
  myPlugin = new BMP180Plugin
  # and return it to the framework.
  return myPlugin
