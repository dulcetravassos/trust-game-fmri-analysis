%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Slice Timing Correction (BIDS ready)                                 %
%                                                                        %
%   Adapted to deal with subjects with reverse slice order and variable  %
%   volumes. Saves output in derivatives folder with a JSON file (BIDS   %
%   friendly).                                                           %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 06/02/2026                                                  %
%   Last update: 01/09/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

% Main folder
main_dir = 'C:\Users\User\Desktop\Tese';

spm_path = fullfile(main_dir,'spm12');

% Input and output directories
base_dir = fullfile(main_dir,'data','spm-data');
raw_dir  = fullfile(base_dir,'rawdata');
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% Acquisition Parameters (most are defined inside the main loop)
TR = 2; % Repetition time in secs
%nslices = 34; % Number of slices
%ref_slice = 2; % Reference slice
%TA = TR-(TR/nslices); % Time of Acquisition
%standard_slice_order = [2:2:nslices 1:2:nslices]; % Slice Order (Series Interleaved)

% List of Subjects
subjects = {
    'sub-819', 'sub-908', 'sub-147', 'sub-915', 'sub-641', 'sub-119', ...
    'sub-295', 'sub-557', 'sub-958', 'sub-965', 'sub-177', 'sub-971', ...
    'sub-664', 'sub-497', 'sub-805', 'sub-162', 'sub-435', 'sub-917', ...
    'sub-797', 'sub-960'
};

% Volumes - Localizer Task
vol_localizer = 190;

% Volumes - Main Task
volumes_main = [
    206, 250, 246, 206, 224, 223, 222, 223; % sub-819
    226, 223, 222, 223, 223, 223, 223, 223; % sub-908
    223, 223, 223, 223, 223, 223, 223, 223; % sub-147
    223, 223, 223, 223, 223, 223, 223, 223; % sub-915
    223, 223, 223, 223, 223, 223, 223, 223; % sub-641
    223, 223, 223, 223, 223, 223, 223, 223; % sub-119
    223, 223, 223, 223, 223, 223, 223, 223; % sub-295
    223, 223, 223, 223, 223, 223, 223, 223; % sub-557
    223, 223, 223, 223, 223, 223, 223, 223; % sub-958
    223, 223, 223, 223, 223, 223, 223, 223; % sub-965
    223, 223, 223, 223, 223, 223, 223, 223; % sub-177
    223, 223, 223, 223, 223, 223, 223, 223; % sub-971
    223, 223, 223, 223, 223, 223, 223, 223; % sub-664
    223, 223, 223, 223, 223, 223, 223, 223; % sub-497
    223, 223, 223, 223, 223, 223, 223, 223; % sub-805
    223, 223, 223, 223, 223, 223, 223, 223; % sub-162
    223, 223, 223, 223, 223, 223, 223, 223; % sub-435
    223, 223, 223, 223, 223, 223, 223, 223; % sub-917
    223, 223, 223, 223, 223, 223, 223, 223; % sub-797
    223, 223, 223, 223, 223, 223, 223, 223; % sub-960
];

%% Slice Timing

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

if size(volumes_main,1) ~= length(subjects)
    error('ERROR: volumes_main has %d lines, but there are %d subjects!',size(volumes_main,1),length(subjects));
