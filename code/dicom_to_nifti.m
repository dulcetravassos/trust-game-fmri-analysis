%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   DICOM to NIfTI Files (BIDS ready)                                    %
%                                                                        %
%   Converts raw DICOM MRI data (anatomical, functional, fieldmaps)      %
%   into NIfTI files suitable for preprocessing and analysis in SPM12.   %
%   Output filenames follow BIDS conventions, when applicable.           %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 19/01/2026                                                  %
%   Last update: 21/01/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc;

%% Initial Configurations
% Change according to your preferences

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
raw_base_dir = 'C:\Users\User\Desktop\Tese\github\data\raw';
output_base_dir = 'C:\Users\User\Desktop\Tese\github\data\spm-data\rawdata';

% What is going to be converted (1 for yes, 0 for no)
convert_anat_defaced = 0; % Defaced Anatomical
convert_anat_mprage = 0; % MPRAGE Anatomical
convert_func_main = 0; % Functional Runs
convert_func_loc = 1; % Face Localizers
convert_fmap = 1; % Fieldmaps (Magnitude, Phase)

% Runs to convert ([1:n] for all)
runs_main = [1:8]; % Functional Runs
runs_fmap = [1:8]; % Fieldmaps

% The raw data may not follow BIDS format and, therefore, the subjects' names 
% may vary between the input and output. This correspondence table follows
% the format {raw, BIDS}.
subject_map = {
    'sub-tg02',  'sub-002';
    'sub-tg03',  'sub-003';
    'sub-tg04',  'sub-004';
    'sub-tg06',  'sub-006';
    'sub-tg07',  'sub-007';
    'sub-tg08',  'sub-008';
    'sub-tg09',  'sub-009';
    'sub-tg11',  'sub-011';
    'sub-tg12',  'sub-012';
    'sub-tg13',  'sub-013';
    'sub-tg14',  'sub-014';
    'sub-tg15',  'sub-015';
    'sub-tg16',  'sub-016';
    'sub-tg17',  'sub-017';
    'sub-tg18',  'sub-018';
    'sub-tg19',  'sub-019';
    'sub-tg20',  'sub-020';
    'sub-tg21',  'sub-021';
    'sub-tg22',  'sub-022';
    'sub-tg23',  'sub-023';
};

%% Conversion Logic

% Check if spm is already in the path and, if not, adds it
if isempty(which('spm'))
    if exist(spm_path, 'dir')
        addpath(spm_path);
    else
        error('CRITICAL ERROR: SPM folder not found at %s.', spm_path);
    end
end

% Initialize SPM
spm('defaults', 'FMRI');
spm_jobman('initcfg');

nsubs = size(subject_map,1);
for s=1:nsubs

    raw_subj = subject_map{s,1};
    bids_subj = subject_map{s,2};

    fprintf('\n======== Processing %s (BIDS: %s) ========\n',raw_subj,bids_subj);

    % Anatomical - MPRAGE
    if convert_anat_mprage
        fprintf('------ MPRAGE Conversion ------\n');
        % Output name: sub-00x_T1w.nii
        convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'anat','MPRAGE','T1w');
    end
        
    % Anatomical - defaced
    if convert_anat_defaced
        fprintf('------ Defaced Image Conversion ------\n');
        % Output name: sub-00x_desc-defaced_T1w.nii
        convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'anat','defaced','desc-defaced_T1w');
    end

    % FieldMaps
    if convert_fmap
        fprintf('------ FieldMaps (Magnitude + Phase) Conversion ------\n');
        for r = runs_fmap
            run_str=sprintf('run%d',r);

            % Magnitude
            subfolder_mag = fullfile('MAGN_PHASE', 'magnitude', run_str); % .../func/MAGN_PHASE/magnitude/runx
            suffix_mag = sprintf('run-%02d_magnitude',r);  % To follow BIDS convention: run-0x_magnitude
            convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'fmap',subfolder_mag,suffix_mag);
            
            % Phase
            subfolder_phase = fullfile('MAGN_PHASE', 'phase', run_str); % .../func/MAGN_PHASE/phase/runx
            suffix_phase = sprintf('run-%02d_phasediff',r);  % To follow BIDS convention: run-0x_phasediff
            convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'fmap',subfolder_phase,suffix_phase);
        end
    end

    % Functional
    if convert_func_main
        fprintf('------ Functional Image Conversion ------\n');
        for r=runs_main
            run_str=sprintf('run%d',r);
            task_name = 'main';
            suffix=sprintf('task-%s_run-%02d_bold',task_name,r); % To follow BIDS convention: run-0x_bold
            convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'func',run_str,suffix);
        end
    end

    % Face Localizers
    if convert_func_loc
        fprintf('------ Face Localizers Conversion ------\n');
        %suffix = sprintf('task-localizer_run-%02d_bold',r); % To follow BIDS convention: localizer_run-0x_bold
        convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'func','FACELOCALIZERS','task-localizer_bold');
    end

