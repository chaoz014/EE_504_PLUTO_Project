function seq = tx_gen_m_seq(m_init)
    % MSRG (Modular Tap Type) Structure
    
    connections = m_init;
    % number of stages of the shift register
    m=length(connections);
    % sequence length
    L=2^m-1;
    % register init
    registers=[zeros(1,m-1) 1];
    % The first sequence bit of the m sequence takes the value of the shift
    % output of the shift register
    seq(1)=registers(m);

    for i=2:L,
        % The first bit of the new register is equal to the connection value
        % multiplied by the last bit of the register
        new_reg_cont(1)=connections(1)*seq(i-1);
        for j=2:m,
            % The other bits are equal to the previous register value plus the 
                % connection value multiplied by the last bit of the register
            new_reg_cont(j)=rem(registers(j-1)+connections(j)*seq(i-1),2);
        end
        % After one cycle of register output, one bit is obtained to obtain the 
            % other bits of the m sequence
        registers=new_reg_cont;
        seq(i)=registers(m);
    end
end

