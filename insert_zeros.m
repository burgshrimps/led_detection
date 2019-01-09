function new_str = insert_zeros(str)
    % inserts zeros in timestamp string depending on how long the string is
    % @param str : timestamp string, e.g. 2018/09/04 12:48:24.16
    % @param new_str : corrected timestamp, e.g. 2018/09/04 12:48:24.016
    str = char(str);
    new_str = strcat(str(1:20),'0',str(21:end));
    new_str = {new_str};
end