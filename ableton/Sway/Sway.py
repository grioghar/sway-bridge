# The Sway's eight dials follow whatever you are working on in Live.
#
# The dials send CC 20-27; the dial page chooses the MIDI channel (factory presets):
#   page 1 (ch 1)  parameters of the selected device (the blue hand)
#   page 2 (ch 2)  volume of tracks 1-8
#   page 3 (ch 3)  pan of tracks 1-8
#   page 4 (ch 4)  send A of tracks 1-8
#   page 5 (ch 5)  send B of tracks 1-8
#   pages 6-8      untouched, free for MIDI mapping or the Sway Map device
#
# Pads, sensor regions and buttons are not claimed, so they still reach tracks.
# If a preset changes the dial CC numbers or channels, edit the constants below to match.
import Live
from _Framework.ControlSurface import ControlSurface
from _Framework.DeviceComponent import DeviceComponent
from _Framework.EncoderElement import EncoderElement
from _Framework.InputControlElement import MIDI_CC_TYPE
from _Framework.MixerComponent import MixerComponent

DIAL_CCS = tuple(range(20, 28))
DEVICE_CHANNEL, VOLUME_CHANNEL, PAN_CHANNEL, SEND_A_CHANNEL, SEND_B_CHANNEL = 0, 1, 2, 3, 4
NUM_TRACKS = 8


class Sway(ControlSurface):

    def __init__(self, c_instance):
        super(Sway, self).__init__(c_instance)
        with self.component_guard():
            self._device = DeviceComponent(name='Device')
            self._device.set_parameter_controls(self._dials(DEVICE_CHANNEL, 'Device_Dial'))
            self.set_device_component(self._device)     # follow the selected device

            self._mixer = MixerComponent(NUM_TRACKS, name='Mixer')
            volumes = self._dials(VOLUME_CHANNEL, 'Volume_Dial')
            pans = self._dials(PAN_CHANNEL, 'Pan_Dial')
            sends_a = self._dials(SEND_A_CHANNEL, 'Send_A_Dial')
            sends_b = self._dials(SEND_B_CHANNEL, 'Send_B_Dial')
            for index in range(NUM_TRACKS):
                strip = self._mixer.channel_strip(index)
                strip.set_volume_control(volumes[index])
                strip.set_pan_control(pans[index])
                strip.set_send_controls((sends_a[index], sends_b[index]))
        self.log_message('Sway control surface loaded')

    def _dials(self, channel, name):
        return tuple(
            EncoderElement(MIDI_CC_TYPE, channel, cc, Live.MidiMap.MapMode.absolute, name='%s_%d' % (name, i + 1))
            for i, cc in enumerate(DIAL_CCS))
