function fname = get_file(filepath, file_ext)
    % gets specific files in current directory
    % @param filepath : complete path to file as string
    % @param file_ext : ending of filename which specifies file
    % @return fname : full path inclusive name to file with specific ending
    file_struct = dir(strcat(filepath, '\', file_ext));
    fname = strcat(filepath, '\', file_struct.name);
end