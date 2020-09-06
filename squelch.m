da = abs(loadFile('adsb_3_2M_3.dat'));
%da = da((1:1e7)); %Just take a small amount of the data to start

d = resample(da,5,4);
%{
%Preamble matched filter
Preamble = [1,0,1,0,0,0,0,1,0,1,0,0,0,0,0,0];
Preamble = Preamble.';
%squelch
w = conv(d, Preamble); %128 us is the length of a packet
w = w(1:length(d)); %truncate it to length of d
idx = w > 10; %threshold
%}

w = conv(d, ones(1,128)); %Ones filter
w = w(1:length(d));
idx = w > 200;

plot(d);
hold on
plot(w);
plot(idx);
legend('Input Data','Filter', 'Threshold');
title('Convolution Filter with signal and threshold (preamble)');
zoom on
hold off

%Find start and end of where we break squelch
num_packets = 0;
packet_starts = {};
for ii = 1:length(d)
    if idx(ii) == 0
        continue;
    end
    
    if idx(ii) == 1
        if (ii ~= 1) && ( idx(ii - 1) == 0 )
            num_packets = num_packets + 1;
            packet_starts{num_packets} = ii;
        else
            continue
        end
    end
end

%break into packets
packets = {};
for ii = 1:length(packet_starts)
    if packet_starts{ii} < 128
        pstart = 1;
    else
        pstart = packet_starts{ii} - 128;
    end
    if packet_starts{ii} > length(d) - 480
        pend = length(d);
    else
        pend = packet_starts{ii} + 480;
    end
    packets{ii} = d(pstart:pend);
end

for ii = 1:length(packets)
    p = packets{ii};
    %threshold each packet
    thresh = mean(p)*1.1;
    p = p > thresh;
    
    %cut-off all blank space at start
    p = p( find(p,1):end );
    
    %m = 2*mask(1:length(p))-1;
    
    packets{ii} = p;
end


%{
%Attempt to sequentially decode all bits; you have enough packets to only
care about the first entries
packet_trash = []
packet1 = packets{1,1};
packet1 = packet1(32:end);
packet_trash = packet1(240:end);
packet1 = packet1(1:2:240)
packet_vector = [packet_vector, packet1];
while length(packet_trash) >= 56;
    packet_trash = packet1(113:end);
    packet1 = packet1(1:112);
    packet_array = [packet_array, packet1(32:end)];
end

%}


ICAO = [];
TC = [0 0 1 0 0];
DATA = [];
decode_vector = [];
sample_byte = [];
test_array = [];

test_packet = packets{1,1}
test_packet = test_packet(1:2:end).'

for i = 1:length(packet_starts)
    packet1 = packets{1,i};
    packet1 = packet1(33:4:end).';
    
    
    %at this point packet1 should be the completed DF packet
    if packet1(1:5) == [1 0 0 0 1] %check for DF-17
        ICAO = [ICAO; binaryVectorToHex(packet1(9:32))];
        if packet1(33:37) == TC
          DATA = [DATA; decode_id(packet1)];
        end
    end
end
