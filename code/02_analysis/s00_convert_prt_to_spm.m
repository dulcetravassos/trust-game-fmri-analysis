%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   PROTOCOL CONVERTER: BRAINVOYAGER (.prt) -> SPM (.mat)                %
%                                                                        %
%   The function prt_to_spm(), using the function read_prt(), reads      %
%   multiple .prt files from a selected folder, confirms the resolution  %
%   of time (converting msec to sec), skips empty conditions (meaning 0  % 
%   trials), detects time start of an event and calculates its duration  % 
%   and, lastly, saves a .mat file with a BIDS compliant name.           %
%   Additionally, includes subject filtering (processes only the defined %
%   subjects) and supports the face localizer's universal protocol.      %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 05/01/2026                                                  %
%   Last update: 04/05/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc; 

%% Initial Configurations
% Change according to your preferences
% NOTE - some configurations may have to be changed in the read_prt function (for example, the conversion factor, currently for msec -> sec)

% Input folder - main task (congruent & incongruent trials)
folder_prt_congruent = 'C:\Users\User\Desktop\Tese\data\spm-data\sourcedata\protocols\task-main\version2_exclude4NrMatch\prts-runs-task-tg-cong';
folder_prt_incongruent = 'C:\Users\User\Desktop\Tese\data\spm-data\sourcedata\protocols\task-main\version2_exclude4NrMatch\prts-runs-task-tg-incong';

% Input file - face localizer (universal protocol)
folder_prt_localizer = 'C:\Users\User\Desktop\Tese\data\spm-data\sourcedata\protocols\task-localizer';
localizer_prt_file = dir(fullfile(folder_prt_localizer,'*.prt'));

% Output folder: /derivatives (BIDS)
folder_out = 'C:\Users\User\Desktop\Tese\data\spm-data\derivatives\spm-events';

% What is going to be converted (1 for yes, 0 for no)
do_congruent = 1;
do_incongruent = 1;
do_localizer = 1;

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% Protocol conversion: .prt -> .mat

% Create output folder if it doesn't exist
if ~exist(folder_out,'dir'); mkdir(folder_out); end

if do_congruent
    disp('Initiating protocol conversion - CONGRUENT task...');
    prt_to_spm(folder_prt_congruent,folder_out,subjects,'congruent');
    disp('Congruent conversion concluded.');
end

if do_incongruent
    disp('Initiating protocol conversion - INCONGRUENT task...');
    prt_to_spm(folder_prt_incongruent,folder_out,subjects,'incongruent');
    disp('Incongruent conversion concluded.');
end

if do_localizer
    disp('Initiating protocol conversion - FACE LOCALIZER task...');
    if isempty(localizer_prt_file)
        fprintf('[ERROR] No .prt file found for the Localizer in %s\n',folder_prt_localizer);
    else
        loc_path = fullfile(folder_prt_localizer,localizer_prt_file(1).name);
        [names, onsets, durations] = read_prt(loc_path);
        if isempty(names)
            fprintf('[WARNING] Localizer protocol is empty.\n');
        else
            for s = 1:length(subjects)
                subj = subjects{s};
                subj_folder = fullfile(folder_out,subj,'func');
                if ~exist(subj_folder,'dir'); mkdir(subj_folder); end;

                % BIDS name generation: sub-XXX_task-localizer_run-01_events.mat
                output_filename = fullfile(subj_folder,sprintf('%s_task-localizer_run-01_events.mat',subj));
                save(output_filename,'names','onsets','durations');
                fprintf("Saved -> %s/%s_events.mat\n",subj,subj);
            end
            disp('Localizer conversion concluded.');
        end
    end
end

disp('ALL JOBS FINISHED.');

%% Helper Functions
% Useful to maintain the code atomic (no need to repeat lines of code)

function prt_to_spm(folder_prt,folder_out,subjects_list,task_type)

if ~exist(folder_prt,'dir')
    fprintf('[ERROR] Folder not found: %s\n', folder_prt);
    return; 
