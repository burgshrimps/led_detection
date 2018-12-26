# LED light detection in video

## Motivation
To correct video frame timestamps of a video recorded with a highspeed camera combinations of a button triggered TTL pulses and a flashing LED lights were used as anchor points. The idea behind those anchor points is further explained in 'timestamp_correction'. This script is only about finding bright circular objects (also LED is flashing) in a video.

## Hard- and Software
- Highspeed camera: Genie Nano M1280 NIR
- Video Recording software: CVB Software Suite
- EEG system: Axona System 

## Setup
- CVB recorded the video signal from the camera and encoded the timestamp of each frame in an AVI container. 
- The highspeed camera sends a TTL pulse to the EEG system every time it acquired a new frame.
- A "button box" was used to transmit a TTL pulse to the EEG system every time the button was pressed. At the same time a LED lit up, clearly visible in the video recording.

## Idea
The two main distinctive features of lit up LED is the increase of pixel values and the roughly circular shape of the light. Together these two features can be used to create a stable way of detecting an LED light. To speed up the whole process and to not go through every single frame of the video the timestamps of the button presses can be used as estimates of when the next LED light is probably being seen.

## Methods
