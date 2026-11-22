# Control surface script for the Audima Sway (Ableton Live 11/12).
from _Framework.Capabilities import (CONTROLLER_ID_KEY, NOTES_CC, PORTS_KEY, REMOTE, SCRIPT,
                                     controller_id, inport, outport)
from .Sway import Sway


def get_capabilities():
    # Lets Live offer this script automatically when the Sway is plugged in.
    return {
        CONTROLLER_ID_KEY: controller_id(vendor_id=0x0483, product_ids=[0x52A4], model_name=['Audima Labs The Sway']),
        PORTS_KEY: [inport(props=[NOTES_CC, SCRIPT, REMOTE]), outport(props=[SCRIPT])],
    }


def create_instance(c_instance):
    return Sway(c_instance)
