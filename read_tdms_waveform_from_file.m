clear

% user variables
waveform_file_path = 'C:\Users\semoore\Downloads\stream02.tdms';
% waveform_file_path = 'C:\Users\semoore\Downloads\stream03.tdms';
subset_offset = 0; % offset from start of the waveform in seconds
subset_length = -1; % length of waveform to load in seconds, -1 is all
default_iq_rate = 125e6; % sample rate to use if one isn't found in the tdms file
scale_subset = true; % if true, scales the subset to have peak power of 0dB

% scan and fill metadata
tdms = TDMS_readTDMSFile(waveform_file_path, 'GET_DATA_OPTION', 'getnone');
channel_property_names = tdms.propNames{3};
channel_property_values = tdms.propValues{3};
waveform_sample_count = tdms.numberDataPointsRaw(3) / 2; % interleaved iq
waveform_burst_start_locations = 1;
waveform_burst_stop_locations = waveform_sample_count;
for i = 1:length(channel_property_names)
    property_name = channel_property_names{i};
    property_value = channel_property_values{i};
    switch property_name
        case 't0'
            waveform_t0 = property_value;
        case 'dt'
            waveform_dt = property_value;
        case 'NI_RF_IQRate'
            waveform_fs = property_value;
        case 'NI_RF_PAPR'
            waveform_papr = property_value;
        case 'NI_RF_SignalBandwidth'
            waveform_bandwidth = property_value;
        case {'NI_RF_Burst_Start_Locations', 'NI_RF_Burst_Stop_Locations'}
            burst_locations = strtrim(property_value);
            burst_locations = strsplit(burst_locations, '\t');
            if strcmp(property_name, 'NI_RF_Burst_Start_Locations')
                property_name = 'waveform_burst_start_locations';
            elseif strcmp(property_name, 'NI_RF_Burst_Stop_Locations')
                property_name = 'waveform_burst_stop_locations';
            end
            for j = 1:length(burst_locations)
                eval([property_name, '(j) = ', burst_locations{j}, ' + 1;']); % matlab indexes start at 1
            end
            clear burst_locations j
    end
end
clear channel_property_names channel_property_values property_name property_value

% fill sample rate with default value if not found in metadata
if ~exist('waveform_fs', 'var')
    if exist('waveform_dt', 'var')
        waveform_fs = 1 / waveform_dt;
    else
        waveform_fs = default_iq_rate;
    end
end
if ~exist('waveform_dt', 'var')
    waveform_dt = 1 / waveform_fs;
end

waveform_length = waveform_dt * waveform_sample_count;

% read waveform subset
subset_start_sample = round(subset_offset * waveform_fs) + 1;
if subset_length < 0
    subset_stop_sample = waveform_sample_count;
else
    subset_stop_sample = subset_start_sample + ...
        round(subset_length * waveform_fs) - 1;
end
tdms = TDMS_readTDMSFile(waveform_file_path, ...
    'SUBSET_GET', ...
    [subset_start_sample * 2 - 1, subset_stop_sample * 2], ...
    'SUBSET_IS_LENGTH', false);
interleaved_iq = tdms.data{3};
clear tdms % free up some space

% build burst mask
waveform_burst_mask = false(1, waveform_sample_count);
for i = 1:length(waveform_burst_start_locations)
    waveform_burst_mask(waveform_burst_start_locations(i): ...
        waveform_burst_stop_locations(i)) = true;
end
subset_burst_mask = waveform_burst_mask(subset_start_sample:subset_stop_sample);
clear i waveform_burst_mask

% compose subset waveform from interleaved iq
subset_real = single(interleaved_iq(1:2:end));
subset_imaginary = single(interleaved_iq(2:2:end));
subset_y = subset_real + 1j * subset_imaginary;
subset_sample_count = length(subset_real);
subset_length = subset_sample_count * waveform_dt;
clear interleaved_iq % free up some space

% scale subset
if scale_subset
    subset_y = subset_y / max(subset_y);
    subset_real = real(subset_y);
    subset_imaginary = imag(subset_y);
end

% save the waveform to a .mat file
[~, file_name] = fileparts(waveform_file_path);
disp('Saving waveform to .mat file. This could take a while.')
save(file_name, '-v7.3')

% print some statistics
fprintf('Waveform Length (s): %.3f\n', waveform_length);
fprintf('Subset Length (s): %.3f\n', subset_length);
if exist('waveform_papr', 'var')
    simulated_rms_power = 10 * log10(mean(...
        subset_real(subset_burst_mask).^2 + ...
        subset_imaginary(subset_burst_mask).^2)); 
    fprintf('Reported Waveform Pavg (dBFS): %.3f\n', -waveform_papr)
    fprintf('Calculated Subset Pavg (dBFS): %.3f\n', simulated_rms_power);
end

% finish off with some additional traces
power_trace = 10 * log10(subset_real.^2 + subset_imaginary.^2); 
time = subset_offset:waveform_dt:subset_offset + waveform_dt * (subset_sample_count - 1);
plot(time, power_trace);
xlabel('Time (s)');
ylabel('Power (dBFS)');
