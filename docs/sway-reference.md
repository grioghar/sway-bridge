# Audima Labs Sway: Reference

Compiled from web sources. Labels: **[Official]** = stated on an Audima page; **[Review]** = third-party review (MagneticMag); **[Inference]** = my own deduction, not stated by a source. Where a source is absent, the heading says "Not found".

Key sources:
- Home: https://audima.com.au/
- Reserve/product page: https://audima.com.au/op/sway-reserve-b5/
- FAQs: https://audima.com.au/faqs/
- Get Started: https://audima.com.au/get-started/
- Downloads: https://audima.com.au/downloads/
- Tutorials: https://audima.com.au/tutorials/
- Updates: https://audima.com.au/updates/
- Contact: https://audima.com.au/contact-us/
- Review: https://magneticmag.com/2026/08/the-sway-by-audima-labs-could-be-the-most-innovative-midi-controller-of-2026/

## 0. Overview

- Motion-controlled MIDI controller; sends MIDI to DAWs, DJ software, synths, iOS apps; makes no sound itself. [Official] https://audima.com.au/faqs/ , https://audima.com.au/op/sway-reserve-b5/
- Infrared distance sensors read hand position/height; no camera or gloves. [Official] https://audima.com.au/faqs/
- Built-in 16 pads, knobs (dials) and buttons, display, light bar. [Official] https://audima.com.au/op/sway-reserve-b5/
- Retail $830 USD, sold in batches (Batch 5 pre-order ~March 2027, delivery Jun–Jul 2027 per Updates page). [Official] https://audima.com.au/faqs/ , https://audima.com.au/updates/
- Up to 36 presets stored on device. [Official] https://audima.com.au/faqs/

## 1. Front-panel operation

- Preset banks: 6 configurable banks, opened by pressing and holding each one. [Review] https://magneticmag.com/2026/08/the-sway-by-audima-labs-could-be-the-most-innovative-midi-controller-of-2026/
- Hardware: 16 pads, 8 buttons, 1 primary rotary encoder, 8 programmable rotary encoders, 3.2-inch OLED with a dedicated rotary encoder (the review does not describe what the display shows). [Review] (same URL)
- Note: the site's own description mentions a display showing "note, scale, and octave" (product imagery). [Official] https://audima.com.au/op/sway-reserve-b5/
- Exact preset/bank selection button presses, encoder turn/press functions, the 6 display buttons, 8 small-button functions, dial pages, button combinations: **Not found.**
- Low-power mode: **Not found.**
- Brightness: **Not found.**
- Calibration: **Not found.** (Review explicitly does not cover it.)
- Factory reset: **Not found.**

## 2. Regions and gesture expressions

- Layouts: 12 layouts, from 1 to 12 regions. Each region can play a note, a chord, a modulation, or note plus modulation. [Official] https://audima.com.au/faqs/ , https://audima.com.au/op/sway-reserve-b5/
- Layout presets: the Sway app designs custom layouts and regions. [Official] https://audima.com.au/op/sway-reserve-b5/ . Named layout presets: **Not found.**
- Region modes "Modulation / Notes / Trigger": **Not found** by name. Site and review describe the region functions above only.
- Expressions (site, "6D of Expression"): [Official] https://audima.com.au/faqs/ , https://audima.com.au/op/sway-reserve-b5/
  - **Strike**: velocity-sensitive.
  - **Sway**: controls rate of change for texture and depth (site). Review describes Sway as horizontal movement for phrasing. [Review] Note the two descriptions differ.
  - **Pulse**: vertical movement for energy (site); review: vertical movement for energy and dynamics. [Review]
  - **Glide**: smooth movement between notes and chords.
  - **Press**: lowering/lifting the hand controls intensity (site). Review: intensity from hand distance to the sensing area. [Review]
  - **Sculpt**: a second hand adds layers at the same time (site). Review: both hands shape chords, melodies and textures together. [Review]
- Strike threshold, X and Y output definitions, invert, "clear modulation on release": **Not found.** Review only says the sensors detect position in "the XY space above the unit".
- LED strip: 80 motion-reactive LEDs; a row of LEDs shows the zones. Colours and per-state behaviour: **Not found** beyond the review's description. [Review] https://magneticmag.com/2026/08/the-sway-by-audima-labs-could-be-the-most-innovative-midi-controller-of-2026/ . Sway Software handles "colours" for layouts. [Review]

