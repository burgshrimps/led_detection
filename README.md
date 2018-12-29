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
- Specify region of interest (ROI) which includes the LED lamp.
- Specify first frame where analysis should begin. It has turned out that starting from the begin of the video is highly unstable because of unpredictive movement like an arm over the LED before the start of the experiment. 
- Go through the video frame by frame until there is a significant change in the values of the pixels in the ROI. 
- Then look for circular objects with the function 'imfindcircles' of the Image Processing Toolbox given some experimentally determined parameters.
- If a LED light has been detected compare the timestamp of said detection with the corresponding button press timestamp.
- Save the frame of the detection as a PNG image to check for possible mistakes during the detection.
- Since we know the timestamp of the next button press and difference between the current LED light and button press we can calculate an estimate of when we expect the next LED light to appear. 
- Reposition the ROI in case the LED light moved. 
