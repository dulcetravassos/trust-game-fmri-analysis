%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Set the Origin ([mostly] Manual step via SPM interface               %
%                                                                        %
%   Makes a copy of the raw anatomical image to the                      %
%   .../derivatives/spm-preprocessing/sub-00x/anat folder.               %
%   Then, opens SPM Display with the copied image and waits for the      %
%   user to set the origin to the Anterior Commissure (AC) and           %
%   horizontally aligned with the Posterior Commisure (PC). Finally,     %
%   updates the anatomical JSON file with SetOrigin = true (BIDS-        %
%   -friendly)                                                           %
%   This step is critical for successful Normalization later on.         %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 12/02/2026                                                  %
%   Last update: 28/04/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Setting the origin early-on, instead of later on (e.g., after Motion and
% Distortion Correction), is advantageous because it ensures that all
% subsequent spatial transformations start from a roughly correct
% alignment.

% The following code automatizes the copy of the anatomical image to the
% correct derivatives folder, opens the SPM interface and waits for the
% operation to be finished before updating the JSON file.

clear all; clc;

%% Initial Configurations
% Change according to your preferences

spm_path = 'C:\Users\User\Desktop\Tese\spm12';

base_dir = 'C:\Users\User\Desktop\Tese\data\spm-data';
% Input folder - raw anatomical
raw_dir = fullfile(base_dir,'rawdata');
% Output folder: /derivatives/spm-preprocessing (BIDS)
deriv_dir = fullfile(base_dir,'derivatives','spm-preprocessing');

% List of Subjects
subjects = {
    'sub-002', 'sub-003', 'sub-004', 'sub-006', 'sub-007', 'sub-008', ...
    'sub-009', 'sub-011', 'sub-012', 'sub-013', 'sub-014', 'sub-015', ...
    'sub-016', 'sub-017', 'sub-018', 'sub-019', 'sub-020', 'sub-021', ...
    'sub-022', 'sub-023'
};

%% Processing

if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

fprintf('Starting Manual Origin Set...\n');
input('Press ENTER to start looping through subjects...')

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n-------------- %s --------------\n',subj);

    % Paths
    raw_anat_nii = fullfile(raw_dir,subj,'anat',[subj '_T1w.nii']);
    raw_anat_json = fullfile(raw_dir,subj,'anat',[subj '_T1w.json']);
    deriv_folder = fullfile(deriv_dir,subj,'anat');
    deriv_anat_nii = fullfile(deriv_folder,[subj '_T1w.nii']);
    deriv_anat_json = fullfile(deriv_folder,[subj '_T1w.json']);

    if ~exist(raw_anat_nii,'file')
        fprintf('[WARNING] Raw file not found: %s\n', raw_anat_nii);
        continue;
    end
    
    if ~exist(deriv_folder, 'dir'); mkdir(deriv_folder); end
    
    if ~exist(deriv_anat_nii, 'file')
        copyfile(raw_anat_nii, deriv_anat_nii);
        fprintf('  -> Copied raw T1w to derivatives.\n');
    else
        fprintf('  -> Derivative file already exists in derivatives. Opening it...\n');
    end

    % ----------------- Manual Interaction - Set Origin -----------------
    fprintf('>>> Opening SPM Display...\n')
    spm_image('Display', deriv_anat_nii); % Opens the copied image and not the original!

    fprintf('ACTION REQUIRED: Set Origin to AC-PC -> Reorient Image -> Done.\n');
    input('>>> Press ENTER ONLY when you have saved the new origin! ');
    
    % Update JSON file
    update_json_anat(raw_anat_json, deriv_anat_json);
    fprintf('  -> JSON updated (SetOrigin=true).\n');

end

fprintf('\nAll done.\n');

%% Helper Functions

function update_json_anat(source_json_path,target_json_path)

if exist(source_json_path,'file')
    content = fileread(source_json_path);
    try
        json_data = jsondecode(content);
    catch
        json_data = struct();
    end
else
    json_data = struct(); % start new one
end

json_data.SetOrigin = true;
json_data.Sources = {source_json_path};

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end