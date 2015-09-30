midi = require 'midi'
input = new midi.input()
output = new midi.output()

input.on('message', (deltaTime, message) ->
  console.log message
)

input.openPort(0)
output.openPort(0);

i = 0
setInterval( ->
  console.log i
  output.sendMessage([ 144, 41, 127 ])
  output.sendMessage([ 144, 42, 15 ])
  output.sendMessage([ 144, 43, 32 ])
  output.sendMessage([ 144, 44, i ])
  i = i + 1 if i < 127
, 500)
