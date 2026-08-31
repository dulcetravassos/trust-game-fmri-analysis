%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Distortion Correction - Unzip outputs and create JSONs (SPM)         %
%                                                                        %
%   Unzips the new images (fieldmap and functional) from the previous    % 
%   script and creates a JSON for them (for the functional, copies the   %
%   metadata from the 'ra*.json', appends the information regarding the  %
%   Distortion Correction performed in the previous script, and saves it %
%   as the new 'ura*.json' sidecar).                                     %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 22/02/2026                                                  %
%   Last update: 01/09/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Note that the preprocessing pipeline would work without Distortion 
% Correction and would therefore stay inside the MATLAB/SPM environment 
% with minor changes.

% All FSL theoretical information was taken from:
% https://fsl.fmrib.ox.ac.uk/fsl/docs/registration/fugue.html
% https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/FUGUE(2f)Guide.html
% https://fsl.fmrib.ox.ac.uk/fsl/docs/structural/bet.html
% https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/BET(2f)UserGuide.html
% https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/FLIRT(2f)UserGuide.html
% https://fsl.fmrib.ox.ac.uk/fsl/docs/registration/flirt/faq.html
% Some commands are not described in the links above and were found by 
% typing the toolbox name in the Ubuntu terminal.

%% Acquisition Parameters - Main Task

% Echo Time 1: 0.00492 s
% Echo Time 2: 0.00738 s
% deltaTE: EchoTime2-EchoTime1 = 2.46 ms

% Echo Spacing: 0.56 ms = 0.00056 s

% Phase Encoding Direction: A >> P = y- direction

%% Acquisition Parameters - Face Localizer

% Echo Spacing: 0.69 ms = 0.00069 s

% Phase Encoding Direction: A >> P = y- direction

%% FSL BET commands

% bet <input> <output> [options]
%
% Main bet2 options
% -o generate brain surface outline overlaid onto original image
% -m generate binary brain mask
% -s generate rough skull image (not as clean as what betsurf generates)
% n do not generate the default brain image output
% f <number> fractional intensity threshold (0..1); default=0.5; smaller values give larger brain outline estimates
% -g <number> vertical gradient in fractional intensity threshold (-1..1); default=0; positive values give larger brain outline at bottom, smaller at top
% r <number> head radius (mm not voxels); initial surface sphere is set to half of this
% -c <x y z> centre-of-gravity (voxels not mm) of initial mesh surface
% -t apply thresholding to segmented brain image and mask
% --ct Assume that the input is a CT image - applies the Hounsfield transform described in https://pubmed.ncbi.nlm.nih.gov/22440645/
% -e generates brain surface as mesh in .vtk format

%% fsl_prepare fielmaps commands

% fsl_prepare_fieldmap <scanner> <phase_image> <magnitude_image> <out_image> <deltaTE (in ms)> [--nocheck]
%
% Prepares a fieldmap suitable for FEAT from SIEMENS or GEHC data - saves output in rad/s format
%   <scanner> must be SIEMENS or GEHC_FIELDMAPHZ
%   <phase_image> should be the phase difference for SIEMENS and the fieldmap in HERTZ for GEHC_FIELDMAPHZ
%   <magnitude image> should be Brain Extracted (with BET or otherwise)
%   <deltaTE> is the echo time difference of the fieldmap sequence - find this out form the operator (defaults are *usually* 2.46ms on SIEMENS)
%   --nocheck supresses automatic sanity checking of image size/range/dimensions

%% FSL FUGUE commands

% fugue -i epi -p unwrappedphase --dwell=dwelltime --asym=asymtime -s 0.5 -u result
% fieldmap specified by a 4D file unwrappedphase containing two unwrapped phase images - from different echo times - plus the dwell time and echo time difference (asym time)
% 
% fugue -i epi --dwell=dwelltime --loadfmap=fieldmap -u result
% uses a previously calculated fieldmap
%
% Note the option -s 0.5 is an example of how to specify the regularisation to apply to the fieldmap (2D Gaussian smoothing of sigma=0.5 in this case which is a reasonable default).

% flirt -in inimage -out outimage -ref refimage -applyxfm -init savedtransform.mat
% The transformation is automatically saved in a file with an extension of .mat and this transformation can be applied to the input image (for resampling) with the 
% GUI ApplyXFM which allows the output image voxel size and FOV to be specified either directly or by using a reference image with the appropriate size. 
% At the command line, the transformation can be saved using the -omat option. This file can then be used for resampling by specifying it with the -init and -applyxfm options. 
% In this form the reference image is used to specify the voxel size and FOV only - all intensities within it are ignored. 