## 3. Scales, chords, pads

- Theory Engine: maps scales, chords and octaves onto the layout so notes stay in key; includes "instant chords". [Official] https://audima.com.au/op/sway-reserve-b5/
- Scale list, chord types, chord inversion, root note/octave settings: **Not found** (only generic mention of scale/chord/octave configuration in the app).
- Pads as notes vs chords: a region can play a note or chord. [Official] https://audima.com.au/op/sway-reserve-b5/ . Per-pad MIDI channel: **Not found.**
- The Sway app assigns notes, chords, scales or any MIDI CC to each control and maps every pad, knob and button. [Official] https://audima.com.au/op/sway-reserve-b5/

## 4. Dials / encoders

- CC assignment: the Sway app can assign "any MIDI CC" to controls. [Official] https://audima.com.au/op/sway-reserve-b5/
- Dial pages, default CC numbers, channels: **Not found.**
- The DAW can send program-change signals (reported by review; the review says recent updates "reportedly" add this). [Review]

## 5. Sway desktop app, projects, firmware

- App: "The Sway" for macOS (Apple Silicon and Intel) and Windows. [Official] https://audima.com.au/downloads/
- Current version listed: **v1.2.0** (only version listed). Downloads:
  - macOS Apple Silicon: https://cdn.audima.com.au/software/v1.2.0/The.Sway_1.2.0_aarch64.dmg
  - macOS Intel: https://cdn.audima.com.au/software/v1.2.0/The.Sway_1.2.0_x64.dmg
  - Windows: https://cdn.audima.com.au/software/v1.2.0/The.Sway_1.2.0_x64_en-US.msi
  - Windows DFU driver (install once so Windows can update firmware): https://cdn.audima.com.au/software/Windows%20DFU%20Driver.zip
  - Source: https://audima.com.au/downloads/
  - (Not downloaded or run, per instructions.)
- App features: layouts, notes, chords, scales, gesture-to-MIDI mapping, colours, saving presets to the device; firmware updates install through the app. [Official] https://audima.com.au/faqs/
- Project files (.swayproj): base project "Audima Labs The Sway V2.swayproj" https://cdn.audima.com.au/software/Audima%20Labs%20The%20Sway%20V2.swayproj ; demo projects (Vital, Logic, Garage, DNB, Hip Hop) listed on https://audima.com.au/downloads/
- Preset upload: the Get Started page says "load projects" through the app. [Official] https://audima.com.au/get-started/ . Exact upload steps: **Not found.**
- Firmware update process: via the Sway app; Windows requires the DFU driver first. Full procedure is in the "Firmware & software update guide" PDF: https://cdn.audima.com.au/docs/Audima%20Labs%20The%20Sway%20Firmware%20Update%20Guide.pdf . **Not read**: the fetch tool rejected the file for size (over 10 MB). Its steps are therefore **Not found** here.
- Firmware version history / changelog: **Not found.** The only release note link is a video, "What's new in v1.2.0": https://youtu.be/YznUAxwg920 (not read). Updates page lists production batches, not software versions: https://audima.com.au/updates/

## 6. DAW and MIDI integration

- Official MIDI remote scripts (zip/ .midiremote) on the Downloads page:
  - Ableton Live 10, 11, 12 remote scripts: https://audima.com.au/downloads/ (cdn.audima.com.au/daws/ableton/...)
  - Cubase: `Audima Labs The Sway Cubase.midiremote` https://cdn.audima.com.au/daws/cubase/Audima%20Labs%20The%20Sway%20Cubase.midiremote
- Max for Live devices: **Not found.**
- Logic, FL Studio, Rekordbox, Serato, Traktor, VirtualDJ: setup via tutorials (see section 8); no separate remote script listed for them.
- MIDI Out: 3.5 mm TRS (Type A) jack; 5-pin DIN needs a Type A adapter (check synth manual for Type B wiring). [Official] https://audima.com.au/faqs/
- USB-C is the computer connection (Mac, Windows, iPhone, iPad; iPad needs the second USB-C port for power). [Official] https://audima.com.au/faqs/
- MPE support: **Not found.** MIDI implementation chart: **Not found.** MIDI channel configuration: **Not found.**

## 7. Hardware specs, accessories, FAQ

