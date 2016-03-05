atem = require 'applest-atem'
midi = require 'midi'
cson = require 'cson'

config = cson.load('./config.cson')
input = new midi.input()
output = new midi.output()
switcher = new atem()
switcher.connect('172.16.0.100')

MAX_CHANNEL = 8
RED_COLOR   = 15
GREEN_COLOR = 32
ORANGE_COLOR = 23
CHANNEL_FUNC_BASE = 72

# Commands
NOTE_ON_COMMAND = 144
MODE_CHANGE_COMMAND = 176

# Button Mappings
DEVICE_BUTTON = 105
MUTE_BUTTON   = 106
SOLO_BUTTON   = 107
RECORD_BUTTON = 108

input.openPort(0)
output.openPort(0)

switcher.on('connect', ->
  console.log('connect')
)
switcher.on('disconnect', ->
  console.log('disconnect')
)

switcher.on('stateChanged', (err, state) ->
  for mapping in getPreviewMappings()
    if mapping.atemInput == state.video.previewInput
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, GREEN_COLOR])
    else
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 0])

  for mapping in getProgramMappings()
    if mapping.atemInput == state.video.programInput
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, RED_COLOR])
    else
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 0])

  for mapping in getPreviewAndProgramMappings()
    if mapping.atemInput == state.video.previewInput && mapping.atemInput == state.video.programInput
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, ORANGE_COLOR])
    else if mapping.atemInput == state.video.programInput
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, RED_COLOR])
    else if mapping.atemInput == state.video.previewInput
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, GREEN_COLOR])
    else
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 0])

  for mapping in getAutoMappings()
    if state.video.transitionPosition != 0
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 127])
    else
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 0])

  for mapping in getAudioOnMappings()
    if state.audio.channels[mapping.atemInput]?.on
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, RED_COLOR])
    else
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 0])

  for mapping in getNextTransitionMappings()
    if switcher.state.video.upstreamKeyNextState[mapping.number]
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 127])
    else
      output.sendMessage([ NOTE_ON_COMMAND, mapping.padAssign, 0])

)

input.on('message', (deltaTime, message) ->
  console.log message
  switch message[0]
    when MODE_CHANGE_COMMAND # Audio Volume
      parseModeChangeCommand(message[1], message[2])
      # return if message[1] < 77 || message[1] > 84
      # channel = message[1] - 76
      # gain = message[2] / 127
      # audioGain = Math.pow(gain, 3.5) # fix me
      # switcher.changeAudioChannelGain(channel, audioGain)

    when NOTE_ON_COMMAND # Buttons
      parseNoteOnCommand(message[1])
      # if message[1] == SOLO_BUTTON
      #   switcher.autoTransition()
      # else if message[1] == RECORD_BUTTON
      #   switcher.cutTransition()
      # else
      #   return if message[2] < 127
      #   channel = message[1] - CHANNEL_FUNC_BASE
      #   switcher.changePreviewInput(channel)
)

parseModeChangeCommand = (padAssign, option) ->
  mapping = getSliderMapping(padAssign)
  return unless mapping?
  switch mapping.mode
    # when "audioPan"
    #   audioPan
    when "audioGain"
      audioGain = Math.pow(option / 127, 3.5) # fix me
      switcher.changeAudioChannelGain(mapping.atemInput, audioGain)
    when "audioMasterGain"
      audioGain = Math.pow(option / 127, 3.5) # fix me
      switcher.changeAudioMasterGain(audioGain)
    when "tbar"
      position = Math.abs((mapping.from || 0) - option) / 127 * 10000
      switcher.changeTransitionPosition(position)
      mapping.from = option if option == 0 || option == 127

parseNoteOnCommand = (padAssign) ->
  mapping = getButtonMapping(padAssign)
  return unless mapping?
  switch mapping.mode
    when "program"
      switcher.changeProgramInput(mapping.atemInput)
    when "preview"
      switcher.changePreviewInput(mapping.atemInput)
    when "previewAndProgram"
      switcher.changePreviewInput(mapping.atemInput)
    when "auto"
      switcher.autoTransition()
    when "cut"
      switcher.cutTransition()
    when "audioOn"
      switcher.changeAudioChannelState(mapping.atemInput, !switcher.state.audio.channels[mapping.atemInput]?.on)
    when "nextTransition"
      switcher.changeUpstreamKeyNextState(mapping.number, !switcher.state.video.upstreamKeyNextState[mapping.number])
    when "runMacro"
      switcher.runMacro(mapping.number)

# class MidiController
getProgramMappings = -> config.buttons.filter( (b) -> b.mode is "program" )
getPreviewMappings = -> config.buttons.filter( (b) -> b.mode is "preview" )
getPreviewAndProgramMappings = -> config.buttons.filter( (b) -> b.mode is "previewAndProgram" )
getAutoMappings = -> config.buttons.filter( (b) -> b.mode is "auto" )
getCutMappings = -> config.buttons.filter( (b) -> b.mode is "cut" )
getAudioOnMappings = -> config.buttons.filter( (b) -> b.mode is "audioOn" )
getNextTransitionMappings = -> config.buttons.filter( (b) -> b.mode is "nextTransition" )

getKnobMapping = (padAssign) ->
  for mapping in config.knobs
    return mapping if mapping.padAssign == padAssign
  null

getSliderMapping = (padAssign) ->
  for mapping in config.sliders
    return mapping if mapping.padAssign == padAssign
  null

getButtonMapping = (padAssign) ->
  for mapping in config.buttons
    return mapping if mapping.padAssign == padAssign
  null