end

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Processing Slice Timing for: %s\n', subj);
    
    % Create output folder
    subj_out_dir = fullfile(deriv_dir,subj,'func');
    if ~exist(subj_out_dir,'dir'); mkdir(subj_out_dir); end
    
    % Tasks
    tasks = {'task-main','task-localizer'};

    for t=1:length(tasks)
        current_task = tasks{t};

        if strcmp(current_task,'task-main')
            nslices = 34;
            ref_slice = 2;
            std_order = [2:2:nslices 1:2:nslices]; % Interleaved
            inv_order = [nslices:-2:2 (nslices-1):-2:1];
        elseif strcmp(current_task,'task-localizer')
            nslices = 29;
            ref_slice = 1;
            std_order = [1:2:nslices 2:2:nslices]; % Interleaved
            inv_order = [nslices:-2:1 (nslices-1):-2:2];
        end
    
        % Time of Acquisition
        TA = TR-(TR/nslices);
    
        % F>>H EXCEPT sub-497 (H>>F)
        if strcmp(subj,'sub-497'); slice_order = inv_order;
        else; slice_order = std_order; end
    
    
        % Get functional files ('sub-002_task-main_run-01_bold.nii' format-like)
        subj_func_dir = fullfile(raw_dir,subj,'func');
        file_pattern = sprintf('*%s*_bold.nii',current_task);
        run_struct = dir(fullfile(subj_func_dir,file_pattern));
        [~,idx] = sort({run_struct.name});
        run_files = run_struct(idx);
        if isempty(run_files)
            fprintf('[WARNING] No functional files found for %s. Skipping.\n', subj);
            continue;
        end
        
        fprintf('######## Analyzing %s (%d files)... ########\n',current_task,length(run_files));
    
        all_sessions = {};
        files_to_move = {};
    
        for r = 1:length(run_files)
            filename = run_files(r).name;
            
            if strcmp(current_task,'task-main')
                n_vols_target = volumes_main(s,r); % subject - line, run - column
            else
                n_vols_target = vol_localizer;
            end

            % Select volumes (from 1 to n_vols_target)
            bold_frames = spm_select('ExtFPList',subj_func_dir,['^',filename,'$'],1:n_vols_target);
            if isempty(bold_frames)
                fprintf('[ERROR] Could not read frames for %s\n', filename);
                continue;
            end

            all_sessions{end+1} = cellstr(bold_frames);
            files_to_move{end+1} = filename;      
        end

        if isempty(all_sessions); continue; end;
        
        % ####################### SPM Batch #######################
        clear matlabbatch;
        % --------------- List of open inputs ---------------
        % Data
        matlabbatch{1}.spm.temporal.st.scans = all_sessions;
        % Number of Slices
        matlabbatch{1}.spm.temporal.st.nslices = nslices;
        % TR
        matlabbatch{1}.spm.temporal.st.tr = TR;
        % TA
        matlabbatch{1}.spm.temporal.st.ta = TA;
        % Slice order
        matlabbatch{1}.spm.temporal.st.so = slice_order;
        % Reference Slice
        matlabbatch{1}.spm.temporal.st.refslice = ref_slice;
        % Prefix added to the (output) file name
        matlabbatch{1}.spm.temporal.st.prefix = 'a';
        
        try
            spm_jobman('run', matlabbatch);
            fprintf('>>> Slice Timing completed for %s\n', subj);
        catch ME
            fprintf('[CRITICAL ERROR] SPM failed for %s: %s\n', subj, ME.message);
            continue;
        end
        
        % To comply with BIDS, we need to move the new files to the derivatives folder... 
        % Also, creates JSON file for this operation
        for k = 1:length(files_to_move)
            orig_name = files_to_move{k};
            out_name = ['a' orig_name];
            src = fullfile(subj_func_dir,out_name);
            dest = fullfile(subj_out_dir,out_name);
    
            if exist(src,'file') 
                movefile(src,dest);
                init_json_path = fullfile(subj_func_dir,replace(orig_name,'.nii','.json'));
                out_json_path = replace(dest,'.nii','.json');  
                create_derivative_json(init_json_path, out_json_path, ref_slice);
            else
                fprintf('[WARNING] Could not find generated file: %s\n',out_name);
            end

            % Move .mat file, if there is one
            [~,fname,~] = fileparts(orig_name);
            mat_src = fullfile(subj_func_dir,['a' fname '.mat']);
            if exist(mat_src,'file'); movefile(mat_src,fullfile(subj_out_dir,['a' fname '.mat'])); end

        end
        fprintf('  > Done for %s!\n', subj);
    end
end

fprintf('\nFinished!\n')

%% Helper Functions

function create_derivative_json(source_json_path,target_json_path,ref_slice)

if exist(source_json_path,'file')
    content = fileread(source_json_path);
    json_data = jsondecode(content);
else
    json_data = struct(); % start new one
end

json_data.SliceTimingCorrected = true;
json_data.ReferenceSliceIndex = ref_slice;
json_data.Sources = {source_json_path};

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end