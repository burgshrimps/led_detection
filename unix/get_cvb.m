function cvb = get_cvb(cvb_raw)
    % filters and formats raw cvb cell 
    % @param cvb_raw : unformatted cell containing timestamp strings
    % @return cvb : vector of formatted CVB timestamps
    
    % Insert missing zeros
    cvb_raw = cvb_raw{1}(:); % cell formatting
    zeros_idx = find(cellfun(@(x) length(x), cvb_raw) < 23); % find those lines which dont exceed a certain length (23). Those are the lines which are missing a zero on the tens decimal position
    cvb_raw(zeros_idx) = cellfun(@(x) insert_zeros(x), cvb_raw(zeros_idx)); % correct the lines in question
    
    % Convert datetime timestamp to timestamp format of axona (starting with zero increasing in seconds)
    formatIn = 'yy/mm/dd HH:MM:SS.FFF';
    start_ts = datevec(cvb_raw{1}, formatIn);
    cvb = etime(datevec(cvb_raw(:), formatIn), start_ts);
    cvb = sort(cvb);
end