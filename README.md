# cranes
stereo varispeed looper / delay / timeline-smoosher

quick start:

- plug a stereo signal or two mono signals into the inputs on norns.
- head over to the params page.
- nb: when the buffer is completely cleared (at startup and after KEY 3 + KEY 1 are held), cranes will record incoming audio at 1x speed into both buffers and will immediately play back at the rates specified in the params page.
- nb: left input will write to voice 1, right input will write to voice 2.
- for the most immediate fun, I suggest setting speed voice 1 to 0.5 and speed voice 2 to -1.
- head back to the performance interface.
- tap KEY 2 to record into the buffers. also, make some sounds!
- to loop, tap KEY 2 again. this sets the loop points (s1/e1 and s2/e2) to the length of the recording. you should hear your material played at half-speed on the left and reversed on the right. you should see the one / two counters counting in the same direction and at the same speed as your audio.
- hold KEY 1 until you see s1 and e1 change to s2 and e2. this switches which buffer you want to control with the buttons and encoders.
- use ENC 2 and ENC 3 to adjust the start and end points of the selected buffer’s loop, with 1/10th second resolution. you should see the counter for the buffer lock to the new start and end points.
- tap KEY 2 to toggle overdub / overwrite for the selected buffer. you will see some friendly birds flying alongside your loop when overdub / overwrite is engaged.
- nb: to retain continuous audio, overdub / overwrite write to the selected buffer at the rate specified in the params page.
- adjust ENC 1 to crawl the spectrum of overdub / overwrite. over: 0 is full overdub, adding incoming audio to the pre-existing audio in the selected buffer. over: 1 is full overwrite, replacing pre-existing audio in the selected buffer with incoming audio.
- fun thing to try: adjust start and end points past the existing audio and write into a new section of the selected buffer, then slowly re-introduce the prior section.
- tap KEY 3 to perform a speed bump on voice 1. hold KEY 3 to produce a more dramatic change. KEY 3’s influence is selectable in the params, under KEY3. ~~ is a small pitch deviation, 0.5 is half-speed, etc.
- hold KEY3 + KEY 1 to completely erase all buffers. if you hit KEY 2 again after this, you’ll get back to the paper crane.

**grid stuff:**

- plug in a grid and re-boot cranes
- use the following legend (still valid for 2.3):
![cranes: grid interface legend](https://llllllll.co/uploads/default/original/3X/e/b/eb0fb77835e0a1fafc7afcaa85569408a03fcebf.jpeg)
- *speed + direction*: -4x to 4x, 0 in the middle (unlit) functions as ‘pause’
- *sync playhead to other*: sync the voice’s playhead to the location of the other’s
- *re-size loop to other*: dynamically adjusts the voice’s current loop points to the other’s
- *reset playhead to start*: trigger voice to playback from currently defined start point
- *create snapshot*: collect speed + direction, playhead position, start and end points and assign it to a button on the far left (similar to less concepts)
- *erase all*: erase all of the voice’s snapshots (similar to less concepts)
- *snapshot recall*: recall a saved snapshot’s parameters
- *start point adjustment* + *end point adjustment*: add or subtract time from the voice’s start and end points, in 0.01 second or 0.1 second increments
- *window adjustment*: adjust voice’s loop window by 0.01 second increments or by the distance between the start and end points

**changelog:**

*240923, cranes 2.3*
- fixed buffer clearing issue
- renamed params separators
- sidestepped the worst of voice 2 -> buffer 1 recording overlaps
- generic code optimization

*5/7/2019, cranes 2.12*
- exposed param for input levels
- created param to switch which buffer voice 2 references (buffer 1 or buffer 2). default (2) is "new cranes", where both buffers are only written simultaneously during paper crane. switch this param (2 -> 1) to unlock "old cranes", where voice 2 references buffer 1 for pitched delays and all kind of cool things.
- generic code optimization