end

fprintf('\nConversion Finished!\n')

%% Helper function
% Useful to maintain the code atomic (no need to repeat lines of code)

function convert_folder(raw_base,out_base,r_subj,b_subj,type,subfolder,suffix)

% /func files (functional runs and face localizers) are merged into a 4D file
if strcmp(type,'func'); do_merge = 1; 
else; do_merge = 0; end

% Fieldmaps are located in ...\func\MAGN_PHASE, but we defined them as type=fmap... 
% This approach detects that there isn't a fmap folder and will get the desired files from \func
% This code also verifies if source exists for all operations
path_try1 = fullfile(raw_base, r_subj, type, subfolder);
path_try2 = fullfile(raw_base, r_subj, 'func', subfolder);
if exist(path_try1,'dir'); dicom_dir = path_try1;
elseif exist(path_try2,'dir'); dicom_dir = path_try2; 
else; fprintf('     (Skipping %s - Source folder not found)\n',subfolder); return; end

dcm_files = spm_select('FPList',dicom_dir,'.dcm');
if isempty(dcm_files)
    fprintf('     (Skipping %s - Folder exists but is EMPTY)\n', subfolder); 
    return; 
end

out_dir = fullfile(out_base, b_subj, type); % output goes to anat/ or func/ root

% Creates output folder if missing
if ~exist(out_dir, 'dir'); mkdir(out_dir); end

% Save files that might be already in the output directory to protect
% them from the BIDS renaming (see next steps)
files_before = dir(fullfile(out_dir, '*.nii'));
if isempty(files_before)
    names_before = {};
else
    names_before = {files_before.name};
end

% -------------------------------------------------------------------------

clear matlabbatch;
matlabbatch{1}.spm.util.import.dicom.data = cellstr(dcm_files);
matlabbatch{1}.spm.util.import.dicom.root = 'flat';
matlabbatch{1}.spm.util.import.dicom.outdir = {out_dir};
matlabbatch{1}.spm.util.import.dicom.protfilter = '.*';
matlabbatch{1}.spm.util.import.dicom.convopts.format = 'nii';
matlabbatch{1}.spm.util.import.dicom.convopts.meta = 0; 
matlabbatch{1}.spm.util.import.dicom.convopts.icedims = 0;

% Run batch in SPM
spm_jobman('run', matlabbatch);


% All files in the directory (including other files)
files_after = dir(fullfile(out_dir, '*.nii'));
names_after = {files_after.name};

% Identify which files are new
created_files_names = setdiff(names_after, names_before);
created_files_names = sort(created_files_names); % They need to be ordered!!!!!!!


if length(created_files_names)>1 && do_merge==1 % functional image has multiple DICOM that need to be merged!
    fprintf('   -> Detected %d 3D files. Merging to 4D...\n',length(created_files_names));
    
    files_to_merge = fullfile(out_dir, created_files_names);

    % New file name: sub-00x + _ + suffix + .nii
    final_name = sprintf('%s_%s.nii', b_subj, suffix);
    final_path = fullfile(out_dir, final_name);
    
    % SPM 3D to 4D File Merge
    spm_file_merge(files_to_merge, final_path, 0);

    % Delete 3D files
    for k = 1:length(files_to_merge)
        delete(files_to_merge{k});
    end

else
    for k=1:length(created_files_names) % length=1 for anatomic, but >1 for fmap and should NOT be merged!
        origin_name = created_files_names{k};
        old_path = fullfile(out_dir,origin_name); 

        if length(created_files_names)>1; this_suffix = sprintf('%s%d',suffix,k); 
        else; this_suffix = suffix; end

        % New file name: sub-00x + _ + suffix + .nii
        final_name = sprintf('%s_%s.nii', b_subj, this_suffix);
        final_path = fullfile(out_dir, final_name);

        % Rename to BIDS (only if it's not already)
        if ~startsWith(origin_name,b_subj)
            movefile(old_path,final_path);
        end
    end
end
end