%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Get Magnitude Substitute from Anatomical (T1w)                       %
%                                                                        %
%   To perform Distortion Correction on FSL FUGUE, we need complete      %
%   fieldmaps (magnitude + phase). For subjects missing the magnitude    %
%   files, this script generates a "fake magnitude" by skull-stripping   %
%   the T1w image and coregistering it to the Mean Functional image.     %
%   This step is not necessary if all subjects have complete fieldmaps.  % 
%   Also, creates a JSON file for this operation.                        %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 18/02/2026                                                  %
%   Last update: 19/02/2026                                              %
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

% List of Subjects WITHOUT magnitude files
subjects = {
    'sub-002', 'sub-003', 'sub-004'
};

%% Get Magnitude Substitute

% Initialize SPM
if isempty(which('spm')); addpath(spm_path); end
spm('defaults', 'FMRI');
spm_jobman('initcfg');

% Path to the tissue templates (needed for the Segmentation step)
tpm_path = fullfile(spm_path, 'tpm', 'TPM.nii');

for s = 1:length(subjects)
    subj = subjects{s};
    fprintf('\n==================================================\n');
    fprintf('Creating "fake" magnitude for: %s\n', subj);
    
    anat_dir = fullfile(deriv_dir,subj,'anat');
    func_dir = fullfile(deriv_dir,subj,'func');
    fmap_dir = fullfile(deriv_dir,subj,'fmap'); % Output folder

    if ~exist(fmap_dir,'dir'); mkdir(fmap_dir); end

    % High-Res anatomical image, with origin set
    t1_file = fullfile(anat_dir,[subj '_desc-defaced_T1w.nii']);
    if ~exist(t1_file,'file')
        fprintf('[ERROR] T1w not found: %s',t1_file);
        continue;
    end

    % Mean functional image from the Realignment step (Reference)
    file_pattern = sprintf('mean*a%s_task-main_run-01_bold.nii', subj);
    mean_struct= dir(fullfile(func_dir,file_pattern));
    if isempty(mean_struct)
        fprintf('[ERROR] Missing Mean Functional Image for %s.',subj);
        continue;
    end
    mean_func = fullfile(func_dir,mean_struct(1).name);
    
    
    % ####################### SPM Batches #######################

    % -------- Segmentation (skull strip preparation) --------
    fprintf('>>>>> Step 1: Segmentation...\n')
    
    clear matlabbatch;
    matlabbatch{1}.spm.spatial.preproc.channel.vols = {t1_file};
    matlabbatch{1}.spm.spatial.preproc.channel.biasreg = 0.001;
    matlabbatch{1}.spm.spatial.preproc.channel.biasfwhm = 60;
    matlabbatch{1}.spm.spatial.preproc.channel.write = [0 1]; % save bias-field corrected structural image (prefix m)
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
    % Other tissues (which we don't need native images)
    matlabbatch{1}.spm.spatial.preproc.tissue(4).tpm = {[tpm_path ',4']};
    matlabbatch{1}.spm.spatial.preproc.tissue(4).ngaus = 3;
    matlabbatch{1}.spm.spatial.preproc.tissue(4).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(4).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(5).tpm = {[tpm_path ',5']};
    matlabbatch{1}.spm.spatial.preproc.tissue(5).ngaus = 4;
    matlabbatch{1}.spm.spatial.preproc.tissue(5).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(5).warped = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(6).tpm = {[tpm_path ',6']};
    matlabbatch{1}.spm.spatial.preproc.tissue(6).ngaus = 2;
    matlabbatch{1}.spm.spatial.preproc.tissue(6).native = [0 0];
    matlabbatch{1}.spm.spatial.preproc.tissue(6).warped = [0 0];
    %
    matlabbatch{1}.spm.spatial.preproc.warp.mrf = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.cleanup = 1;
    matlabbatch{1}.spm.spatial.preproc.warp.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{1}.spm.spatial.preproc.warp.affreg = 'mni';
    matlabbatch{1}.spm.spatial.preproc.warp.fwhm = 0;
    matlabbatch{1}.spm.spatial.preproc.warp.samp = 3;
    matlabbatch{1}.spm.spatial.preproc.warp.write = [0 0]; % don't need deformations for now
    matlabbatch{1}.spm.spatial.preproc.warp.vox = NaN;
    matlabbatch{1}.spm.spatial.preproc.warp.bb = [NaN NaN NaN 
                                                  NaN NaN NaN];
    
    spm_jobman('run',matlabbatch);
    
    [filepath,name,ext] = fileparts(t1_file);
    m_t1 = fullfile(filepath, ['m' name ext]); % bias corrected
    c1 = fullfile(filepath, ['c1' name ext]); % grey matter
    c2 = fullfile(filepath, ['c2' name ext]); % white matter
    c3 = fullfile(filepath, ['c3' name ext]); % csf

    
    % -------- ImCalc (apply mask) --------
    fprintf('>>>>> Step 2: Skull stripping via ImCalc...\n')

    skull_stripped_t1 = fullfile(anat_dir,['brain_' name ext]);

    clear matlabbatch;
    matlabbatch{1}.spm.util.imcalc.input = {m_t1; c1; c2; c3};
    matlabbatch{1}.spm.util.imcalc.output = skull_stripped_t1;
    matlabbatch{1}.spm.util.imcalc.outdir = {anat_dir};
    matlabbatch{1}.spm.util.imcalc.expression = 'i1.*((i2+i3+i4)>0.5)'; % if the sum of the probabilities is less than 50%, it is considered 0
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
    
    spm_jobman('run',matlabbatch);

    
    % -------- Coregister and Reslice to Functional space --------
    fprintf('>>>>> Step 3: Coregistration to Functional...\n')

    final_mag_file = fullfile(fmap_dir,[subj '_run-01_magnitude.nii']); % following BIDS standard and matching the existing dataset pattern

    clear matlabbatch;
    matlabbatch{1}.spm.spatial.coreg.estwrite.ref = {mean_func};
    matlabbatch{1}.spm.spatial.coreg.estwrite.source = {skull_stripped_t1};
    matlabbatch{1}.spm.spatial.coreg.estwrite.other = {''};
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep = [4 2];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol = [0.02 0.02 0.02 0.001 0.001 0.001 0.01 0.01 0.01 0.001 0.001 0.001];
    matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm = [7 7];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask = 0;
    matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix = 'r';
  
    spm_jobman('run',matlabbatch);

    % Move and rename outputs
    [filepath_ss, name_ss, ext_ss] = fileparts(skull_stripped_t1);
    resliced_output = fullfile(filepath_ss, ['r' name_ss ext_ss]);
    if exist(resliced_output,'file')
        movefile(resliced_output,final_mag_file);
        fprintf('SUCCESS: Fake magnitude created at: %s\n',final_mag_file);
        % According to BIDS, it needs a JSON file
        t1_json = replace(t1_file,'.nii','.json');
        create_mag_json(t1_json,replace(final_mag_file,'.nii','.json'));

        % CLEAN THE INTERMEDIATE FILES IN THE FOLDER, NOT TO MESS WITH
        % LATER PROCESSING STAGES!
        fprintf('> Cleaning up intermediate files in anat folder...\n');
        files_to_delete = {m_t1,c1,c2,c3,skull_stripped_t1};
        for f=1:length(files_to_delete)
            if exist(files_to_delete{f},'file')
                delete(files_to_delete{f});
            end
        end
        mat_file = fullfile(filepath, [name '_seg8.mat']); % if there are any
        if exist(mat_file,'file'); delete(mat_file); end;
    else
        fprintf('[ERROR] Coregistration output not found...\n');
    end
end
fprintf('\nDone!\n');

%% Helper Functions

function create_mag_json(source_json_path,target_json_path)

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

json_data.Description = 'Magnitude Substitute/Surrogate Image derived from T1w for FSL FUGUE';
json_data.SkullStripped = true;
json_data.CoregisteredTo = 'Mean Functional Image';
json_data.Sources = {source_json_path};

% Save .json file
fid = fopen(target_json_path,'w');
if fid==-1; warning('Could not save JSON file.'); return; end
fprintf(fid,'%s',jsonencode(json_data,'PrettyPrint',true));
fclose(fid);
end