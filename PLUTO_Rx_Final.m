%% System Object Configuration
close all; clear all; clc;
format compact;

%{
    Pluto IP Configurations
    Cuh Fam: 192.168.2.1
%}
ip = '192.168.2.2';

s = iio_sys_obj_matlab; % MATLAB libiio Constructor
s.ip_address = ip;
s.dev_name = 'ad9361';
s.in_ch_no = 2;
s.out_ch_no = 2;
s.in_ch_size = 42568;
s.out_ch_size = 42568*8;

% initialize PLUTO Rx and Tx object with above parameters
s = s.setupImpl();

% initialize cell array objects for input and output of size 1 by the 
% number of input channels + the length of the configuration channel list
input = cell(1, s.in_ch_no + length(s.iio_dev_cfg.cfg_ch));
output = cell(1, s.out_ch_no + length(s.iio_dev_cfg.mon_ch));
freq = 700e6;
% Set the attributes of the PLUTO
input{s.getInChannel('RX_LO_FREQ')} =freq;
input{s.getInChannel('RX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('RX_RF_BANDWIDTH')} = 20e6;
input{s.getInChannel('RX1_GAIN_MODE')} = 'manual'; % manual slow-attack
input{s.getInChannel('RX1_GAIN')} = 10;
input{s.getInChannel('TX_LO_FREQ')} = freq;
input{s.getInChannel('TX_SAMPLING_FREQ')} = 40e6;
input{s.getInChannel('TX_RF_BANDWIDTH')} = 20e6;


%% Receive using MATLAB libiio
% 
% % stringToSend = 'Once a heroic Jedi Knight, Darth Vader was seduced by the dark side of the Force, became a Sith Lord, and led the Empire"s eradication of the Jedi Order. He remained in service of the Emperor -- the evil Darth Sidious -- for decades, enforcing his Master''s will and seeking to crush the fledgling Rebel Alliance. But there was still good in him ...';
% stringToSend = '~test';
% % stringToSend = '01010101010101010101010101010101010101010101010101';
% 
% 
% % determine the number of packets to be sent in arrLength
% arrLength = ceil(length(stringToSend)/59);
% % create cell object with arrLength packets
% sendArray = cell(1,arrLength);
% initialize packet sequence number
seqNum = 0;

isRecieved = 0;
recievedStr = ' ';
next_index = 1;
% recievedStr = 0;
init_time = clock;

while(etime(clock, init_time)<15)
    % Signal intercepted message with packet number o/p
%     fprintf('receiving %d ...\n',next_index);

    % save I and Q data from the Rx side
    sendTime = clock;
    while (etime(clock, sendTime) < 10)
        % output is Rx data broken d
        % own into two packets (I and Q)
        output = recieveData(s);
        I = output{1};
%         Q = output{2};
%         tm = linspace(0,1,length(I));
%         plot(tm, abs(I));
		
        % combine data packets to form complex waveform
        Rx = I+1i*Q;
        % demodulate data
            %{ 
                IF: isReceived = 1. Rx is successfull
                    isReceived = 0. Rx is unssuccesful              
            %}
        [receive_string, isRecieved] = bpsk_rx_func(Rx(end/2:end));						% Demodulate the data received
        
		% receive_string package: 1 index region 2 character received
		
%         receive_string = receive_string(2:end);
        % no Rx interception message o/p
        if (~isRecieved)
%             fprintf('recieve nothing at all\n');
            % Transmit NAK in case of unsucessfull Rx
            txdata = bpsk_tx_func(['NAK',char(next_index)]);
            txdata = round(txdata .* 2^14);
            txdata = repmat(txdata, 8,1);
            input{1} = real(txdata);
            input{2} = imag(txdata);
%             fprintf('send NAK %d\n',next_index);
            sendData(s, input);
           continue;
		   
		   
        else
        % Rx successful         
            if (abs(receive_string(1, 1)) == next_index)									% Check if the right index 
				% Check if this is the tilda

	
				
                
%                 fprintf('recieve : %s \n', receive_string(1,2:length(receive_string)));
				next_index = next_index + 1;									% This is acknoledgement that it is successfully recieved and moving onto the next letter
                txdata = bpsk_tx_func(['ACK',char(next_index)]);				% prepare package to send ACK and Index 
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
%                 fprintf('send ACK %d\n',next_index);							% HERE IS THE ACK THAT IS SENT
                sendData(s, input);
                temp_rx = [receive_string(1, 2:length(receive_string)), receive_string(2, 1:length(receive_string)), ...
                                receive_string(3, 1:length(receive_string)), receive_string(4, 1:length(receive_string))];
                recievedStr = [recievedStr, temp_rx];


                break;
			        															% DONT KNOW IF WE SHOULD ADD END FOR FORMALITY
			
            else
%                 fprintf('recieve is : %s \n', receive_string(1,2:length(receive_string)));
%                 fprintf('recieve nothing %d %c\n', abs(receive_string(1, 1)),receive_string(1, 1));
                % Transmit NAK in case of unsucessfull Rx
                txdata = bpsk_tx_func(['ACK',char(next_index)]);
                txdata = round(txdata .* 2^14);
                txdata = repmat(txdata, 8,1);
                input{1} = real(txdata);
                input{2} = imag(txdata);
%                 fprintf('send NAK %d\n',next_index);
                sendData(s, input);
                continue;
            
            end
			
		% End of else statement for succesful transmission of data
        end	
	% End of while loop of recieving data 
    end
% Check if done or not
%     check = ismember('\done',receive_string)
%     for i = 1: length(check)
%         if 
%     end

% End of window time of reciving data from trasmission

end

% Transmission successful and message display
fprintf('Transmission and reception finished\n');
fprintf('recievedData: %s\n', recievedStr);

% Read the RSSI attributes of both channels
rssi1 = output{s.getOutChannel('RX1_RSSI')};
% rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();


%{
	Functions used:
		etime: elapsed time
	
	
	Things to ask Juan
	When there is an ACK it moves onto the next index but still sends a NAK. Since the index is preshifted does it send that data with it and sends through the next
		bit package?
		
	If so then there will always be a nak.
	Implement a done sequence probably with a literal /done or something
	
	There is no ACK test function. Is this because it worked so dont fix it (Sending version of the code)
		is this why we are always sending a nak because there is no ack portion of the code?
	
	
	CHANGED:
		changed the always send NACK to send an ACK
		
	Note:
		Think of a stop bit


concatenate the whole string

		
%}