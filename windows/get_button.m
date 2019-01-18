function button = get_button(dtime, dvalue)
    % filters list of button presses to only use the timestamp in which the
    % button was pressed first (there gotta be a 2s difference between the
    % button presses in order to be considered unique)
    % @param dtime : vector of all timestamps from the digitalIO file
    % @param dvalue : vector of all values from the digitalIO file
    % @return button : vector of timestamps where the button was pressed 
    button_all = dtime(dvalue == 6);
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