- Sensors: 16 infrared distance sensors with overlapping coverage (not skeletal tracking). [Review] (same URL). Detection range: **Not found.**
- Power: use only a regulated USB-C PD (Power Delivery) compliant supply; non-PD may cause permanent damage. [Official] https://audima.com.au/get-started/
- USB: one dual-role USB-C (power and data) plus one additional USB-C power port. [Review]
- Dimensions about 45 × 17 × 4 cm; weight about 2 kg. Soft padded carrying case included. [Review]
- Power consumption: **Not found.**
- Care: keep out of direct sunlight; don't press or force the sensor array; clean only with a soft dry lint-free cloth (no chemicals, water or abrasives). [Official] https://audima.com.au/get-started/ , https://audima.com.au/faqs/
- Warranty: free 180 days from delivery; optional Sway Care+ 12 months incl. accidental damage. 30-day money-back return policy. [Official] https://audima.com.au/faqs/
- Troubleshooting (official FAQ): try a different USB-C cable/port directly to computer (not a hub); select Sway as MIDI input and match MIDI channel; update firmware and app; restart software with Sway connected; keep out of direct sunlight; contact support with order number, setup and a short video. [Official] https://audima.com.au/faqs/
- Known issues/bugs: none listed officially. Review caveats: not built for heavy durability; learning curve. [Review]
- Accessories: Sway App access and two USB-C cables are mentioned in a third-party Reverb listing (not verified on Audima's site): https://reverb.com/item/99410012-new-audima-labs-sway-motion-midi-controller-2026-black

## 8. Community and learning

- Discord: https://discord.com/invite/CYUrJXjjN4 (3,000+ members per FAQ). [Official] https://audima.com.au/ , https://audima.com.au/faqs/
- Forums: **Not found** (none linked).
- Support email: contactus@audima.com.au (shown on the Contact page). [Official] https://audima.com.au/contact-us/
- YouTube channel: https://www.youtube.com/@audimalabs ; Instagram @audimalabs ; Facebook link on the homepage.
- Tutorials page (https://audima.com.au/tutorials/), playlists:
  - Ableton Live: https://www.youtube.com/playlist?list=PLuS0mVV699ffgV0_p4tFcdsi2spPoMkZv
  - Logic Pro: https://www.youtube.com/playlist?list=PLuS0mVV699ffQYiNC7OoJ2ZboSRS6ze38
  - Cubase: https://www.youtube.com/playlist?list=PLuS0mVV699fcuxDWioGasbKqnTF_MM6nc
  - FL Studio: https://www.youtube.com/playlist?list=PLuS0mVV699fdI22qpVsOod2Clg3mpOfHN
  - Serato DJ: https://www.youtube.com/playlist?list=PLuS0mVV699ffpCvQ_M8tKhCtspY_Zwiid
  - Rekordbox: https://www.youtube.com/playlist?list=PLuS0mVV699fcJTSF_rTrLyDm8gHPGihEN
  - Traktor: https://www.youtube.com/playlist?list=PLuS0mVV699ffGEXLRE7FRZK2xKA-f6CzZ
  - Sway Software (customising, uploading projects, saving presets, master effect controls): https://www.youtube.com/playlist?list=PLuS0mVV699fccXh6mRSUfj_tj4CFfyYS4
  - Explore Sway: https://www.youtube.com/playlist?list=PLuS0mVV699ffNV1k3FXHAGwIyFSErtHkA
  - Play a hardware synth with Sway (Roland JU-06A demo): https://www.youtube.com/watch?v=LUs8Di-kWKs
- Get Started video links (care, unboxing): https://www.youtube.com/watch?v=vTWZgu7Bl2Q , https://www.youtube.com/watch?v=1_KhQvXNDh4
- Sway overview video: https://www.youtube.com/watch?v=RnAa7wgdjvg
- Individual video titles inside playlists were not listed by the source. Concrete operating details in video descriptions: **Not found** (not fetched).
- User manual PDF: **Not found** on audima.com.au (no manual link on any page read). Search returned no manual.

## Not found (summary)

Button-level front-panel operation, bank/preset selection keys, display button and encoder functions, dial pages, low-power, brightness, calibration, factory reset, Modulation/Notes/Trigger modes, Strike threshold, X/Y definitions, invert, clear-on-release, LED colour behaviour, scale and chord-type lists, inversion, root/octave, per-pad MIDI channel, CC defaults, Max for Live, MPE, MIDI implementation chart, detection range, power consumption, firmware changelog, firmware procedure (PDF unread), user manual, forums.


## 9. From the Audima Labs Discord (read 2026-11-22)

Read in full (all text channels visible to a member, 2026-11-22): #sway, #updates, #software, #technical-support, #report-a-bug, #feature-request, #setup-sway, #faq, #sway-tutorials, #ideas, #design-talk, #general-chat (all 2,488 messages), #djs, #producers, #musicians, #launch-chat, #studio-setup, #sway-content, and the three batch/announcement channels. #newcomers was sampled (810 join greetings, nothing about the device). Not read: threads inside channels, and attachments (images, videos, files).

### Hardware operation
- **Power on/off:** press and hold the display encoder (staff, Sep 2025).
- **Presets:** the six round buttons at the display select the 6 presets of the bank (user, Dec 2025).
- **Custom pad/dial mapping ("keys mode"):** press and hold for 3 s the **bottom-left black button of the right-hand group** to switch the pads and dials to the custom mapping stored in the preset; the pads turn **green** instead of the normal pink (staff, 13 Jul and 4 Oct 2026; mod, May 2026). Custom knob CCs "not remembered" is nearly always this switch not being made, or the project not pushed.
- With the Ableton script, the **black buttons change what the white pads do** (arm, solo, etc.) and the pad colours change with the function; the bottom-right black button on the right side toggles record (users, Jul 2025 / Jun 2026).
- **No calibration procedure** exists (staff, Sep 2025). **Factory reset** = reload the base project (mod, Jan 2026). "Delete" a preset = upload a blank one to that slot (staff, Sep 2026).
- Pads are stiff; press nearer the edge than the centre (mod, May 2026).
- The display shows a "voicing" screen for Instrument regions; a region set to Instrument rather than Modulation does not give X/Y modulation (mod, Jan 2026).

### Power
- Sway needs more power than some ports give (notably M1 MacBooks): it boots, then shuts off after ~2 s, or shuts off during use. Fix: second USB-C cable from the **middle (power-only) port** to a wall adapter; plug power first, then data, then switch on (staff, repeatedly).
- **Low power mode** (firmware 1.3.0): the app's Sway logo is **yellow/orange** instead of purple; everything works, LEDs are dimmer. Grey = not connected. A USB-A to C cable works but forces low power.
- Sensors skipping/jumping across the middle, or constant triggering: power the unit properly, or wait ~5 s after plugging in before switching on so the sensors initialise (staff, Aug 2026).
- For the firmware update on an M1, the power cable had to be unplugged and only the data cable reconnected (user, May 2026).

### Software 1.2.0 + firmware 1.3.0 (released 28 Apr 2026)
- New: two-handed note playing, **MPE**, customisable buttons & knobs, **preset switching via Program Change**, adjustable LED brightness, low power mode, copy/paste/move regions and presets, pull projects from the Sway.
- **Program Change is receive-only:** the Sway changes preset when it receives a PC; it cannot send PC (staff, 29 Apr 2026). Walkthrough: https://youtu.be/YznUAxwg920?t=450
- Firmware version: click the SWAY word at the bottom-left of the app. Units shipped mid-2026 already have 1.3.0.
- Updating: uninstall the old app first, install 1.2.0, on Windows install the DFU driver; update video https://www.youtube.com/watch?v=KFL2E-Oj8js . Failed/hung updates and units not powering up afterwards were reported (May 2026).
- "Beat stutter" was renamed **Trigger** in the new app (staff, May 2026). Full app walkthrough incl. two-handed mapping and X triggers: https://youtu.be/AlOIoXLroMA
- MPE could not be selected on some layouts (worked on the 12-note grid, not on a 6-note grid with two Y regions) (user, Jul 2026).
- In Instrument regions the CC channel can only be changed after choosing a note; otherwise CCs go out on channel 1 (user, Feb 2026).
- Region colours: start colour applied, active colour sometimes unrelated (user, Jul 2025, older firmware).
- The app does not follow preset changes made on the hardware; it only builds and uploads (mod, Dec 2025). No 1x16 layout; layouts are fixed, not user-drawn (staff, Aug 2026). Key/scale can only be changed in the app (button top-right above the layouts), not from the hardware (Sep 2026).
- A written manual PDF exists (posted by staff as an attachment in #sway, 5 May 2026).

### DAWs and MIDI
- Ableton script: separate versions for Live 10 and Live 11+ (tested 10.1, 11.3, 12.3). Must sit directly in `User Library/Remote Scripts` (exact spelling, not zipped, not nested); on Windows delete the Mac file inside the script folder; enable Remote and MPE on the Sway's ports. Live 8 is not supported.
- Notes/CC only appear after a project has been pushed to the device.
- Hardware synths: TRS MIDI out; watch for one-octave note-name offsets between devices.
- iOS/iPad works over USB-C with the second cable on power.
- Community projects mentioned: a web-based version of the config app with a shared device library (Dec 2025), a standalone performance app incl. Android (Nov 2026), a Linux user documenting setup (Aug 2025).

### More from #report-a-bug, #feature-request, #setup-sway
- **Upload Project** sends all 36 presets; **Upload Preset** sends only the active preset and is much faster (staff, Jan 2026).
- **Pad colours:** pink/purple = default pad mode; other colours appear when the Ableton script is engaged (e.g. red for arm, with solo etc. on other button pages); green = custom "keys" mapping. Pad LED colour is not user-configurable (staff, Mar 2026). Arm only works on MIDI tracks; switch the Sway on before opening Live.
- Before firmware 1.3.0 the pads and knobs had fixed outputs; 1.3.0 added full customisation of encoders and pads (staff, Jan-Apr 2026).
- The app has a **channel swap** feature that lets the two sides play different instruments (user, Jul 2026).
- **Sleep** option on the device: older firmware woke up on its own while the display still said "sleep" (bug acknowledged Dec 2025).
- Power adapter for the middle port should be USB PD compliant; staff ask "below 35 W?" when diagnosing.
- No Android/phone app; app is Mac and Windows only (staff, Nov 2025). MIDI in / thru were "being tested" in Sep 2024; the shipped unit has MIDI out only.
- Requested, not available: sensor sensitivity control (adjacent regions flicker on a 4x3 grid), on-device key/scale selector, X/Y scaling factors, region naming (a show/hide region info toggle is done for the next app update, Jun 2026), sending Program Change, jog-wheel mode, arming several tracks at once.

### More from #faq, #sway-tutorials, #ideas, #design-talk
- **Banks: press and hold preset button 1-6 for about 2 seconds to switch to bank 1-6** (staff, 30 Jul 2026; moderator, Jul 2025). A short press selects that preset within the current bank. 6 banks x 6 presets = 36, all reachable from the hardware.
- Some settings (e.g. channels) can be changed on the device itself through the display (moderator, Jul 2025); details not described.
- **Written user manual:** linked from https://audima.com.au/tutorials/ (staff, 27 Jun 2026).
- **Small black buttons:** have no fixed function by default and can be MIDI-mapped freely; with the Ableton script each gets a dedicated function (staff, Jul 2025; walkthrough video from about 2:20). They are not backlit.
- Mapping tip for regions with two outputs: set one CC to "--" (off) while MIDI-learning the other, then swap (moderator, Jul 2025).
- MPE is supported (staff, May 2026). Sway uses up to 16 MIDI channels (staff, Jun 2025).
- Outputs: TRS MIDI out, USB-C data+power, USB-C 5 V power only.
- No output range scaling (e.g. 0-64) on the device; scale in the DAW or with a MIDI translator (users, 2026). Rekordbox cannot map one CC to several functions; Serato can; users rely on Bome MIDI Translator and similar for Rekordbox/Traktor.
- Pad LEDs cannot be driven over MIDI in; requested for DJ feedback (Jul-Sep 2026), staff "can look into" it.
- A community member built a web companion tool that writes the official `.swayproj` file format with a shareable "device library" of CC charts (Dec 2025); Audima's developer said they would rather integrate device libraries into the official app.

### From #general-chat (Feb-Nov 2026)
- **Pad modes:** "cycle through the pads till they turn green" puts them in note mode, playable like a piano (moderator, Jun 2026); see the 3-second hold on the right-hand bottom-left black button above.
- **The four black buttons per side** with the Ableton script: navigate Session view and launch/stop scenes; without the script they are free to map (staff, Jun 2026). Users find them more precise than the pads for split-second cues; the pads' contacts are at their outer edge and cannot be calibrated.
- Presets are created and edited only in the app, then pushed and stored on the device (staff, Feb 2026). Preset changes can be automated from MIDI clips via Program Change.
- No OSC output; MIDI only (staff, Feb 2026). Outdoors: keep direct sunlight off the sensors; stage lights and lasers do not interfere (staff, Feb 2026).
- Power on: long-press the big round knob at the display.
- Third-party: github.com/gantasmo/theDAW advertises Sway features (Jun 2026); not examined.
- **Manual:** https://cdn.audima.com.au/docs/Audima%20Labs%20The%20Sway%20User%20Manual.pdf (linked from the Tutorials page). Summarised in section 10.

## 10. From the official User Manual (PDF, 37 pages, (c) 2026, read 2026-11-22)

Source: https://cdn.audima.com.au/docs/Audima%20Labs%20The%20Sway%20User%20Manual.pdf . Paraphrased; where it differs from Discord posts the manual is listed as the reference and the difference is noted.

### Front panel
- **Scroll-Click Wheel** (the knob at the display): long-press 2 s to power on, long-press 2 s to power off. Scroll to move through the on-device parameters/axes; press to select; press again to deselect.
- **Always power off with the wheel before unplugging**: unplugging while powered on "may cause preset corruption".
- **Preset buttons 1-6:** press to load that preset of the active bank. **Bank change is two steps: hold any preset button until the display shows bank selection, then press 1-6 to choose the bank.** (Discord staff describe it as holding button N for ~2 s to go to bank N; try both on the unit.)
- **Display:** Instrument region shows Note / Voicing / Oct; Modulation shows Axis / CC / Y1; Trigger shows Trigger / Y; second hand shows X2 / Y2; `B1P3` = bank 1 preset 3; `SLEEP` = sensors paused.
- **SLEEP mode:** pauses all sensors. Scroll the wheel through the axes; SLEEP is one of the options; scroll again to an axis to wake.
- **Click knobs (x8):** turning sends a CC; **pressing a knob sends a second, independent CC**. CC number and channel are set per knob.
- **Drum pads (16):** send a note; not velocity sensitive by default; notes/chords set in the app's Encoder & Pad Mapping.
- **Mappable buttons:** "assignable buttons that send MIDI CC values. Configurable per preset."
- **MIDI-learning one axis at a time:** scroll the wheel to X1 or Y1, press to select, move your hand so the DAW learns it, then **press again to deselect**. While an axis is selected the Sway outputs only that axis; forgetting to deselect is the most common mapping mistake.

### Regions
- Two modes: **Instrument (I)** triggers a note or chord on entry and shows LED columns; **Modulation (M)** sends CCs and shows a single tracking dot. (This project's "Notes" mode is Audima's Instrument.)
- Layouts named in the manual: 4x3 (12 regions), 4x2, 2x2, 4x1, 1x1, 2x3 + XY, 3x3 + Y, 2x3 + dual Y.
- Modulation types: 1D fader (one axis), 2D fader (X and Y), **X-Trigger / Y modulation** (a trigger CC fires on entry, Y is continuous). X and Y each take any CC on any channel 1-16. **X2 / Y2** are the second hand's CCs, used when **Link Hands** is switched off; they must differ from the first hand's CCs. This explains the "second copy" of the X and Y CCs in the preset data.
- **Invert Horizontal Axis** reverses X output and the LED animation. **Clear CC on Release** resets the CC to 0 when the hand leaves.
- Instrument settings: voicing Unison or a chord (Major, Minor, Sus2, Sus4, Diminished, Augmented, more); inversion root / 1st / 2nd.
- Gestures, enabled per Instrument region: **Strike** velocity from entry speed (automatic, no mapping); **Sway** shake left-right gives rate of change on a CC; **Pulse** raising the hand after a note raises a CC; **Press** pushing down sends a CC **or Aftertouch**; **Glide / MPE** each note on its own channel, sliding between regions bends pitch (toggle in Scale Selection, then Apply to Regions); **Sculpt** notes with one hand, modulation with the other.

### App
- Task bar: preset name, Reset Region Order, Scale Selection (piano icon: scale, key, Assign to Regions, MPE toggle), Encoder/Pad Mapping (knob icon).
- Device menu: Push Preset, Push Project (overwrites all 36), Pull Preset (active one), Pull Project.
- Project files are named `.swayproj.json` in the manual. (The file saved by app 1.2.0 on this Mac was a binary `.swayproj`; unresolved.)
- LED colours: start and end colour per region; black start = dark until played. Brightness: Cmd-] and Cmd-[ in the app.
- Copy/swap presets by right-click; Cmd/Ctrl-drag a region to copy it, plain drag to swap. Propagate Pads / Propagate Encoders copy that mapping to all presets.
- Presets may be cleared by major firmware updates; save the project first.

### Program Change (receive)
- A MIDI clip routed to the Sway with **Bank and Program set to the target bank and preset number** switches preset when played.
- **Bank 0, Program 37 = enter SLEEP; Bank 0, Program 38 = exit SLEEP.**
- **Measured on firmware 1.3.0 (2026-11-22):** a raw Program Change on channel 1 with value 0-35 selects preset `bank * 6 + preset` (both counted from 0), with no Bank Select needed: value 2 gave bank 1 preset 3, value 7 gave bank 2 preset 2, value 35 gave bank 6 preset 6. The manual's 37 and 38 are the same scale counted from 1 (raw 36 and 37); sleep/wake were not tried.

### Hardware
- Ports: MIDI out **TRS Type A** (left), USB-C power in (middle; wall adapter rated under 35 W), USB-C host data+power (right). Class-compliant USB MIDI on macOS, Windows 10+ and Linux.
- The manual says the LED beam has 16 RGB LEDs; the device's own data and the press say 80 addressable LEDs. 16 sensors.
- Base project: 36 presets, all in B minor. Banks: 1 founder's favourites, 2 instrument layouts, 3 instruments + expressions, 4 notes + modulation, 5 one modulation feature each, 6 one gesture each (6-1 Pulse, 6-2 Press, 6-3 Sway, 6-4 Glide/MPE, 6-5 Sculpt, 6-6 Strike).

### Open questions this raises for the project
- Where the knob-press CCs and the mappable-button CCs live in the preset bytes (candidates: the three unexplained 16-byte arrays after the pad notes, and region bytes 45-48, 72, 77).
- Whether the idle "notes 0-14" seen on the wire were knob presses or buttons in the default (non-custom) mode.

### From the remaining channels (#djs, #producers, #musicians, #launch-chat, #studio-setup, #sway-content, older #general-chat)
- **Ableton script details (staff, Apr and Dec 2025):** the Sway's buttons solo, mute and arm tracks, navigate scenes, launch/stop individual scenes and master scene launch/stop. The lit pads mirror the Live set: with four tracks only four pads light; add tracks and more light up. Pressing the right-hand black button cycles the pad function/colour pages.
- **Default pad behaviour:** the Sway has two built-in pad configurations by default (staff, Jan 2026); firmware 1.3.0 added the custom one where each pad's note, CC or chord is set in the app. Pad colours are still not configurable.
- **Region capacity (staff, Oct 2024):** up to 15 notes per region. (Staff also said up to 16 regions at that time; the shipped app and manual have 12.)
- **Lighting:** the Sway works better in the dark; haze/smoke is fine unless aimed straight at it (staff, Feb 2025). One user reported erratic sensors in a dim room (Jun 2025), and another a sensor "blind spot" that made the controller go wild (Jul 2025).
- **Display:** dim and hard to read on stage per a user; staff say that brightness is normal (Aug 2026). No display brightness setting.
- **Push 3 standalone:** the remote script installs on Push 3 and works, including Program Change preset switching; easiest is to map in Live and transfer the set (user, Aug 2026).
- **DJ use:** Serato maps well and allows one CC on several functions; Rekordbox rejects a CC that is already assigned, so users give every preset its own CC numbers (preset = which CCs are sent) or use a MIDI translator. No direct connection to standalone CDJs/mixers: it needs a laptop running DJ software or a DAW. Traktor works as a generic MIDI controller; no official Traktor tutorial yet. Staff planned to export their mappings for import (Jun 2026).
- **Press ("push") gesture:** modulation starts from the height at which the note was triggered rather than using the full height (user, Jul 2026).
- **Other software:** no TouchDesigner patch, no Linux or mobile configuration app; any MIDI-capable software works for playing. Ableton Live Standard is enough; Suite only adds instruments and Max for Live (staff, Apr 2025).
- The display-knob cap and the eight encoder caps are standard enough that staff offered dimensions for 3D-printed replacements (Feb 2025).

## 11. Discord threads and Audima's tutorial videos (2026-11-22)

Videos were read as YouTube's auto-generated transcripts, not watched: anything shown only on screen ("click this button here") is not captured.

### Threads
- The server has four threads in total (one in #sway, three in #technical-support). Only new fact: the sensor board cannot be separated from the unit (staff, May 2026).

### "What's New in the Sway Update" (YznUAxwg920)
- **Dial pages are chosen by clicking a knob.** Clicking a knob switches the MIDI channel that all eight knobs send on; clicking the first knob returns to the original. Eight knobs x eight channels = "up to 64 different controls". This is the A-H page selection.
- **Pad layouts:** pink = the built-in finger-drumming layout; green = the custom layout edited in the app (reached with a button on the Sway).
- Pad Configuration "output type" includes Chord and Lead (single notes); Apply to Pads fills all pads from the chosen key and octave.
- Propagate Pads / Propagate Encoders copy the custom mapping to every preset; without it a change stays on the one preset.
- Two-handed note playing is automatic on all instrument grids.
- MPE: piano icon, enable MIDI Polyphonic Expression, Apply to Regions, push; the instrument must have MPE enabled too.
- Program Change in an Ableton MIDI clip routed to "Audima Labs The Sway": set Bank and Program (sub-bank unused), e.g. bank 1, program 3 for preset 3. Bank 0 with program 37 = sleep, 38 = wake.
- App: Cmd-[ / Cmd-] dim and brighten the LEDs (with min/max warnings); right-click presets to Select, Copy from, Swap; Cmd-drag a region to copy it, drag to swap.

### "Master Sway's Effect Controls & App Settings" (AlOIoXLroMA) and "Instrument Modes & Gesture Controls" (PFm-i0fTJqU)
- Region colours: start colour is the lowest height, end colour the highest; the LED shows the gradient between them as the hand rises.
- Modulation settings: Horizontal and Vertical CC, each with its own channel; the Sway's display shows the same numbers. Clicking **Link Hands** reveals the second hand's CC settings, which must be different numbers from the first hand's. To map the second hand, put two hands in the region while the DAW is learning.
- **Beat Stutter** checkbox (later renamed Trigger): no tracking dot, a brighter beam on entry and a gradient with height. Entry sends a button CC (learn it by putting a hand in and taking it out), height sends a second CC (learn it by leaving the hand in).
- Invert Horizontal Axis flips X (and the LED); Clear CC on Release drops the CC to 0 and the LED goes out when the hand leaves.
- Instrument settings per region: note, octave, chord type (Unison = single note), inversion, and per-note manual edits of note, octave and channel. Expression checkboxes: Strike, Sway, Pulse, Press. Sway is learned by shaking the hand in the region, Pulse by lifting, Press by pushing toward the base.
- Piano icon: choose scale and key, Assign to Regions; choose Unison for single notes.

### "Get familiar with the Sway app" (Tor7iyJxSlc), "Setting Up the MIDI Remote Script" (1JCoFNKi8LU), "How to map Sway to Ableton Live" (YGrEHJ4MAkQ)
- **Banks, from Audima's own app tutorial: long-press preset button 2 to reach bank 2, button 3 for bank 3, and so on.** (The newer manual describes hold-then-press; firmware may have changed.)
- The app's Sway icon is purple when connected.
- **Remote script behaviour:** purple pads all lit = script not engaged (reset the control surface). With it engaged the pads show one per track and solo tracks; one black button cycles the pads solo -> arm -> mute; other black buttons move the session box left/right/up/down; one launches and stops the master scene. Knobs control track volume; **clicking knob 2 switches them to pan, knob 3 to send A, knob 4 to send B, knob 1 back to volume.** Ports: input Track + Remote + MPE, output Track + Remote.
- Mapping walkthrough confirms the factory preset values seen in this project's captures: bank 1 preset 2 sends Y1 = CC 38 and X1 = CC 50, second hand from CC 52; bank 1 preset 3's trigger region sends CC 14 on entry and CC 18 for height.
- "Sway Beginner Guide" (5HF4dUurW_o): uses the free Vital synth and a "Vital Sway preset pack" project; MPE glide works best entering the centre of a region and then sliding sideways. Nothing else new about the hardware.
