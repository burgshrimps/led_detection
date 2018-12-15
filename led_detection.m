clear;

%% Set parameters
filepath = input('Enter path to files: ');
FPS = input('Enter FPS: ');
start_time = input('Enter start time in s: ');
ROI_size = 40; % determines how big the rectangular shaped region of interest around the LED is
sensitivity = 0.985; % for imfindcircles(), higher numbers detect more circles
edgethreshold = 0.7; % for imfindcircles(), higher number detects fewer circles with weak edges
step_margin = 0.05; % tolerance for skipping frames regarding the difference between button and cam
radius_range = [9 12]; % for imfindcircles(), specifies how big the circles are 
pxval_thr = 200;
pxnum_thr = 12;

%% Open and read digialIO files
digitalIO_info = strcat(filepath,'/','*_digitalIO.txt'); % get frame timestamp.txt file in current directory
digitalIO_struct = dir(digitalIO_info);
digitalIO_name = digitalIO_struct.name;
digitalIO_file = strcat(filepath, '/', digitalIO_name);
%comma2point_overwrite(digitalIO_file); % replace commas with dots for better handling
[time, type, value] = textread(digitalIO_file, '%f %s %u', 'headerlines', 1, 'endofline', '\r\n'); % read data from file

% Get timestamps of button presses
key_ind = find(strcmp(type,'KEY')); % we only want tpye == INPUT
button_ind = union(find(value == 2), find(value == 6));
% button_ind = button_ind(button_ind ~= key_ind);
button_all = time(button_ind);

% Filter button timestamps since we only need the first frame in which it was
% pressed every time and digitalIO contains every frame the button remained
% pressed
button = filterbutton(button_all);
num_button = length(button(button ~= 0));

if ~isempty(button)
    disp('Successfully read button timestamps from .txt file!')
end


%% Open and read CVB timestamp files
cvb_info = strcat(filepath, '/', '*_CVB_TS.txt'); % get cvb timestamp .txt file in current directory
cvb_struct = dir(cvb_info);
cvb_name = cvb_struct.name;
cvb_file = strcat(filepath, '/', cvb_name);

cvb_fid = fopen(cvb_file);
cvb_raw = textscan(cvb_fid, '%s', 'Delimiter', '\n');

% Insert missing zeros
cvb_raw = cvb_raw{1}(:);
zeros_idx = find(cellfun(@(x) length(x), cvb_raw) < 23);
cvb_raw(zeros_idx) = cellfun(@(x) insert_zeros(x), cvb_raw(zeros_idx));

% Convert datetime timestamp to timestamp format of camera
start_ts = str2date(cvb_raw{1});
cvb = etime(str2date(cvb_raw(:)),start_ts);

% cvb = sort(cvb); % in case somewhere on the way order of timestamps getting mixed

if ~isempty(cvb)
    disp('Successfully read cvb timestamps from .txt file!')
end

%% Open and read video from .avi file
avi_info = strcat(filepath, '/', '*.avi');
avi_struct = dir(avi_info);
avi_name = avi_struct.name;
avi_file = strcat(filepath, '/', avi_name);
[out_path, out_name, out_ext] = fileparts(avi_file);

video = VideoReader(avi_file);
i = start_time * FPS;
if ~isempty(video)
    disp('Successfully read video from .avi file!')
end

%% Specify ROI
disp('Displaying preview...')
first_frame = read(video,i);
imshow(first_frame);
[LEDx,LEDy] = ginput(1); % get user input to specify location of LED
LEDx = round(LEDx); % round input coordinates
LEDy = round(LEDy);

ORIx = LEDx - ROI_size;
ORIy = LEDy - ROI_size;
width = ROI_size * 2;
height = ROI_size * 2;
rectangle('Position',[ORIx ORIy width height], 'EdgeColor', 'y');
waitforbuttonpress;
close;

%% Video analysis
% create folder to store detected frames in
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

tic % start timer

disp('Processing video...')
while i <= num_frames
   frame = read(video,i);
   frame_crop = imcrop(frame, [ORIx ORIy width height]);
   [center, radius] = imfindcircles(frame_crop, radius_range, 'Sensitivity', sensitivity, 'ObjectPolarity', 'bright', 'EdgeThreshold', edgethreshold);
   max_px_value = max(frame_crop);
   max_px_value = max_px_value(:,:,1);
   num_px_over_thr = length(find(max_px_value > pxval_thr));
   if num_px_over_thr >= pxnum_thr
       if ~isempty(center)
           video_timestamps(event_counter) = cvb(i);
           video_idx(event_counter) = i;
           diff = video_timestamps(event_counter) - button(event_counter);
           fprintf('Detected timestamp %i/%i \n', event_counter, num_button);

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

toc % end timer


%% Functions
function comma2point_overwrite(filespec)
    % Replaces all commas in a .txt file with dots
    file    = memmapfile(filespec, 'writable', true);
    comma   = uint8(',');
    point   = uint8('.');
    file.Data(transpose(file.Data==comma)) = point;
end 

function tvec = str2date(str)
    formatIn = 'yy/mm/dd HH:MM:SS.FFF';
    tvec = datevec(str, formatIn);
end

function button = filterbutton(button_all)
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
    str = char(str);
    new_str = strcat(str(1:20),'0',str(21:end));
    new_str = {new_str};
end