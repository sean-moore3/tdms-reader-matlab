complex_waveform.file_path = 'NR_DL_FR2_100M_120k_256QAM.tdms';

% read tdms data from file
tdms_waveform = TDMS_readTDMSFile(complex_waveform.file_path);
interleaved_iq = tdms_waveform.data{3};
channel_property_names = tdms_waveform.propNames{3};
channel_property_values = tdms_waveform.propValues{3};
clear tdms_waveform % free up some space

% compose complex waveform from interleaved iq
complex_waveform.real = interleaved_iq(1:2:end);
complex_waveform.imaginary = interleaved_iq(2:2:end);
complex_waveform.iq = complex_waveform.real + 1i .* complex_waveform.imaginary;
complex_waveform.sample_count = length(complex_waveform.iq);
clear interleaved_iq % free up some space

% scan and fill metadata
complex_waveform.burst_start_locations = 1;
complex_waveform.burst_stop_locations = complex_waveform.sample_count;
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
clear channel_property_names channel_property_values property_name property_value

% build burst mask
complex_waveform.burst_mask = false(1, complex_waveform.sample_count);
for i = 1:length(complex_waveform.burst_start_locations)
    burst_start_location = complex_waveform.burst_start_locations(i);
    burst_stop_location = complex_waveform.burst_stop_locations(i);
    complex_waveform.burst_mask(burst_start_location:burst_stop_location) = true;
end
clear burst_start_location burst_stop_location

% perform some sanity checks
fprintf('Waveform Length (s): %.3f\n', complex_waveform.dt * complex_waveform.sample_count);
simulated_rms_power = 10 * log10(mean(...
    complex_waveform.real(complex_waveform.burst_mask).^2 + ...
    complex_waveform.imaginary(complex_waveform.burst_mask).^2)); 
fprintf('Reported Pavg (dBFS): %.3f\n', -complex_waveform.papr)
fprintf('Calculated Pavg (dBFS): %.3f\n', simulated_rms_power);

% finish off with some additional traces
power_trace = 10 * log10(complex_waveform.real.^2 + complex_waveform.imaginary.^2); 
% time = 0:complex_waveform.dt:complex_waveform.dt*(complex_waveform.sample_count-1);
% plot(time, power_trace);
% xlabel('Time (s)');
% ylabel('Power (dBFS)');

% save the waveform to a .mat file
clear i
[~, file_name] = fileparts(complex_waveform.file_path);
save(file_name)