end

files = dir(fullfile(folder_prt,'*.prt')); % select .prt files only
fprintf("\n=================================================\n");
fprintf("TASK %s\n", upper(task_type));
fprintf("=================================================\n");

for i = 1:length(files)
    file_name = files(i).name;
    full_path = fullfile(folder_prt, file_name);
    [~, base_name, ~] = fileparts(file_name); % we only want the name of the file
    
    % Name correction: subject names in origin files do not follow BIDS (sub-x)
    regex_pattern = 'sub-tg(\d+)'; % regex = Regular Expression; (\d+) detects numbers
    tokens = regexp(base_name,regex_pattern,'tokens'); % tokens match parts of the regex expression

    if isempty(tokens)
        % localizer's protocol has no "sub-"
        process_file = true;
        bids_sub = '';
    else
        num_str = tokens{1}{1}; % Extracts the number string
        num_val = str2double(num_str);
        
        bids_sub = sprintf('sub-%03d',num_val); % we want 3 digits (sub-002, sub-023, for example)
        
        if ismember(bids_sub,subjects_list)
            process_file = true;
        else
            process_file = false; % skip subject
        end
    end

    if process_file
        fprintf("Processing: %s ... ", file_name);
        try
            [names, onsets, durations] = read_prt(full_path);
            
            % If there are no valid conditions (or file is empty)
            if isempty(names)
                fprintf("[WARNING] No valid condition found in this file.\n");
                continue; % skips to next file
            end  
            
            if ~isempty(bids_sub)
                % Output Folder: derivatives/spm-events/sub-0xx/func/
                subj_folder = fullfile(folder_out, bids_sub, 'func');
                if ~exist(subj_folder, 'dir'); mkdir(subj_folder); end
               
                % Search for run number in the protocol file name (differs between cong and incong files)
                run_tokens = regexp(base_name,'run(\d+)','tokens');

                if ~isempty(run_tokens)
                    run_val = str2double(run_tokens{1}{1});
                    bids_run = sprintf('run-%02d',run_val); % run-01, run-02, etc.
                    new_base_name = sprintf('%s_task-main_%s',bids_sub,bids_run); % 'sub-00x_task-main_run-0y'
                else 
                    % security fallback
                    new_base_name = sprintf('%s_task-main',bids_sub);
                end
                
                output_filename = fullfile(subj_folder, sprintf('%s_events.mat',new_base_name));
                save(output_filename,'names','onsets','durations');
                fprintf("Saved -> %s/%s_events.mat\n", bids_sub, new_base_name);  
            else
                % Non-BIDS output
                fprintf("[WARNING] Filename does not match 'sub-tgXX' pattern. Skipping BIDS renaming.\n");
                output_filename = fullfile(folder_out, sprintf('%s_events.mat',base_name)); % Saves file in the root
                save(output_filename, 'names', 'onsets', 'durations');
            end
            
        catch ME
            fprintf('[ERROR] %s\n', ME.message);
        end
    end
end
fprintf("=================================================\n All files analysed. Finished.\n");
end


% (Helper) This function is used in the function above
function [names, onsets, durations] = read_prt(filepath)
fid = fopen(filepath, 'rt'); % 'rt' - read + text mode

% Final variables to be saved and imported to SPM 
% 'Specify 1st-level/Data & Design/Multiple Conditions'
names = {};
onsets = {};
durations = {};

idx = 1;
conversion_factor = 1000; % for msec

