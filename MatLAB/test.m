clc;
% Connect to serial port
comHandle = serial('com5', 'baudrate',115200, 'DataBits',8, 'Terminator','', 'Timeout', 2);
fopen(comHandle);

% send all values to FPGA
sendData(comHandle, 0, 1); % Amplitude
sendData(comHandle, 1, 50); % Frequency in Hz

% receive values and show them in console
readData(comHandle);

% close connection
fclose(comHandle);