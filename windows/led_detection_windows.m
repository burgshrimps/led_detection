% Timestamp synchronization of high framerate video with an EEG recording
% system
%
% Nico Alavi, 31. Dec 2018, <nico.alavi aT fu-berlin.de>
% Leibniz-Institute for Neurobiology, Magdeburg
% Department Functional Architecture of Memory
%
% For further information see 'README.md'.

clear

%% Set parameters for LED detection
filepath = input('Enter path to files: ');
FPS = input('Enter FPS: ');
start_time = input('Enter start time in s: ');
ROI_size = 40; % determines how big the rectangular shaped region of interest around the LED is
sensitivity = 0.985; % for imfindcircles(), higher numbers detect more circles
edgethreshold = 0.7; % for imfindcircles(), higher number detects fewer circles with weak edges
step_margin = 0.05; % tolerance for skipping frames regarding the difference between button and cam
radius_range = [9 12]; % for imfindcircles(), specifies how big the circles are 
radius_range_small = [7 9]; % for imfindcircles(), specifies how big the circles in second iteration are
pxval_thr = 200; % for brightness detection, threshold for pixel values
pxnum_thr = 12; % for brightness detection, number of pixels which have to reach that threshold

%% Open and read digialIO (from Axona) files
digitalIO_file = get_file(filepath, '*_digitalIO.txt');
comma2point_overwrite(digitalIO_file); % replace commas with dots
[dtime, dtype, dvalue] = textread(digitalIO_file, '%f %s %u', 'headerlines', 1, 'endofline', '\r\n'); % read data from file, skip 5 first lines since video recording starts after that

% value explanation:
% 4 -> frame captured
% 2 -> button pressed
% 6 (4+2) -> frame captured and button pressed at the same time
% 0 -> event stopped

% remove the event stopped (value == 0) entries since we only need to
% consider beginning of event (e.g. start recording frame)
dtype = dtype(dvalue == 'INPUT');
dtime = dtime(dvalue ~= 0);
dvalue = dvalue(dvalue ~= 0);

% get timestamps of when the button was pressed
button = get_button(dtime, dvalue);
num_button = length(button);
if ~isempty(button)
    disp('Successfully read button timestamps from .txt file!')
end

%% Open and read CVB timestamp file
cvb_file = get_file(filepath, '*_CVB_TS.txt');
cvb_fid = fopen(cvb_file);
cvb_raw = textscan(cvb_fid, '%s', 'Delimiter', '\n'); % cell containing unformatted CVB timestamps
cvb = get_cvb(cvb_raw); % vector with cvb timestamps in same format as axona timestamps
if ~isempty(cvb)
    disp('Successfully read cvb timestamps from .txt file!')
end

%% Open and read video from video file
video_file = get_file(filepath, '*.avi');
[out_path, out_name, out_ext] = fileparts(video_file); % for file output later
video = VideoReader(video_file);
i = start_time * FPS; % starting frame index
if ~isempty(video)
    disp('Successfully read video from file!')
end

%% Specify ROI (region of interest)
disp('Displaying preview...')
first_frame = read(video,i);
imshow(first_frame);
[LEDx,LEDy] = ginput(1); % get user input to specify location of LED
LEDx = round(LEDx); % round input coordinates
LEDy = round(LEDy);

ORIx = LEDx - ROI_size; % x coordinate of origin of ROI
ORIy = LEDy - ROI_size; % y coordinate of origin of ROI
width = ROI_size * 2; % width of ROI
height = ROI_size * 2; % heigth of ROI
rectangle('Position',[ORIx ORIy width height], 'EdgeColor', 'y'); % visualize ROI on screen
waitforbuttonpress;
close;

%% Video analysis
% create folder to store detected frames in, every time an LED light got
% detected the corresponding frame gets stored as an image to check for
% possible errors
detection_folder = strcat(filepath, '\DetectedFrames');
if exist(detection_folder, 'dir') ~= 7
    crtfolder = char(strcat('mkdir', {' '}, detection_folder));
    dos(crtfolder); 
