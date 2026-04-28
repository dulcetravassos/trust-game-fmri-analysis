%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Segmentation (BIDS ready)                                            %
%                                                                        %
%   Partitions the coregistered anatomical image into different tissues  %
%   (Grey Matter, White Matter, CSF, etc.). Generates the spatial        %
%   deformation parameters (Forward Deformation Field, 'y_*') needed to  %
%   normalize both the anatomical and functional images to MNI space     %
%   later, and a bias-corrected structural image ('m*).                  %
%   This script also updates the JSON sidecar for the T1w image and      %
%   creates the corresponding sidecars for the segmentation outputs, for % 
%   BIDS compliance.                                                     %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 26/02/2026                                                  %
%   Last update: 28/04/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear all; clc;

%% Initial Configurations
% Change according to your preferences
% Note that some parameters may have to be changed inside the main loop

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

% Input and output directories
base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data';
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% Path to the tissue probability maps
tpm_path = fullfile(spm_path,'tpm','TPM.nii');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% Segmentation 

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Segmenting T1w for: %s\n', subj);
    
    anat_dir = fullfile(deriv_dir,subj,'anat');

    % T1w anatomical (previously coregistered)
    anat_file = fullfile(anat_dir,[subj '_T1w.nii']);
    if ~exist(anat_file,'file')
        fprintf('[ERROR] Missing T1w file for %s.\n',subj);
        continue;
    end
    
    % Original anat image JSON
    base_json = replace(anat_file,'.nii','.json');


    % ####################### SPM Batch #######################
    
    clear matlabbatch;
    matlabbatch{1}.spm.spatial.preproc.channel.vols = {anat_file};
    matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1]; % Save Bias Corrected (m*)
    % Grey Matter
    matlabbatch{1}.spm.spatial.preproc.tissue(1).tpm = {[tpm_path ',1']};
    matlabbatch{1}.spm.spatial.preproc.tissue(1).ngaus = 1;
    matlabbatch{1}.spm.spatial.preproc.tissue(1).native = [1 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(1).warped = [0 0];
    % White Matter
    matlabbatch{1}.spm.spatial.preproc.tissue(2).tpm = {[tpm_path ',2']};
    matlabbatch{1}.spm.spatial.preproc.tissue(2).ngaus = 1;
    matlabbatch{1}.spm.spatial.preproc.tissue(2).native = [1 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(2).warped = [0 0];
    % CSF
    matlabbatch{1}.spm.spatial.preproc.tissue(3).tpm = {[tpm_path ',3']};
    matlabbatch{1}.spm.spatial.preproc.tissue(3).ngaus = 2;
    matlabbatch{1}.spm.spatial.preproc.tissue(3).native = [1 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(3).warped = [0 0];
    % Skull/bones
    matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {[tpm_path ',4']};
    matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [1 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
    % Soft tissue
    matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {[tpm_path ',5']};
    matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [1 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
    % Air
    matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {[tpm_path ',6']};
    matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
    matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
    % Warping Parameters
    matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{1}.spm.spatial.preproc.warp.write = [0 1]; % Save Forward Deformation Field (y_*)
    matlabbatch{1}.spm.spatial.preproc.warp.vox = NaN;
    matlabbatch{1}.spm.spatial.preproc.warp.bb = [NaN NaN NaN
                                                  NaN NaN NaN];

    try
        spm_jobman('run',matlabbatch);
        fprintf('Success! Creating JSONs for BIDS compliance...\n');
        create_seg_json(anat_file,base_json);
    catch ME
        fprintf('[ERROR] Segmentation failed for %s: %s\n',subj,ME.message);
    end
end
fprintf('\nDone!\n');

%% Helper Functions

function create_seg_json(anat_file,base_json)

if exist(base_json,'file')
    content = fileread(base_json);
    try
        json_data = jsondecode(content);
    catch
        json_data = struct();
    end
else
    json_data = struct();
end

json_data.Segmentation = true;
json_data.Software = 'SPM12';
json_data.Description = 'Segmentation applied to coregistered T1w image';

[filepath, name, ~] = fileparts(anat_file);
output_files = {
    fullfile(filepath,['m' name '.json']); % bias corrected (new anat image)
    fullfile(filepath,['y_' name '.json']); % deformation fields
    fullfile(filepath,['c1' name '.json']); % grey matter
    fullfile(filepath,['c2' name '.json']); % white matter
    fullfile(filepath,['c3' name '.json']); % csf
    fullfile(filepath,['c4' name '.json']); % skull/bones
    fullfile(filepath,['c5' name '.json']); % soft tissue
    %fullfile(filepath,['c6' name '.json']); % air
    };

output_files{end+1} = base_json;

% Save .json files
for i=1:length(output_files)
    fid = fopen(output_files{i},'w');
    if fid==-1; warning('Could not save JSON file.'); continue; end
    fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
    fclose(fid);
end

end

