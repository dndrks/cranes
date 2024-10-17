engine.name = "CheatCranes"

CheatCranes = include 'lib/engine_init'
_ca = include 'lib/clip'

function init()
  CheatCranes.init(3,true)
  _ca.init(3)
end