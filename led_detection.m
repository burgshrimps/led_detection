% Automatic detection of LED light in a video
%
% Nico Alavi, 26. Dec 2018, <nico.alavi aT fu-berlin.de>
% Leibniz-Institute for Neurobiology, Magdeburg
% Department Functional Architecture of Memory
%
% For further information see 'README.md'.

clear

%% Set parameters
filepath = input('Enter path to files: ');
FPS = input('Enter FPS: ');
start_time = input('Enter start time in s: ');
ROI_size = 40; % determines how big the rectangular shaped region of interest around the LED is
sensitivity = 0.985; % for imfindcircles(), higher numbers detect more circles
edgethreshold = 0.7; % for imfindcircles(), higher number detects fewer circles with weak edges
step_margin = 0.05; % tolerance for skipping frames regarding the difference between button and cam
radius_range = [9 12]; % for imfindcircles(), specifies how big the circles are 
pxval_thr = 200; % for brightness detection, threshold for pixel values
pxnum_thr = 12; % for brightness detection, number of pixels which have to reach that threshold

%% Open and read digialIO files
digitalIO_info = strcat(filepath,'/','*_digitalIO.txt'); % get frame timestamp.txt file in current directory
digitalIO_struct = dir(digitalIO_info);
digitalIO_name = digitalIO_struct.name;
digitalIO_file = strcat(filepath, '/', digitalIO_name);
comma2point_overwrite(digitalIO_file); % replace commas with dots for better handling
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

% Get timestamps of button presses
button_all = dtime(dvalue == 6);

% Filter button timestamps since we only need the first frame in which it was
% pressed every time and digitalIO contains every frame the button remained
% pressed
button = filterbutton(button_all);
num_button = length(button(button ~= 0));

if ~isempty(button)
    disp('Successfully read button timestamps from .txt file!')
end


%% Open and read CVB timestamp file
cvb_info = strcat(filepath, '/', '*_CVB_TS.txt'); % get cvb timestamp .txt file in current directory
cvb_struct = dir(cvb_info);
cvb_name = cvb_struct.name;
cvb_file = strcat(filepath, '/', cvb_name);
cvb_fid = fopen(cvb_file);
cvb_raw = textscan(cvb_fid, '%s', 'Delimiter', '\n');

% Insert missing zeros
cvb_raw = cvb_raw{1}(:); % cell formatting
zeros_idx = find(cellfun(@(x) length(x), cvb_raw) < 23); % find those lines which dont exceed a certain length (23). Those are the lines which are missing a zero on the tens decimal position
cvb_raw(zeros_idx) = cellfun(@(x) insert_zeros(x), cvb_raw(zeros_idx)); % correct the lines in question

% Convert datetime timestamp to timestamp format of axona (starting with zero increasing in seconds)
formatIn = 'yy/mm/dd HH:MM:SS.FFF';
start_ts = datevec(cvb_raw{1}, formatIn);
cvb = etime(datevec(cvb_raw(:), formatIn), start_ts);
cvb = sort(cvb);

if ~isempty(cvb)
    disp('Successfully read cvb timestamps from .txt file!')
end

%% Open and read video from video file
video_info = strcat(filepath, '/', '*.mp4');
video_struct = dir(video_info);
video_name = video_struct.name;
video_file = strcat(filepath, '/', video_name);
[out_path, out_name, out_ext] = fileparts(video_file);

video = VideoReader(video_file);
i = start_time * FPS;
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
detection_folder = strcat(out_path, '/DetectedFrames');
if exist(detection_folder, 'dir') ~= 7
    crtfolder = char(strcat('mkdir', {' '}, detection_folder));
    dos(crtfolder); 
end

% preallocate memory for better performance
video_timestamps = zeros(1,num_button);
video_idx = zeros(1, num_button);

num_frames = video.NumberOfFrames;
event_counter = 1;

disp('Processing video...')
while i <= num_frames
   frame = read(video,i); % read in current frame
   frame_crop = imcrop(frame, [ORIx ORIy width height]); % crop frame to ROI so less data has to be considered for the detection
   max_px_value = max(frame_crop); % find rows of pixels with values over threshold
   max_px_value = max_px_value(:,:,1); % image has 3 planes but since its a grayscale image they all are the same and we only have to look at one
   num_px_over_thr = length(find(max_px_value > pxval_thr)); % find number of pixels with value over brightness threshold
   if num_px_over_thr >= pxnum_thr
       [center, radius] = imfindcircles(frame_crop, radius_range, 'Sensitivity', sensitivity, 'ObjectPolarity', 'bright', 'EdgeThreshold', edgethreshold); % search for circular objects 
       if ~isempty(center)
           fprintf('Detected timestamp %i/%i \n', event_counter, num_button);
           % if bright circle (LED light) has been detected save
           % corresponding frame index and timestamp 
           video_timestamps(event_counter) = cvb(i);
           video_idx(event_counter) = i;
           
           % look at time difference between current LED and button to have 
           % an estimate about how much time difference will be between 
           % between the next LED and button
           diff = video_timestamps(event_counter) - button(event_counter); 

           % Save detected frame for checking
           fig = figure('visible', 'off');
           img = imshow(frame_crop);
           viscircles(center,radius);
           print(strcat(detection_folder,'/detection_', num2str(event_counter)),'-dpng'); % save detected frames for checking
           close(fig);

           % skip frames depending on diff and framerate
           event_counter = event_counter + 1; % describes number of LED event
           if event_counter <= num_button
                i = floor((button(event_counter)*FPS) + (diff - abs(diff*step_margin)) * FPS);

                % position ROI new in case center of LED moved
                ORIx = ORIx + (center(1) - ROI_size);
                ORIy = ORIy + (center(2) - ROI_size);
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

%% Save results to .txt files
out_name = out_name(12:end);

out_file_ts = strcat(out_path, '/', out_name, '_videoTS.txt');
fileID_ts = fopen(out_file_ts,'w');
fprintf(fileID_ts, '%10f, ', video_timestamps);
fclose(fileID_ts);

out_file_idx = strcat(out_path, '/', out_name, '_videoIDX.txt');
fileID_idx = fopen(out_file_idx,'w');
fprintf(fileID_idx, '%u, ', video_idx);
fclose(fileID_idx);

disp('Successfully wrote video timestamps and frame index to .txt files!')

%% Functions
function comma2point_overwrite(filespec)
    % Replaces all commas in a .txt file with dots
    file    = memmapfile(filespec, 'writable', true);
    comma   = uint8(',');
    point   = uint8('.');
    file.Data(transpose(file.Data==comma)) = point;
end 

function button = filterbutton(button_all)
    % filters list of button presses to only use the timestamp in which the
    % button was pressed first (there gotta be a 2s difference between the
    % button presses in order to be considered unique)
    button = zeros(1,30);
    button(1) = button_all(1);
    j = 2;
    for k = 2:length(button_all) 
        if abs(button(j-1) - button_all(k)) > 2
            button(j) = button_all(k);
            j = j + 1;
        end
    end
end

function new_str = insert_zeros(str)
    % inserts zeros in timestamp string depending on how long the string is
    str = char(str);
    new_str = strcat(str(1:20),'0',str(21:end));
    new_str = {new_str};
end