% flirt -in im3 -ref imref -dof 12 -out imout3 -omat im3_to_imref.mat
% Register each image in the set to the reference image, using flirt, and saving the output images
% -dof: degrees of freedom

%% Regular subjects (with real magnitude)

% Example
% ----------- s05_01 -----------
% bet ../../../rawdata/sub-915/fmap/sub-915_run-01_magnitude.nii fmap/sub-915_run-01_magnitude_brain.nii.gz -f 0.5 -m
% fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-01_phasediff.nii -div 2 fmap/sub-915_run-01_phasediff_half.nii.gz
% fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-01_phasediff_half.nii.gz fmap/sub-915_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-915_run-01.nii.gz 2.46 --nocheck
% fslmaths fmap/fmap_rads_sub-915_run-01.nii.gz -nan fmap/fmap_rads_sub-915_run-01.nii.gz
% flirt -in fmap/sub-915_run-01_magnitude_brain.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
% flirt -in fmap/fmap_rads_sub-915_run-01.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-915_run-01.nii.gz
% fugue -i func/rasub-915_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-01.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-01_bold.nii.gz -v
% ----------- s05_02 -----------
% Unzip rfmap* and ura* files and create JSONs (BIDS-compliant)

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with fmap run-02)

%% Special case: fake magnitude subjects

% The substitute/surrogate magnitude was already skull-stripped with SPM's native Segmentation tool.

% Example
% ----------- s05_01 -----------
% fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-01_phasediff.nii -div 2 fmap/sub-819_run-01_phasediff_half.nii.gz
% fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-01_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-01.nii.gz 2.46 --nocheck
% fslmaths fmap/fmap_rads_sub-819_run-01.nii.gz -nan fmap/fmap_rads_sub-819_run-01.nii.gz
% flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
% flirt -in fmap/fmap_rads_sub-819_run-01.nii.gz -ref func/rasub-819_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-819_run-01.nii.gz
% fugue -i func/rasub-819_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-01.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-01_bold.nii.gz -v
% ----------- s05_02 -----------
% Unzip rfmap* and ura* files and create JSONs (BIDS-compliant)

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with fmap run-02)

%% Final notices

% You can use the full paths to each file or, before running these scripts, change the terminal's directory using the 'cd' command
% (for example, cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-915/)

% In cases where there are magnitude1 and magnitude2, we manually chose the best option:
% MAGNITUDE 1:
% sub-915: Runs – 2, 3, 6, 7  
% sub-295: Runs – 1, 2, 3, 4 
% sub-971: Runs – 2, 4, 5, 8
% sub-162: Runs – 3, 4, 5, 7, 8 
% MAGNITUDE 2:
% sub-295: Runs – 6, 8
%
% Additionally, while developing this script, I noticed that thosemagnitude1 and magnitude2 files had +1 voxel than the phasediff, 
% blocking the fsl_prepare_fieldmap. Those runs have an additional line (flirt), to cut the magnitude to the exact size of phasediff.
%
% flirt -in fmap/sub-915_run-01_magnitude_brain.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
% flirt -in fmap/fmap_rads_sub-915_run-01.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat  -out fmap/rfmap_rads_sub-915_run-01.nii.gz
% flirt: used for registration, the main options are an input (-in), a reference (-ref) volume, the calculated affine transformation that registers 
% the input to the reference which is saved as a 4x4 affine matrix (-omat), and output volume (-out) where the transform  is applied to the input 
% volume to align it with the reference volume. To apply a saved transformation to a volume: -applyxfm, -init and -out. For these usage the reference 
% volume must still be specified as this sets the voxel and image dimensions of the resulting volume.

% fslmaths fmap/fmap_rads_sub-119_run-01.nii -nan fmap/fmap_rads_sub-119_run-01.nii
% replaces NaNs with 0

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

clear all; clc;

% Input and output directories
base_dir = fullfile(main_dir,'data','spm-data');
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% List of Subjects
subjects = {
    'sub-819', 'sub-908', 'sub-147', 'sub-915', 'sub-641', 'sub-119', ...
    'sub-295', 'sub-557', 'sub-958', 'sub-965', 'sub-177', 'sub-971', ...
    'sub-664', 'sub-497', 'sub-805', 'sub-162', 'sub-435', 'sub-917', ...
    'sub-797', 'sub-960'
};

