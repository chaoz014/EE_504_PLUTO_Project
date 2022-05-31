%% System Object Configuration
close all; clear all; clc;
format compact;
%{
    Pluto IP Configurations
    Cuh Fam: 192.168.2.1
%}

ip = '192.168.2.2';

% S IS THE SYSTEM CONFIGURATION I SUPPOSE FOR 'libiio' PROTOCOL
s = iio_sys_obj_matlab; % MATLAB libiio Constructor
s.ip_address = ip;
s.dev_name = 'ad9361';
s.in_ch_no = 2;
s.out_ch_no = 2;
s.in_ch_size = 42568;
s.out_ch_size = 42568*8;


s = s.setupImpl();

input = cell(1, s.in_ch_no + length(s.iio_dev_cfg.cfg_ch));
output = cell(1, s.out_ch_no + length(s.iio_dev_cfg.mon_ch));

set_freq = 700e6;
% Set the attributes of AD9361
input{s.getInChannel('RX_LO_FREQ')} = set_freq;
input{s.getInChannel('RX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('RX_RF_BANDWIDTH')} = 20e6;
input{s.getInChannel('RX1_GAIN_MODE')} = 'manual';%% slow_attack manual
input{s.getInChannel('RX1_GAIN')} = 10;
input{s.getInChannel('TX_LO_FREQ')} = set_freq;
input{s.getInChannel('TX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('TX_RF_BANDWIDTH')} = 20e6;

% input{s.getInChannel('RX2_GAIN_MODE')} = 'slow_attack';
% input{s.getInChannel('RX2_GAIN')} = 0;

%% Transmit and Receive using MATLAB libiio
% prompt = 'Input: ';
% stringToSend = input(prompt, 's');
% str = input(prompt,'s')
% stringToSend = 'Once a heroic Jedi Knight, Darth Vader was seduced by the dark side of the Force, became a Sith Lord, and led the Empire"s eradication of the Jedi Order. He remained in service of the Emperor -- the evil Darth Sidious -- for decades, enforcing his Master''s will and seeking to crush the fledgling Rebel Alliance. But there was still good in him ...';
% stringToSend = 'Fuck you bitch';
% stringToSend = 'Once a heroic Jedi Knight, Darth Vader was seduced by the dark side of the Force, became a Sith Lord, and led the Empire''s eradication of the Jedi Order. He remained in service of the Emperor -- the evil Darth Sidious -- for decades, enforcing his Master''s will and seeking to crush the fledgling Rebel Alliance. But there was still good in him ...';
% stringToSend = '01010101010101010101010101010101010101010101010101';
stringToSend = 'It was because of Kingston''s contribution to the drinkning process, that the team was able to complete the project.';
arrLength = ceil(length(stringToSend)/59);

sendArray = cell(1,arrLength);
seqNum = 0;

% ��֡
for index = 1:arrLength
    if index*59 > length(stringToSend)
        sendArray(index) = {[char(index),stringToSend(index*59-58:length(stringToSend))]};
    else
        sendArray(index) = {[char(index),stringToSend(index*59-58:index*59)]};
    end
end

% ����
% % for index = 1:arrLength
% %     txdata = bpsk_tx_func(sendArray{index});
% %     txdata = round(txdata .* 2^14);
% %     txdata = repmat(txdata, 8,1);
% %     input{1} = real(txdata);
% %     input{2} = imag(txdata);
% %     sendData(s, input);
% %     fprintf('send %d %s\n',index, sendArray{index});
% % end

isRecieved = 0;							% Currently not using this variable
recievedStr = '';
next_index = 1;                         % Indexing starts at 1 for matlab


% This is recieve portion of the transmitting process to move onto the next
% index
init_time = clock;
while(etime(clock, init_time)<300)
    output = recieveData(s);						% Data from Receiver
    I = output{1};
    Q = output{2};
    Rx = I+1i*Q;
    [receive_string, isRecieved] = bpsk_rx_func(Rx(end/2:end));

    if(~isRecieved)
        fprintf('Nothing Received.\nResending Previous Packet.\n')
        continue;
    else
        % Resend same packet
        if (receive_string(1, 1:3) == 'NAK')
            send_index = abs(receive_string(1,4));
            fprintf('recieve NAK %d\n',send_index);
            for index = send_index:arrLength
                txdata = bpsk_tx_func(sendArray{index});
                txdata = round(txdata .* 2^14);
                txdata=repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
                sendData(s, input);
            end

        else
            % Send next packet
    	    if (receive_string(1, 1:3) == 'ACK')
    		    send_index = abs(receive_string(1,4));			% This looks for the index
    		    fprintf('Recieved ACK', send_index)
    		    for index = send_index:arrLength
    			    txdata = bpsk_tx_func(sendArray{index});
    			    txdata = round(txdata .* 2^14);
    			    txdata=repmat(txdata, 8,1);
    			    input{1} = real(txdata);
    			    input{2} = imag(txdata);
    			    sendData(s, input);
                end
            end
        end
    end
end

fprintf('Transmission and reception finished\n');
fprintf('recievedData: %s\n', recievedStr);

% % Read the RSSI attributes of both channels
% rssi1 = output{s.getOutChannel('RX1_RSSI')};
% % % rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();


%{
	% New Things done:
		Added ACK for the test cases of received
		
%}