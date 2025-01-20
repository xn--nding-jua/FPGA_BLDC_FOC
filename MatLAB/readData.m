function readData(comHandle)
    try
        vector = fread(comHandle, 11, 'uint8');
    
        if (length(vector) == 11)
            if (vector(1) == 'A') && (vector(11) == 'E')
                omega = (bitshift(vector(2), 8) + vector(3)) / (2^5 * 2 * pi);
                disp(['Omega = ' num2str(omega) ' Hz']);
                disp(['FPGA BLDC FOC v' num2str(vector(8)/100)]);
    
                disp(['b4 = ' num2str(vector(4)) ' | b5 = ' num2str(vector(5)) ' | b6 = ' num2str(vector(6)) ' | b7 = ' num2str(vector(7))]);
            else
                disp('Wrong header!');
            end
        else
            disp('Received wrong length!');
        end
    catch ME
        disp(ME);
    end