%% Unzip and Generate JSONs

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Unzipping FSL outputs for: %s\n', subj);
    
    func_dir = fullfile(deriv_dir,subj,'func');
    fmap_dir = fullfile(deriv_dir,subj,'fmap');

    % -------------------------- Fieldmaps --------------------------

    % Find all rfmap_rads.nii.gz (resliced by FSL Flirt)
    fmaps_gz = dir(fullfile(fmap_dir,'rfmap_rads_*.nii.gz'));
    if isempty(fmaps_gz)
        fprintf('[Warning] No rfmap_rads_*.nii.gz files found for %s.\n',subj);
        %continue;
    else
        for p = 1:length(fmaps_gz)
            fmap_gz_file = fullfile(fmap_dir,fmaps_gz(p).name);
            fprintf('>> Unzipping FMAP: %s\n',fmaps_gz(p).name);
            
            % Unzip if the .nii doesn't exist yet
            fmap_nii_file = replace(fmap_gz_file,'.nii.gz','.nii');
            if ~exist(fmap_nii_file,'file')
                gunzip(fmap_gz_file);
            end
        
            % Extract basic name and create JSON
            [~,fmap_name_only,~] = fileparts(replace(fmap_gz_file,'.nii.gz','.nii'));
            fmap_out_json = fullfile(fmap_dir,[fmap_name_only '.json']);
            create_fmap_json(fmap_out_json,subj);
        end
    end

    % ---------------------- Functional 'ura' ----------------------
    
    tasks = {'task-main', 'task-localizer'};

    for t=1:length(tasks)
        current_task = tasks{t};
        fprintf('\n--- Processing Task: %s ---\n',current_task);

        % Find all urasub-00x_task-main_run-0y_bold.nii.gz
        search_pattern = sprintf('ura*%s*.nii.gz',current_task);
        ura_files_gz = dir(fullfile(func_dir,search_pattern));
        if isempty(ura_files_gz)
            fprintf('[Warning] No %s files found for %s.\n',current_task,subj);
            %continue;
        else
            for p = 1:length(ura_files_gz)
                func_gz_file = fullfile(func_dir,ura_files_gz(p).name);
                fprintf('>> Unzipping FUNC: %s\n',ura_files_gz(p).name);
            
                % Unzip if the .nii doesn't exist yet
                func_nii_file = replace(func_gz_file,'.nii.gz','.nii');
                if ~exist(func_nii_file,'file')
                    gunzip(func_gz_file);
                end
            
                [~,func_name_only,~] = fileparts(replace(func_gz_file, '.nii.gz', '.nii'));
                func_base_name_raw = eraseBetween(func_name_only,1,3); % removes 'ura' prefix to obtain the original file name
            
                ra_json_path = fullfile(func_dir,['ra' func_base_name_raw '.json']);
                ura_json_path = fullfile(func_dir,[func_name_only '.json']);
                
                create_ura_json(ra_json_path,ura_json_path,subj,func_base_name_raw);
            end
        end
    end
end
fprintf('\nDone!\n');

%% Helper Functions

function create_fmap_json(target_json_path,subj)

json_data = struct();
json_data.Description = 'Coregistered Phase/Magnitude Fieldmap calculated in rad/s using FSL FUGUE';
json_data.Units = 'rad/s';
json_data.Software = 'FSL (fsl_prepare_fieldmap & flirt)';

fake_mag_subjects = {'sub-819', 'sub-908', 'sub-147'};
if ismember(subj,fake_mag_subjects)
    json_data.Sources = {
        sprintf('rawdata/%s/fmap/ (phasediff)',subj), ...
        sprintf('derivatives/spm-preprocessing/%s/fmap/ (fake magnitude derived from T1w)',subj)
        };
else
    json_data.Sources = {sprintf('rawdata/%s/fmap/ (phasediff and magnitude)',subj)};
end

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end


function create_ura_json(ra_json_path,ura_json_path,subj,func_base_name_raw)

if exist(ra_json_path,'file')
    content = fileread(ra_json_path);
    try
        json_data = jsondecode(content);
    catch
        json_data = struct();
    end
else
    json_data = struct();
end

if contains(func_base_name_raw,'localizer')
    dwell_time = 0.00069;
    fmap_name = sprintf('rfmap_rads_%s_run-01.nii',subj);
else
    dwell_time = 0.00056;
    run_str = regexp(func_base_name_raw,'run-\d+','match','once');
    fmap_name = sprintf('rfmap_rads_%s_%s.nii',subj,run_str);
end

json_data.DistortionCorrection = true;
json_data.DistortionCorrectionSoftware = 'FSL FUGUE';
json_data.DistortionCorrectionParameters = struct('dwell_time',dwell_time,'unwarpdir','y-');

%fake_mag_subjects = {'sub-819', 'sub-908', 'sub-147'};
%if ismember(subj,fake_mag_subjects)
%    json_data.DistortionCorrectionParameters.FieldmapSmoothing = 'Gaussian (sigma=2mm)';
%end

json_data.B0FieldSource = fmap_name;
json_data.Sources = {sprintf('func/ra%s.nii',func_base_name_raw)};

% Save .json file
fid = fopen(ura_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end