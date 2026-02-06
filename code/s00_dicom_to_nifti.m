%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   DICOM to NIfTI Files (BIDS ready)                                    %
%                                                                        %
%   Converts raw DICOM MRI data (anatomical, functional, fieldmaps)      %
%   into NIfTI files suitable for preprocessing and analysis in SPM12.   %
%   Saves a JSON file with metadata.                                     %
%   Output filenames follow BIDS conventions, when applicable.           %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 19/01/2026                                                  %
%   Last update: 06/02/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; clc;

%% Initial Configurations
% Change according to your preferences

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
raw_base_dir = 'C:\Users\User\Desktop\Tese\data\raw';
output_base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data\rawdata';

% What is going to be converted (1 for yes, 0 for no)
convert_anat_defaced = 1; % Defaced Anatomical
convert_anat_mprage = 1; % MPRAGE Anatomical
convert_func_main = 1; % Functional Runs
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
        convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'anat','MPRAGE','T1w',runs_main);
    end
        
    % Anatomical - defaced
    if convert_anat_defaced
        fprintf('------ Defaced Image Conversion ------\n');
        % Output name: sub-00x_desc-defaced_T1w.nii
        convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'anat','defaced','desc-defaced_T1w',runs_main);
    end

    % FieldMaps
    if convert_fmap
        fprintf('------ FieldMaps (Magnitude + Phase) Conversion ------\n');
        for r = runs_fmap
            run_str=sprintf('run%d',r);

            % Magnitude
            subfolder_mag = fullfile('MAGN_PHASE', 'magnitude', run_str); % .../func/MAGN_PHASE/magnitude/runx
            suffix_mag = sprintf('run-%02d_magnitude',r);  % To follow BIDS convention: run-0x_magnitude
            convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'fmap',subfolder_mag,suffix_mag,runs_main);
            
            % Phase
            subfolder_phase = fullfile('MAGN_PHASE', 'phase', run_str); % .../func/MAGN_PHASE/phase/runx
            suffix_phase = sprintf('run-%02d_phasediff',r);  % To follow BIDS convention: run-0x_phasediff
            convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'fmap',subfolder_phase,suffix_phase,runs_main);
        end
    end

    % Functional
    if convert_func_main
        fprintf('------ Functional Image Conversion ------\n');
        for r=runs_main
            run_str=sprintf('run%d',r);
            task_name = 'main';
            suffix=sprintf('task-%s_run-%02d_bold',task_name,r); % To follow BIDS convention: run-0x_bold
            convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'func',run_str,suffix,runs_main);
        end
    end

    % Face Localizers
    if convert_func_loc
        fprintf('------ Face Localizers Conversion ------\n');
        %suffix = sprintf('task-localizer_run-%02d_bold',r); % To follow BIDS convention: localizer_run-0x_bold
        convert_folder(raw_base_dir,output_base_dir,raw_subj,bids_subj,'func','FACELOCALIZERS','task-localizer_bold',runs_main);
    end

end

fprintf('\nConversion Finished!\n')

%% Helper function
% Useful to maintain the code atomic (no need to repeat lines of code)

function convert_folder(raw_base,out_base,r_subj,b_subj,type,subfolder,suffix,runs_list)

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

% ------- Read DICOM files and extract metadata to a new JSON file -------
hdr = spm_dicom_headers(dcm_files(1,:)); 
hdr = hdr{1};

try tr_val = hdr.RepetitionTime/1000;
catch; tr_val = 2.0; end % Directly taken from Scanner Properties
try te_val = hdr.EchoTime/1000;
catch 
    if contains(suffix, 'localizer') || contains(subfolder, 'FACELOCALIZERS')
        te_val = 0.039; % 39ms for Face Localizers
    else
        te_val = 0.030; % 30ms for Main Task
    end 
end

% Prepare JSON info
json_info.type = type; % 'func', 'fmap', 'anat'
json_info.suffix = suffix;
json_info.runs_main = runs_list;
json_info.bids_subj = b_subj;
if contains(suffix,'task-main'); json_info.task = 'main';
elseif contains(suffix,'task-localizer'); json_info.task = 'localizer';
else; json_info.task = 'unknown'; end


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

    % Create JSON for functional data
    create_bids_json(final_path,tr_val,te_val,hdr,json_info);

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

        % Create JSON
        current_info = json_info;
        current_info.suffix = this_suffix; % sends new updated suffix
        create_bids_json(final_path,tr_val,te_val,hdr,current_info);
    end
end
end

% ---------------------------------------------------------------------------------------------------------------

function create_bids_json(nifti_path,tr,te,hdr,info)

json=struct();

