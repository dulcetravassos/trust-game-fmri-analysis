%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Distortion Correction - Align Fieldmap to Mean Functional (SPM)      %
%                                                                        %
%   Now that the fieldmap is a continuous rad/s map, we can safely       %
%   reslice it into the functional sapce using SPM's Coregister tool.    %
%   This code also creates JSON files for the FSL commands descripted    %
%   on the previous script (BIDS).                                       %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 20/02/2026                                                  %
%   Last update: 20/02/2026                                              %
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

%% Acquisition Parameters

% Echo Time 1: 0.00492 s
% Echo Time 2: 0.00738 s
% deltaTE: EchoTime2-EchoTime1 = 2.46 ms

% Echo Spacing: 0.56 ms = 0.00056 s

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

%% Regular subjects (with real magnitude)

% Example
% ----------- s05_01 -----------
%fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-01_phasediff.nii -div 2 fmap/sub-002_run-01_phasediff_half.nii
%bet rsub-006_run-01_magnitude.nii rsub-006_run-01_magnitude_brain.nii -f 0.5 -m
%fsl_prepare_fieldmap SIEMENS rsub-006_run-01_phasediff.nii rsub-006_run-01_magnitude_brain.nii fmap_rads_sub-006_run-01.nii.gz 2.46
% ----------- s05_02 -----------
% Open fmap_rads_sub-002_run-01.nii.gz to .nii
% Coregister (Estimate & Reslice) using Reference Image mean...a_sub-002...bold.nii and Source Image fmap_rads_sub-002_run-01.nii
% Output: rfmap_rads_sub-002_run-01.nii
% ----------- s05_03 -----------
%fugue -i rasub-006_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap_rads_sub-006_run-01.nii.gz --unwarpdir=y- -u urasub-006_task-main_run-01_bold.nii

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with rfmap run-02)

%% Special case: fake magnitude subjects

% The substitute/surrogate magnitude was already skull-stripped with SPM's native Segmentation tool.

% Example
% ----------- s05_01 -----------
%fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-01_phasediff.nii -div 2 fmap/sub-002_run-01_phasediff_half.nii
%fsl_prepare_fieldmap SIEMENS rsub-002_run-01_phasediff.nii sub-002_run-01_magnitude.nii fmap_rads_sub-002_run-01.nii.gz 2.46
% ----------- s05_02 -----------
% Open fmap_rads_sub-002_run-01.nii.gz to .nii
% Coregister (Estimate & Reslice) using Reference Image mean...a_sub-002...bold.nii and Source Image fmap_rads_sub-002_run-01.nii
% Output: rfmap_rads_sub-002_run-01.nii
% ----------- s05_03 -----------
%fugue -i rasub-002_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap_rads_sub-002_run-01.nii.gz --unwarpdir=y- -u urasub-002_task-main_run-01_bold.nii

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with rfmap run-02)

%% Final notices

% You can use the full paths to each file or, before running these scripts, change the terminal's directory using the 'cd' command
% (for example, cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-006/)

% In cases where there are magnitude1 and magnitude2, we manually chose the best option:
% MAGNITUDE 1:
% Sub-006: Runs – 2, 3, 6, 7  
% Sub-009: Runs – 1, 2, 3, 4 
% Sub-015: Runs – 2, 4, 5, 8
% Sub-019: Runs – 3, 4, 5, 7, 8 
% MAGNITUDE 2:
% Sub-009: Runs – 6, 8
%
% Additionally, while developing this script, I noticed that thosemagnitude1 and magnitude2 files had +1 voxel than the phasediff, 
% blocking the fsl_prepare_fieldmap. Those runs have an additional line (flirt), to cut the magnitude to the exact size of phasediff.
%
% flirt -in fmap/sub-006_run-02_magnitude_brain.nii -ref ../../../rawdata/sub-006/fmap/sub-006_run-02_phasediff.nii -applyxfm -usesqform -out fmap/sub-006_run-02_magnitude_brain_matched.nii
% flirt: the main options are an input (-in), a reference (-ref) volume, and output volume (-out) where the transform is applied to the 
% input volume to align it with the reference volume. To apply a transform that aligns the NIFTI mm coordinates: -applyxfm, -usesqform 
% and -out; but not -init). For these usage the reference volume must still be specified as this sets the voxel and image dimensions of 
% the resulting volume.

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data';
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% Align Fieldmaps

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Aligning rad/s fieldmaps for: %s\n', subj);
    
    fmap_dir = fullfile(deriv_dir,subj,'fmap');
    func_dir = fullfile(deriv_dir,subj,'func');

    % Find Mean Functional image (Reference)
    file_pattern = sprintf('mean*a%s_task-main_run-01_bold.nii', subj);
    mean_struct= dir(fullfile(func_dir,file_pattern));
    if isempty(mean_struct)
        fprintf('[ERROR] Missing Mean Functional Image for %s.\n',subj);
        continue;
    end
    mean_func = fullfile(func_dir,mean_struct(1).name);
    
    % Find all fmap_rads.nii.gz
    fmaps_gz = dir(fullfile(fmap_dir,'fmap_rads_*.nii.gz'));
    if isempty(fmaps_gz)
        fprintf('[Warning] No fmap_rads_*.nii.gz files found for %s.\n',subj);
        continue;
    end

    for p = 1:length(fmaps_gz)
        gz_file = fullfile(fmap_dir,fmaps_gz(p).name);

        fprintf('>> Unzipping and aligning: %s\n',fmaps_gz(p).name);
        
        % Unzip if the .nii doesn't exist yet
        nii_file = replace(gz_file,'.nii.gz','.nii');
        if ~exist(nii_file,'file')
            gunzip(gz_file);
        end

        [~,name_only,ext] = fileparts(nii_file);
        out_rfmap = fullfile(fmap_dir,['r' name_only ext]);
        out_json = fullfile(fmap_dir,['r' name_only '.json']);


        % ####################### SPM Batch #######################
        
        clear matlabbatch;
        matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {mean_func};
        matlabbatch{1}.spm.spatial.coreg.estwrite.source = {nii_file};
        matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
        matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
        matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
        matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
        matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
        matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
        matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
        matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
        matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
        
        try
            spm_jobman('run',matlabbatch);
            fprintf('Success! Creating JSON for BIDS compliance...\n');
            create_fmap_json(out_json,subj);
        catch ME
            fprintf('[ERROR] Alignment failed for %s: %s\n',fmaps_gz(p).name,ME.message);
        end
    end
end
fprintf('\nDone!\n');

%% Helper Functions

function create_fmap_json(target_json_path,subj)

json_data = struct();
json_data.Description = 'Coregistered Phase/Magnitude Fieldmap calculated in rad/s using FSL fsl_prepare_fieldmap';
json_data.Units = 'rad/s';
json_data.CoregisteredTo = sprintf('Mean Functional Image (mean*a%s_task-main_run-01_bold.nii)',subj);
json_data.Software = 'SPM12 (Coregistration) & FSL (Fieldmap Prep)';
json_data.Interpolation = '4th Degree B-Spline';

fake_mag_subjects = {'sub-002', 'sub-003', 'sub-004'};
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