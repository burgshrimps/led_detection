function comma2point_overwrite(filespec)
    % replaces all commas in a .txt file with dots
    % @param filespec : filename including full path to file
    file    = memmapfile(filespec, 'writable', true);
    comma   = uint8(',');
    point   = uint8('.');
    file.Data(transpose(file.Data==comma)) = point;
end 