json.Manufacturer = 'Siemens';
if isfield(hdr,'ManufacturersModelName'); json.ManufacturersModelName = hdr.ManufacturersModelName; end
if isfield(hdr,'Modality'); json.Modality = hdr.Modality; end
if isfield(hdr,'MagneticFieldStrength'); json.MagneticFieldStrength = hdr.MagneticFieldStrength; end
if isfield(hdr,'DeviceSerialNumber'); json.DeviceSerialNumber = hdr.DeviceSerialNumber; end
if isfield(hdr,'StationName'); json.StationName = hdr.StationName; end

if isfield(hdr,'AcquisitionNumber'); json.AcquisitionNumber = hdr.AcquisitionNumber; end
if isfield(hdr,'AcquisitionTime')
    val = hdr.AcquisitionTime;
    hours = floor(val / 3600);
    minutes = floor(mod(val, 3600) / 60);
    seconds = floor(mod(val, 60));
    json.AcquisitionTime = sprintf('%02d:%02d:%02d',hours,minutes,seconds);
end

if isfield(hdr,'SeriesNumber'); json.SeriesNumber = hdr.SeriesNumber; end
if isfield(hdr,'SeriesDescription'); json.SeriesDescription = hdr.SeriesDescription; end
if isfield(hdr,'StudyDescription'); json.StudyDescription = hdr.StudyDescription; end
if isfield(hdr,'FlipAngle'); json.FlipAngle = hdr.FlipAngle; end

if isfield(hdr,'PatientPosition'); json.PatientPosition = hdr.PatientPosition; end
if isfield(hdr,'SliceThickness'); json.SliceThickness = hdr.SliceThickness; end

if isfield(hdr, 'ImageOrientationPatient'); json.ImageOrientationPatientDICOM = hdr.ImageOrientationPatient; end
if isfield(hdr, 'ImagePositionPatient'); json.ImagePositionPatientDICOM = hdr.ImagePositionPatient; end
if isfield(hdr, 'ImageType'); json.ImageType = strjoin(string(hdr.ImageType),' '); end

json.ConversionSoftware = 'SPM12';
try json.ConversionSoftwareVersion = spm('Ver'); catch; json.ConversionSoftwareVersion = 'Unknown'; end

% Functional files
nslices=0;
if strcmp(info.type,'func')

    if isfield(info,'task'); json.TaskName = info.task; end;
    json.RepetitionTime = tr;
    json.EchoTime = te;

    if strcmp(info.task,'main')

        % Since we know that the protocol is Siemens Interleaved with 34 slices, we
        % can calculate the exact timing and save them in the JSON.
        % Order: [2, 4, 6, ..., 34, 1, 3, ..., 33]
        
        nslices = 34;
        time_per_slice = tr/nslices;
        slice_times = zeros(1, nslices);
        
        % Even slices
        % Slice 2 at t=0, slice 2*n at t=(n-1)*time_per_slice
        counter = 0;
        for s = 2:2:nslices
            slice_times(s) = counter * time_per_slice;
            counter = counter+1;
        end
        
        % Odd slices
        for s = 1:2:nslices
            slice_times(s) = counter * time_per_slice;
            counter = counter+1;
        end
        
        json.SliceTiming = slice_times;

    elseif strcmp(info.task,'localizer')
        % Localizers may not have 29 slices...
        nslices = 29;
        time_per_slice = tr/nslices;
        slice_times = zeros(1, nslices);
        
        % Odd slices
        counter = 0;
        for s = 1:2:nslices
            slice_times(s) = counter * time_per_slice;
            counter = counter+1;
        end
        
        % Even slices
        for s = 2:2:nslices
            slice_times(s) = counter * time_per_slice;
            counter = counter+1;
        end
        
        json.SliceTiming = slice_times;
    end

    if isfield(hdr,'InstanceNumber'); json.ImageNumber = hdr.InstanceNumber; end
end

% Fieldmap files
if strcmp(info.type,'fmap')
    % phasediff: TE1 + TE2
    if contains(info.suffix,'phasediff')
        if isfield(hdr,'EchoTime1') && isfield(hdr,'EchoTime2')
            json.EchoTime1 = hdr.EchoTime1/1000;
            json.EchoTime2 = hdr.EchoTime2/1000;
        else
            warning('EchoTime1/EchoTime2 not found in DICOM header.');
        end
    end

    % IntendedFor
    if ~isempty(info.suffix)
        tokens = regexp(info.suffix,'run-(\d+)','tokens');
        if ~isempty(tokens)
            run_num = str2double(tokens{1}{1}); % '01', for example
            fname = sprintf('func/%s_task-main_run-%02d_bold.nii',info.bids_subj,run_num);
            json.IntendedFor = {fname};
        else
            % What if there is no run number? In BIDS that would be unexpected...
        end
    end
end

% Save .json file
json_path = replace(nifti_path,'.nii','.json');
fid = fopen(json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json,'PrettyPrint',true));
fclose(fid);

if nslices>0; fprintf('   -> JSON created: TR=%.2fs, Slices=%d\n',tr,nslices);
else; fprintf('   -> JSON created (basic info)\n'); end;
end