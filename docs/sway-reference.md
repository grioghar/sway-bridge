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


## 9. From the Audima Labs Discord (#sway channel, read 2026-11-22)

Statements by Audima staff ("Isaac | Audima Labs") unless noted; only the most recent few months of one channel were read.

- **Dial CC and channel** are editable in the Sway app: "click the knob icon which is above the layout/regions" (3 Oct 2026). This opens an "Encoder and Pad Mapping" panel.
- **Custom mapping must be switched on at the hardware:** after pushing the project to the device, "click this button on Sway to switch to the custom Encoder and Pad Mapping ... (the pads will turn green)" (4 Oct 2026). The button marked in the screenshot is one of the four small buttons on the right-hand side (bottom row, column nearer the pads). [Reading of a small screenshot: confirm on the unit.]
- **Encoder and Pad Mapping panel** (from the screenshot): dial pages are lettered **A–H**; each dial has a CC and a channel (defaults CC 20–27, channel 1). Pads are numbered across the whole top row first (left four, then right four), then the bottom row; defaults run chromatically C0…D#1. A "Pad Configuration" box sets Scale, Key, Octave, Default channel and Output type (e.g. Chord) with "Apply to pads", and "Click a pad to override chord". "Propagate encoders" / "Propagate pads" buttons copy the mapping (presumably to all presets). The four small buttons each side are drawn hatched, i.e. not configurable, as two columns of upright keys beside the pads.
- A user asked for a jog-wheel style feature (15 Aug 2026); no answer seen.
- Not yet read: older history of #sway, and #software, #technical-support, #report-a-bug, #faq beyond the latest page.