end

% result vectors with detected frame index + timestamp
led_ts = zeros(1,num_button);
led_idx = zeros(1, num_button);

num_frames = video.NumberOfFrames;
event_counter = 1; % specifies number of found LEDs

disp('Processing video...');
while i <= num_frames
   frame_big = read(video,i); % read in current frame
   frame_crop_big = imcrop(frame_big, [ORIx ORIy width height]); % crop frame to ROI so less data has to be considered for the detection
   max_px_value = max(frame_crop_big); % find rows of pixels with values over threshold
   max_px_value = max_px_value(:,:,1); % image has 3 planes but since its a grayscale image they all are the same and we only have to look at one
   num_px_over_thr = length(find(max_px_value > pxval_thr)); % find number of pixels with value over brightness threshold
   if num_px_over_thr >= pxnum_thr
       [center_big, radius_big] = imfindcircles(frame_crop_big, radius_range, 'Sensitivity', sensitivity, 'ObjectPolarity', 'bright', 'EdgeThreshold', edgethreshold); % search for circular objects 
       if ~isempty(center_big)  
           frame_small = read(video, i-1);
           frame_crop_small = imcrop(frame_small, [ORIx ORIy width height]);
           % look for smaller circle in previous frame
           [center_small, radius_small] = imfindcircles(frame_crop_small, radius_range_small, 'Sensitivity', sensitivity, 'ObjectPolarity', 'bright', 'EdgeThreshold', edgethreshold); % search for circular objects
           if ~isempty(center_small)
               led_idx(event_counter) = i-1;
               led_ts(event_counter) = cvb(i-1);
               
               % position ROI new in case center of LED moved
               ORIx = ORIx + (center_small(1) - ROI_size);
               ORIy = ORIy + (center_small(2) - ROI_size);
               
               % Save detected frame for checking
               fig = figure('visible', 'off');
               img = imshow(frame_crop_small);
               viscircles(center_small,radius_small);
               print(strcat(detection_folder,'/detection_', num2str(event_counter)),'-dpng'); % save detected frames for checking
               close(fig);
           else
               led_idx(event_counter) = i;
               led_ts(event_counter) = cvb(i);
               
               % position ROI new in case center of LED moved
               ORIx = ORIx + (center_big(1) - ROI_size);
               ORIy = ORIy + (center_big(2) - ROI_size);
               
               % Save detected frame for checking
               fig = figure('visible', 'off');
               img = imshow(frame_crop_big);
               viscircles(center_big,radius_big);
               print(strcat(detection_folder,'/detection_', num2str(event_counter)),'-dpng'); % save detected frames for checking
               close(fig);
           end
           fprintf('Detected timestamp %i/%i \n', event_counter, num_button);
           
           % look at time difference between current LED and button to have 
           % an estimate about how much time difference will be between 
           % between the next LED and button
           differ = led_ts(event_counter) - button(event_counter); 

           % skip frames depending on diff and framerate
           event_counter = event_counter + 1; % describes number of LED event
           if event_counter <= num_button
                i = floor((button(event_counter)*FPS) + (differ - abs(differ*step_margin)) * FPS);
           else
               break;
           end
       else
           i = i + 1;
       end
   else
       i = i + 1;
   end
end

%% Save LED light frame indices and timestamps to textfile
line_num = 1:30;
led_idx_with_ts = [line_num; led_idx; led_ts];
fileID_led = fopen(strcat(filepath, '\', out_name(12:end),'_LED.txt'),'w');
fprintf(fileID_led, '%3s %8s %10s \r\n','#','Index', 'Timestamp');
fprintf(fileID_led,'%3d %8d %10.3f \r\n', led_idx_with_ts);
fclose(fileID_led);

disp('Successfully wrote detection timestamps to .txt file!')
