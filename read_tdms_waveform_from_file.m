file_path = 'NR_DL_FR2_100M_120k_256QAM.tdms';

% read tdms data from file
tdms_waveform = TDMS_readTDMSFile(file_path);
interleaved_iq = tdms_waveform.data{3};
channel_property_names = tdms_waveform.propNames{3};
channel_property_values = tdms_waveform.propValues{3};
clear tdms_waveform % free up some space

% compose complex waveform from interleaved iq
iq_real = interleaved_iq(1:2:end);
iq_imag = interleaved_iq(2:2:end);
complex_waveform.data = iq_real + 1i .* iq_imag;
clear interleaved_iq % free up some space

% scan and fill metadata
complex_waveform.burst_start_locations = 1;
complex_waveform.burst_stop_locations = length(complex_waveform.data);
for i = 1:length(channel_property_names)
    property_name = channel_property_names{i};
    property_value = channel_property_values{i};
    switch property_name
        case 'dt'
            complex_waveform.dt = property_value;
        case 'NI_RF_IQRate'
            complex_waveform.fs = property_value;
        case 'NI_RF_PAPR'
            complex_waveform.papr = property_value;
        case 'NI_RF_SignalBandwidth'
            complex_waveform.bandwidth = property_value;
        case {'NI_RF_Burst_Start_Locations', 'NI_RF_Burst_Stop_Locations'}
            burst_locations = strtrim(property_value);
            burst_locations = strsplit(burst_locations, '\t');
            if strcmp(property_name, 'NI_RF_Burst_Start_Locations')
                property_name = 'burst_start_locations';
            elseif strcmp(property_name, 'NI_RF_Burst_Stop_Locations')
                property_name = 'burst_stop_locations';
            end
            for j = 1:length(burst_locations)
                complex_waveform.(property_name)(j) = str2double(burst_locations{j}) + 1; % matlab indexes start at 1
            end
    end
end

% perform some sanity checks
fprintf('Waveform Length (s): %.3f\n', complex_waveform.dt * length(complex_waveform.data));
burst_mask = false(1, length(complex_waveform.data));
for i = 1:length(complex_waveform.burst_start_locations)
    burst_start_location = complex_waveform.burst_start_locations(i);
    burst_stop_location = complex_waveform.burst_stop_locations(i);
    burst_mask(burst_start_location:burst_stop_location) = true;
end
simulated_rms_power = 10 * log10(mean(...
    iq_real(burst_mask).^2 + iq_imag(burst_mask).^2)); 
fprintf('Reported Pavg (dBFS): %.3f\n', -complex_waveform.papr)
fprintf('Calculated Pavg (dBFS): %.3f\n', simulated_rms_power);

% finish off with some plotting
power_trace = 10 * log10(iq_real.^2 + iq_imag.^2); 
time = 0:complex_waveform.dt:complex_waveform.dt*(length(complex_waveform.data)-1);
plot(time, power_trace);
xlabel('Time (s)');
ylabel('Power (dBFS)');