while ~feof(fid) % While ~ end of file
    
    % Protection against end of file
    raw_line = fgetl(fid);
    if isnumeric(raw_line) && raw_line == -1; break; end

    line = strtrim(raw_line);

    % NOTE: fgetl reads everything between the current pointer position and the next line change, 
    % moving the pointer to the beginning of the next line. The pointer is used to ensure the file 
    % is being processed sequentially (from top to bottom).

    % Check unit of time of protocol (usually msec in BV)
    if contains(line, 'ResolutionOfTime:', 'IgnoreCase', true)
        if contains(line, 'msec', 'IgnoreCase', true)
            conversion_factor = 1000;
        else 
            conversion_factor = str2double(input("Time Resolution appears not to be in msec. Input manually your conversion factor (to sec): "));
        end
    end
    
    % Jump empty or irrelevant lines for SPM protocol
    if isempty(line) || ...
       contains(line, 'FileVersion') || ...
       contains(line, 'Experiment') || ...
       contains(line, 'BackgroundColor') || ...
       contains(line, 'TextColor') || ...
       contains(line, 'TimeCourseColor') || ...
       contains(line, 'TimeCourseThick') || ...
       contains(line, 'ReferenceFunc') || ...
       contains(line, 'NrOfConditions')
        continue;
    end
    
    % PRT file follows the format:
    % (...)
    % name of condition
    % number of trials
    % start time of event  *space*  end time of event
    % (...)
    % Knowing this format, we can find the desired data automatically
    
    current_position = ftell(fid); % pointer to save current position in the file
    
    next_line = strtrim(fgetl(fid));
    
    % Tries to convert next line to number... 
    num_trials = str2double(next_line);
    
    % If it was indeed a number, it means the current line has the name of the 
    % condition and the next line has the number of trials for that condition!
    % Note that this is only true and only works because of the PRT file format...
    if ~isnan(num_trials)

        condition_name = line;
        
        if num_trials > 0
            % PRT files have the start and end times of an event, not
            % the start time and the duration - we have to calculate!
            temp_onsets = [];
            temp_durations = [];
            
            actual_trials_read = 0;
            for k = 1:num_trials

                pos_before_trial = ftell(fid); % saves position before reading trial line

                % Protection against end of file
                raw_trial_line = fgetl(fid);
                if isnumeric(raw_trial_line) && raw_trial_line == -1; break; end
                
                trial_line_trim = strtrim(raw_trial_line);
                    
                % Found a problem in several protocols: some said there were x events for a certain condition,
                % but the number of times was not matching that number. To overcome that problem, we need to
                % detect its presence...
                if contains(trial_line_trim,'Color:','IgnoreCase',true) || isempty(trial_line_trim) % if that line is not a pair of numbers
                    fseek(fid,pos_before_trial,'bof'); % we don't want the color line! Goes back to the position saved in pos_before_trial
                    fprintf("\n   > [WARNING] Count mismatch in '%s': Expected %d, found %d. Stopping early.",condition_name,num_trials,actual_trials_read);
                    break;
                end

                time_data = sscanf(raw_trial_line, '%f'); % get both numbers
                
                if length(time_data)>=2
                    start_time = time_data(1);
                    end_time = time_data(2);
                    
                    % Convert to seconds (SPM doesn't work with msec)
                    temp_onsets(end+1) = start_time/conversion_factor;
                    % Duration = Final time (2nd number) - Initial time (1st number)
                    temp_durations(end+1) = (end_time-start_time)/conversion_factor;
                
                    actual_trials_read=actual_trials_read+1;
                else
                    fprintf("\n   > [WARNING] Malformed trial (missing times). Skipping line.\n")
                end
            end
            
            % Update variables to be exported
            names{idx} = condition_name;
            onsets{idx} = temp_onsets;
            durations{idx} = temp_durations;
            idx = idx + 1;
            
            % Skip 'Color:' line
            fgetl(fid); 
        else
            % If 0 trials, we need to skip the 'Color:' line
            check_color = fgetl(fid); 
            if isempty(check_color) % Sometimes there's an extra line before the 'Color:'...
                fgetl(fid);
            end
        end
    else
        % if num_trials line is NaN, it might be an empty line or a lost 'Color' line...
        % It is best to return to the beginning of the line
        fseek(fid, current_position, 'bof'); % 'bof' - beginning of file
    end
end

fclose(fid);
end
