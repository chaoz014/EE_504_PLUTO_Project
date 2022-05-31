
%% System Object Configuration
close all; clear all; clc

    %{ 
            MAKE SURE YOU CHECK YOUR PLUTO'S IP ADDRESS IN THE CONFIG FILE
            AND CHANGE IT ACCORDINGLY.
    %}

ip = '192.168.2.2';         % PLUTO's default ip address

% System Object Configuration
s = iio_sys_obj_matlab;     % MATLAB libiio Constructor
s.ip_address = ip;          % define the ip address of the PLUTO
s.dev_name = 'ad9361';      % name the device to the PLUTO's chip
s.in_ch_no = 2;             % number of input channels
s.out_ch_no = 2;            % number of output channels
s.in_ch_size = 42568;       % input data channel size [samples]
s.out_ch_size = 42568*8;    % output data channel size [samples]

s = s.setupImpl();  % initialize PLUTO Rx and Tx object
%{
    - Initializes nnumeric and string with parameters specified above
%}

% initialize cell array objects for input and output of size 1 by the 
% number of input channels + the length of the configuration channel list
input = cell(1, s.in_ch_no + length(s.iio_dev_cfg.cfg_ch));
output = cell(1, s.out_ch_no + length(s.iio_dev_cfg.mon_ch));

% Set the attributes for the PLUTO
input{s.getInChannel('RX_LO_FREQ')} = 998e6;
input{s.getInChannel('RX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('RX_RF_BANDWIDTH')} = 20e6;
input{s.getInChannel('RX1_GAIN_MODE')} = 'manual';%% slow_attack manual
input{s.getInChannel('RX1_GAIN')} = 10;
% input{s.getInChannel('RX2_GAIN_MODE')} = 'slow_attack';
% input{s.getInChannel('RX2_GAIN')} = 0;
input{s.getInChannel('TX_LO_FREQ')} = 998e6;
input{s.getInChannel('TX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('TX_RF_BANDWIDTH')} = 20e6;

%% Transmit and Receive using MATLAB libiio

% BB-8 Description
stringToSend = ['A skittish but loyal astromech, BB-8 accompanied Poe Dameron' ...
    ' on many missions for the Resistance, helping to keep his X-wing in working order.' ...
    ' When Poe''s mission to Jakku ended with his capture by the First Order, BB-8 fled into' ...
    ' the desert with a vital clue to the location of Luke Skywalker.' ...
    ' He rejoined Poe in time for the attack on Starkiller Base, then helped' ...
    ' Rey locate Skywalker''s planet of exile. As the Resistance rebuilt its' ...
    ' forces after the Battle of Crait, BB-8 helped both Poe and Rey.'];


% Darth Vader Description
% stringToSend = ['Once a heroic Jedi Knight, Darth Vader was seduced by the ' ...
%     'dark side of the Force, became a Sith Lord, and led the Empire''s eradication' ...
%     ' of the Jedi Order. He remained in service of the Emperor -- ' ...
%     'the evil Darth Sidious -- for decades, enforcing his Master''s will and ' ...
%     'seeking to crush the fledgling Rebel Alliance. But there was still good in him ...'];


% Random String
% stringToSend = 'Dunton is the best professor. I love beta!';

% determine the number of packets to be sent
arrLength = ceil(length(stringToSend)/57);
% create cell object with arrLength packets
sendArray = cell(1,arrLength);
% initialize packet sequence number
seqNum = 0;

% break down message into packets of 57 characters concatenated with a
% sequence number for packet accuracy check
for index = 1:arrLength
    % encode next sequence number
    seqNumStr = ['00', int2str(seqNum)];
    if seqNum == 0 
        seqNum = 1;
    else 
        seqNum = 0;
    end
    if index*57 > length(stringToSend)
        % concatenate the sequence number with the last characters of the
        % message to be sent and store in packets cell object
        sendArray(index) = {[seqNumStr,stringToSend(index*57-56:length(stringToSend))]};
    else
        % DEFAULT: concatenate the next 57 sequence number with the next set of message
        % to be sent and store in packets cell object
        sendArray(index) = {[seqNumStr,stringToSend(index*57-56:index*57)]};
    end
end

% Rx variables init
index = 1;
isRecieved = 0;
% Sequence number switches between 0 and 1 only
RxcurrentSeq = '0';
% received string init
receivedStr = '';

% while index is less than the number of packets
while(index <= arrLength)
    % get next struct to be sent
    TcurrentSeq = sendArray{index}(3);
    % print message to screen to signal tx
    fprintf('Transmitting Data Block %s ...\n',TcurrentSeq);

    % modulate data to be sent
    txdata = bpsk_tx_func(sendArray{index}); 
    % round data to be sent to 16384 characters
    txdata = round(txdata .* 2^14);
    % store data in an 8 x 1 array
    txdata = repmat(txdata, 8,1);
    % break down sata into I and Q components
    input{1} = real(txdata);
    input{2} = imag(txdata);
    % transmit I and Q waves
    sendData(s, input);
    

    % Receiving side

    % begin a timer from the last sent signal
    sendTime = clock;
    while (etime(clock, sendTime) < 10)
        % Rx data
        output = recieveData(s);
        % separate data into a I and Q components
        I = output{1};
        Q = output{2};
        % compbine data to make complex array
        Rx = I+1i*Q;
        % demodulate data
        [rStr, isRecieved] = bpsk_rx_func(Rx(end/2:end));

        % Rx unsuccessful
        if (~isRecieved)
           continue;
        % Rx successful
        else
            % Repeated message received
            if (rStr(1, 1:3) == 'ACK')
                if (rStr(1, 4) == TcurrentSeq)
                    fprintf('Data Block %s ACKed...\n',TcurrentSeq);
                    % increment counter so next packet can be received
                    index = index + 1;
                    % break to send Ack and next index number
                    break;
                end
            % New packet received
            else
                if (rStr(1, 3) == RxcurrentSeq)
                    fprintf('Data Block %s Received...\n',RxcurrentSeq);
                    % message is longer than 16 characters
                    if (length(rStr) == 16)
                        temp = [rStr(1, 4:16), rStr(2,:), rStr(3,:), rStr(4,:)];
                        recievedData = temp(1:find(ismember(temp, char(0)), 1 ) - 1);
                    % message id less than 16 characters
                    else
                        recievedData = rStr(1, 4:length(rStr));
                    end
                    % print received block
                    fprintf('recievedData: %s\n', recievedData);

                    % add new packet to total received string
                    
                    receivedStr = [receivedStr, recievedData];
                    if (RxcurrentSeq == '0')
                        RxcurrentSeq = '1';
                    else
                        RxcurrentSeq = '0';
                    end
                end
                % modulate ack'd and packet to be sent
                txdata = bpsk_tx_func(['ACK', rStr(1, 3)]);
                % round data to 16384
                txdata = round(txdata .* 2^14);
                % break down data into an 8x1 array
                txdata=repmat(txdata, 8,1);
                % separate I and Q waveforms
                input{1} = real(txdata);
                input{2} = imag(txdata);
                fprintf('Transmitting ACK...\n');
                % Transmit Rx ACK or NAK
                sendData(s, input);
                % clear outout struct for next Rx cycle
                output = {};
            end
        end
    end
end
fprintf('Transmission and reception finished\n');
fprintf('received Data: %s\n', receivedStr);

s.releaseImpl();
