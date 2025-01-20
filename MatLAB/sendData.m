function sendData(comHandle, command, value)
    temp = int32(floor(value * 2^16));
    
    % prepare data
    vector(1) = uint8(char('A'));
    
    vector(2) = uint8(command); % index for amplitude
    vector(3) = uint8(bitand(bitshift(temp,-24), 255));
    vector(4) = uint8(bitand(bitshift(temp,-16), 255));
    vector(5) = uint8(bitand(bitshift(temp,-8), 255));
    vector(6) = uint8(bitand(temp, 255));
    vector(7) = uint8(0);
    vector(8) = uint8(0);
    
    PayloadSum = vector(3) + vector(4) + vector(5) + vector(6) + vector(7) + vector(8);
    vector(9) = uint8(bitand(bitshift(PayloadSum,-8), 255));
    vector(10) = uint8(bitand(PayloadSum, 255));
    
    vector(11) = uint8(char('E'));
    
    fwrite(comHandle, vector, 'uint8');
    flushoutput(comHandle);
