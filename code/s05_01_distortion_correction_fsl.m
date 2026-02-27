%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Distortion Correction - Preparation, Coregistration, Unwarping (FSL) %
%                                                                        %
%   This step is performed entirely using FSL via a WSL terminal.        %
%   First, "real" magnitudes are skull-stripped using FSL BET. Second,   %
%   fieldmaps are prepared in native space using fsl_prepare_fieldmaps   %
%   ('fmap_rads_*.nii.gz'). Magnitude images are coregistered to the     %
%   functional space using FSL FLIRT. This spatial transformation is     %
%   then applied to the fieldmaps (using spline interpolation) to create %
%   functionally-aligned fieldmaps ('rfmap_rads_*.nii.gz'). Finally,     %
%   FSL FUGUE applies these resliced fieldmaps to the previously         %
%   realigned BOLD images. The output is a new set of functional images  %
%   prefixed with 'u' (unwarped) corrected for B0 magnetic field         %
%   inhomogeneities.                                                     %
%   This script handles multiple magnitudes (magnitude1, magnitude2)     %
%   with matrix size mismatches and "fake" magnitudes derived from T1w   %
%   (see scrip s04) by applying a Gaussian smoothing (-s 2) on the       %
%   fieldmap to prevent ghost voxels.                                    %
%                                                                        %
%   To install FSL, follow the guide:                                    %
%   https://fsl.fmrib.ox.ac.uk/fsl/docs/install/windows.html             %
%                                                                        %
%   THIS SCRIPT SHOULD NOT BE RUN ON MATLAB. IT IS INTENDED TO COPY      %
%   AND PASTE DIRECTLY ON THE WSL INTERPRETER. The code is separated by  %
%   subject.                                                             %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 20/02/2026                                                  %
%   Last update: 26/02/2026                                              %
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
% Some commands are not described in the links above and were found by 
% typing the toolbox name in the Ubuntu terminal.

% IMPORTANT: THE FOLLOWING CODE IS BASH AND THEREFORE CANNOT BE RUN ON
% MATLAB. YOU SHOULD COPY THE CODE AND RUN IT ON A WSL LINUX INTERPRETER.

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

%% Regular subjects (with real magnitude)

% Example
% ----------- s05_01 -----------
bet ../../../rawdata/sub-006/fmap/sub-006_run-01_magnitude.nii fmap/sub-006_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-01_phasediff.nii -div 2 fmap/sub-006_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-01_phasediff_half.nii.gz fmap/sub-006_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-006_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-01.nii.gz -nan fmap/fmap_rads_sub-006_run-01.nii.gz
flirt -in fmap/sub-006_run-01_magnitude_brain.nii.gz -ref func/rasub-006_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-006_run-01.nii.gz -ref func/rasub-006_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-006_run-01.nii.gz
fugue -i func/rasub-006_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-01.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-01_bold.nii.gz -v
% ----------- s05_02 -----------
% Unzip rfmap* and ura* files and create JSONs (BIDS-compliant)

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with fmap run-02)

%% Special case: fake magnitude subjects

% The substitute/surrogate magnitude was already skull-stripped with SPM's native Segmentation tool.

% Example
% ----------- s05_01 -----------
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-01_phasediff.nii -div 2 fmap/sub-002_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-01_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-01.nii.gz -nan fmap/fmap_rads_sub-002_run-01.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-01.nii.gz -s 2 fmap/fmap_rads_sub-002_run-01.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-002_run-01.nii.gz -ref func/rasub-002_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-002_run-01.nii.gz
fugue -i func/rasub-002_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-01.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-01_bold.nii.gz -v
% ----------- s05_02 -----------
% Unzip rfmap* and ura* files and create JSONs (BIDS-compliant)

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with fmap run-02)

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
% flirt -in fmap/sub-006_run-01_magnitude_brain.nii.gz -ref func/rasub-006_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
% flirt -in fmap/fmap_rads_sub-006_run-01.nii.gz -ref func/rasub-006_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-006_run-01.nii.gz
% flirt: used for registration, the main options are an input (-in), a reference (-ref) volume, the calculated affine transformation that registers 
% the input to the reference which is saved as a 4x4 affine matrix (-omat), and output volume (-out) where the transform  is applied to the input 
% volume to align it with the reference volume. To apply a saved transformation to a volume: -applyxfm, -init and -out. For these usage the reference 
% volume must still be specified as this sets the voxel and image dimensions of the resulting volume.

% fslmaths fmap/fmap_rads_sub-008_run-01.nii -nan fmap/fmap_rads_sub-008_run-01.nii
% replaces NaNs with 0

% fslmaths fmap/fmap_rads_sub-002_run-01.nii.gz -s 2 fmap/fmap_rads_sub-002_run-01.nii.gz
% for subjects with fake magnitudes, we perform smoothing to eliminate "phantom voxels" outside the brain

%% SUB-002

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-002

# RUN-01
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-01_phasediff.nii -div 2 fmap/sub-002_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-01_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-01.nii.gz -nan fmap/fmap_rads_sub-002_run-01.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-01.nii.gz -s 2 fmap/fmap_rads_sub-002_run-01.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-002_run-01.nii.gz -ref func/rasub-002_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-002_run-01.nii.gz
fugue -i func/rasub-002_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-01.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-01_bold.nii.gz -v

# RUN-02
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-02_phasediff.nii -div 2 fmap/sub-002_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-02_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-02.nii.gz -nan fmap/fmap_rads_sub-002_run-02.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-02.nii.gz -s 2 fmap/fmap_rads_sub-002_run-02.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-002_run-02.nii.gz -ref func/rasub-002_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-002_run-02.nii.gz
fugue -i func/rasub-002_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-02.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-02_bold.nii.gz -v

# RUN-03
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-03_phasediff.nii -div 2 fmap/sub-002_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-03_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-03.nii.gz -nan fmap/fmap_rads_sub-002_run-03.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-03.nii.gz -s 2 fmap/fmap_rads_sub-002_run-03.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-002_run-03.nii.gz -ref func/rasub-002_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-002_run-03.nii.gz
fugue -i func/rasub-002_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-03.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-03_bold.nii.gz -v

# RUN-04
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-04_phasediff.nii -div 2 fmap/sub-002_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-04_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-04.nii.gz -nan fmap/fmap_rads_sub-002_run-04.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-04.nii.gz -s 2 fmap/fmap_rads_sub-002_run-04.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-002_run-04.nii.gz -ref func/rasub-002_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-002_run-04.nii.gz
fugue -i func/rasub-002_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-04.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-04_bold.nii.gz -v

# RUN-05
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-05_phasediff.nii -div 2 fmap/sub-002_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-05_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-05.nii.gz -nan fmap/fmap_rads_sub-002_run-05.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-05.nii.gz -s 2 fmap/fmap_rads_sub-002_run-05.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-002_run-05.nii.gz -ref func/rasub-002_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-002_run-05.nii.gz
fugue -i func/rasub-002_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-05.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-05_bold.nii.gz -v

# RUN-06
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-06_phasediff.nii -div 2 fmap/sub-002_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-06_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-06.nii.gz -nan fmap/fmap_rads_sub-002_run-06.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-06.nii.gz -s 2 fmap/fmap_rads_sub-002_run-06.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-002_run-06.nii.gz -ref func/rasub-002_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-002_run-06.nii.gz
fugue -i func/rasub-002_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-06.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-06_bold.nii.gz -v

# RUN-07
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-07_phasediff.nii -div 2 fmap/sub-002_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-07_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-07.nii.gz -nan fmap/fmap_rads_sub-002_run-07.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-07.nii.gz -s 2 fmap/fmap_rads_sub-002_run-07.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-002_run-07.nii.gz -ref func/rasub-002_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-002_run-07.nii.gz
fugue -i func/rasub-002_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-07.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-07_bold.nii.gz -v

# RUN-08
fslmaths ../../../rawdata/sub-002/fmap/sub-002_run-08_phasediff.nii -div 2 fmap/sub-002_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-002_run-08_phasediff_half.nii.gz fmap/sub-002_run-01_magnitude.nii fmap/fmap_rads_sub-002_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-002_run-08.nii.gz -nan fmap/fmap_rads_sub-002_run-08.nii.gz
fslmaths fmap/fmap_rads_sub-002_run-08.nii.gz -s 2 fmap/fmap_rads_sub-002_run-08.nii.gz
flirt -in fmap/sub-002_run-01_magnitude.nii -ref func/rasub-002_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-002_run-08.nii.gz -ref func/rasub-002_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-002_run-08.nii.gz
fugue -i func/rasub-002_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-002_run-08.nii.gz --unwarpdir=y- -u func/urasub-002_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-002_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-002_run-01.nii.gz --unwarpdir=y- -u func/urasub-002_task-localizer_bold.nii.gz -v

%% SUB-003

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-003

# RUN-01
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-01_phasediff.nii -div 2 fmap/sub-003_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-01_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-01.nii.gz -nan fmap/fmap_rads_sub-003_run-01.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-01.nii.gz -s 2 fmap/fmap_rads_sub-003_run-01.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-003_run-01.nii.gz -ref func/rasub-003_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-003_run-01.nii.gz
fugue -i func/rasub-003_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-01.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-01_bold.nii.gz -v

# RUN-02
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-02_phasediff.nii -div 2 fmap/sub-003_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-02_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-02.nii.gz -nan fmap/fmap_rads_sub-003_run-02.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-02.nii.gz -s 2 fmap/fmap_rads_sub-003_run-02.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-003_run-02.nii.gz -ref func/rasub-003_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-003_run-02.nii.gz
fugue -i func/rasub-003_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-02.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-02_bold.nii.gz -v

# RUN-03
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-03_phasediff.nii -div 2 fmap/sub-003_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-03_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-03.nii.gz -nan fmap/fmap_rads_sub-003_run-03.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-03.nii.gz -s 2 fmap/fmap_rads_sub-003_run-03.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-003_run-03.nii.gz -ref func/rasub-003_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-003_run-03.nii.gz
fugue -i func/rasub-003_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-03.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-03_bold.nii.gz -v

# RUN-04
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-04_phasediff.nii -div 2 fmap/sub-003_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-04_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-04.nii.gz -nan fmap/fmap_rads_sub-003_run-04.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-04.nii.gz -s 2 fmap/fmap_rads_sub-003_run-04.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-003_run-04.nii.gz -ref func/rasub-003_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-003_run-04.nii.gz
fugue -i func/rasub-003_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-04.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-04_bold.nii.gz -v

# RUN-05
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-05_phasediff.nii -div 2 fmap/sub-003_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-05_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-05.nii.gz -nan fmap/fmap_rads_sub-003_run-05.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-05.nii.gz -s 2 fmap/fmap_rads_sub-003_run-05.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-003_run-05.nii.gz -ref func/rasub-003_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-003_run-05.nii.gz
fugue -i func/rasub-003_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-05.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-05_bold.nii.gz -v

# RUN-06
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-06_phasediff.nii -div 2 fmap/sub-003_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-06_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-06.nii.gz -nan fmap/fmap_rads_sub-003_run-06.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-06.nii.gz -s 2 fmap/fmap_rads_sub-003_run-06.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-003_run-06.nii.gz -ref func/rasub-003_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-003_run-06.nii.gz
fugue -i func/rasub-003_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-06.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-06_bold.nii.gz -v

# RUN-07
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-07_phasediff.nii -div 2 fmap/sub-003_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-07_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-07.nii.gz -nan fmap/fmap_rads_sub-003_run-07.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-07.nii.gz -s 2 fmap/fmap_rads_sub-003_run-07.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-003_run-07.nii.gz -ref func/rasub-003_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-003_run-07.nii.gz
fugue -i func/rasub-003_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-07.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-07_bold.nii.gz -v

# RUN-08
fslmaths ../../../rawdata/sub-003/fmap/sub-003_run-08_phasediff.nii -div 2 fmap/sub-003_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-003_run-08_phasediff_half.nii.gz fmap/sub-003_run-01_magnitude.nii fmap/fmap_rads_sub-003_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-003_run-08.nii.gz -nan fmap/fmap_rads_sub-003_run-08.nii.gz
fslmaths fmap/fmap_rads_sub-003_run-08.nii.gz -s 2 fmap/fmap_rads_sub-003_run-08.nii.gz
flirt -in fmap/sub-003_run-01_magnitude.nii -ref func/rasub-003_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-003_run-08.nii.gz -ref func/rasub-003_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-003_run-08.nii.gz
fugue -i func/rasub-003_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-003_run-08.nii.gz --unwarpdir=y- -u func/urasub-003_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-003_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-003_run-01.nii.gz --unwarpdir=y- -u func/urasub-003_task-localizer_bold.nii.gz -v

%% SUB-004

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-004

# RUN-01
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-01_phasediff.nii -div 2 fmap/sub-004_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-01_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-01.nii.gz -nan fmap/fmap_rads_sub-004_run-01.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-01.nii.gz -s 2 fmap/fmap_rads_sub-004_run-01.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-004_run-01.nii.gz -ref func/rasub-004_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-004_run-01.nii.gz
fugue -i func/rasub-004_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-01.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-01_bold.nii.gz -v

# RUN-02
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-02_phasediff.nii -div 2 fmap/sub-004_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-02_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-02.nii.gz -nan fmap/fmap_rads_sub-004_run-02.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-02.nii.gz -s 2 fmap/fmap_rads_sub-004_run-02.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-004_run-02.nii.gz -ref func/rasub-004_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-004_run-02.nii.gz
fugue -i func/rasub-004_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-02.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-02_bold.nii.gz -v

# RUN-03
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-03_phasediff.nii -div 2 fmap/sub-004_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-03_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-03.nii.gz -nan fmap/fmap_rads_sub-004_run-03.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-03.nii.gz -s 2 fmap/fmap_rads_sub-004_run-03.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-004_run-03.nii.gz -ref func/rasub-004_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-004_run-03.nii.gz
fugue -i func/rasub-004_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-03.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-03_bold.nii.gz -v

# RUN-04
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-04_phasediff.nii -div 2 fmap/sub-004_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-04_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-04.nii.gz -nan fmap/fmap_rads_sub-004_run-04.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-04.nii.gz -s 2 fmap/fmap_rads_sub-004_run-04.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-004_run-04.nii.gz -ref func/rasub-004_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-004_run-04.nii.gz
fugue -i func/rasub-004_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-04.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-04_bold.nii.gz -v

# RUN-05
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-05_phasediff.nii -div 2 fmap/sub-004_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-05_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-05.nii.gz -nan fmap/fmap_rads_sub-004_run-05.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-05.nii.gz -s 2 fmap/fmap_rads_sub-004_run-05.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-004_run-05.nii.gz -ref func/rasub-004_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-004_run-05.nii.gz
fugue -i func/rasub-004_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-05.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-05_bold.nii.gz -v

# RUN-06
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-06_phasediff.nii -div 2 fmap/sub-004_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-06_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-06.nii.gz -nan fmap/fmap_rads_sub-004_run-06.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-06.nii.gz -s 2 fmap/fmap_rads_sub-004_run-06.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-004_run-06.nii.gz -ref func/rasub-004_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-004_run-06.nii.gz
fugue -i func/rasub-004_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-06.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-06_bold.nii.gz -v

# RUN-07
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-07_phasediff.nii -div 2 fmap/sub-004_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-07_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-07.nii.gz -nan fmap/fmap_rads_sub-004_run-07.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-07.nii.gz -s 2 fmap/fmap_rads_sub-004_run-07.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-004_run-07.nii.gz -ref func/rasub-004_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-004_run-07.nii.gz
fugue -i func/rasub-004_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-07.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-07_bold.nii.gz -v

# RUN-08
fslmaths ../../../rawdata/sub-004/fmap/sub-004_run-08_phasediff.nii -div 2 fmap/sub-004_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-004_run-08_phasediff_half.nii.gz fmap/sub-004_run-01_magnitude.nii fmap/fmap_rads_sub-004_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-004_run-08.nii.gz -nan fmap/fmap_rads_sub-004_run-08.nii.gz
fslmaths fmap/fmap_rads_sub-004_run-08.nii.gz -s 2 fmap/fmap_rads_sub-004_run-08.nii.gz
flirt -in fmap/sub-004_run-01_magnitude.nii -ref func/rasub-004_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-004_run-08.nii.gz -ref func/rasub-004_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-004_run-08.nii.gz
fugue -i func/rasub-004_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-004_run-08.nii.gz --unwarpdir=y- -u func/urasub-004_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-004_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-004_run-01.nii.gz --unwarpdir=y- -u func/urasub-004_task-localizer_bold.nii.gz -v

%% SUB-006

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-006

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-006/fmap/sub-006_run-01_magnitude.nii fmap/sub-006_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-01_phasediff.nii -div 2 fmap/sub-006_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-01_phasediff_half.nii.gz fmap/sub-006_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-006_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-01.nii.gz -nan fmap/fmap_rads_sub-006_run-01.nii.gz
flirt -in fmap/sub-006_run-01_magnitude_brain.nii.gz -ref func/rasub-006_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-006_run-01.nii.gz -ref func/rasub-006_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-006_run-01.nii.gz
fugue -i func/rasub-006_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-01.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-006/fmap/sub-006_run-02_magnitude1.nii fmap/sub-006_run-02_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-006_run-02_magnitude_brain.nii.gz -ref ../../../rawdata/sub-006/fmap/sub-006_run-02_phasediff.nii -applyxfm -usesqform -out fmap/sub-006_run-02_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-02_phasediff.nii -div 2 fmap/sub-006_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-02_phasediff_half.nii.gz fmap/sub-006_run-02_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-006_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-02.nii.gz -nan fmap/fmap_rads_sub-006_run-02.nii.gz
flirt -in fmap/sub-006_run-02_magnitude_brain_matched.nii.gz -ref func/rasub-006_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-006_run-02.nii.gz -ref func/rasub-006_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-006_run-02.nii.gz
fugue -i func/rasub-006_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-02.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-006/fmap/sub-006_run-03_magnitude1.nii fmap/sub-006_run-03_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-006_run-03_magnitude_brain.nii.gz -ref ../../../rawdata/sub-006/fmap/sub-006_run-03_phasediff.nii -applyxfm -usesqform -out fmap/sub-006_run-03_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-03_phasediff.nii -div 2 fmap/sub-006_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-03_phasediff_half.nii.gz fmap/sub-006_run-03_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-006_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-03.nii.gz -nan fmap/fmap_rads_sub-006_run-03.nii.gz
flirt -in fmap/sub-006_run-03_magnitude_brain_matched.nii.gz -ref func/rasub-006_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-006_run-03.nii.gz -ref func/rasub-006_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-006_run-03.nii.gz
fugue -i func/rasub-006_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-03.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-006/fmap/sub-006_run-04_magnitude.nii fmap/sub-006_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-04_phasediff.nii -div 2 fmap/sub-006_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-04_phasediff_half.nii.gz fmap/sub-006_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-006_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-04.nii.gz -nan fmap/fmap_rads_sub-006_run-04.nii.gz
flirt -in fmap/sub-006_run-04_magnitude_brain.nii.gz -ref func/rasub-006_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-006_run-04.nii.gz -ref func/rasub-006_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-006_run-04.nii.gz
fugue -i func/rasub-006_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-04.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-006/fmap/sub-006_run-05_magnitude.nii fmap/sub-006_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-05_phasediff.nii -div 2 fmap/sub-006_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-05_phasediff_half.nii.gz fmap/sub-006_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-006_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-05.nii.gz -nan fmap/fmap_rads_sub-006_run-05.nii.gz
flirt -in fmap/sub-006_run-05_magnitude_brain.nii.gz -ref func/rasub-006_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-006_run-05.nii.gz -ref func/rasub-006_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-006_run-05.nii.gz
fugue -i func/rasub-006_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-05.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-006/fmap/sub-006_run-06_magnitude1.nii fmap/sub-006_run-06_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-006_run-06_magnitude_brain.nii.gz -ref ../../../rawdata/sub-006/fmap/sub-006_run-06_phasediff.nii -applyxfm -usesqform -out fmap/sub-006_run-06_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-06_phasediff.nii -div 2 fmap/sub-006_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-06_phasediff_half.nii.gz fmap/sub-006_run-06_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-006_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-06.nii.gz -nan fmap/fmap_rads_sub-006_run-06.nii.gz
flirt -in fmap/sub-006_run-06_magnitude_brain_matched.nii.gz -ref func/rasub-006_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-006_run-06.nii.gz -ref func/rasub-006_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-006_run-06.nii.gz
fugue -i func/rasub-006_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-06.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-006/fmap/sub-006_run-07_magnitude1.nii fmap/sub-006_run-07_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-006_run-07_magnitude_brain.nii.gz -ref ../../../rawdata/sub-006/fmap/sub-006_run-07_phasediff.nii -applyxfm -usesqform -out fmap/sub-006_run-07_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-07_phasediff.nii -div 2 fmap/sub-006_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-07_phasediff_half.nii.gz fmap/sub-006_run-07_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-006_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-07.nii.gz -nan fmap/fmap_rads_sub-006_run-07.nii.gz
flirt -in fmap/sub-006_run-07_magnitude_brain_matched.nii.gz -ref func/rasub-006_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-006_run-07.nii.gz -ref func/rasub-006_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-006_run-07.nii.gz
fugue -i func/rasub-006_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-07.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-006/fmap/sub-006_run-08_magnitude.nii fmap/sub-006_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-006/fmap/sub-006_run-08_phasediff.nii -div 2 fmap/sub-006_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-006_run-08_phasediff_half.nii.gz fmap/sub-006_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-006_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-006_run-08.nii.gz -nan fmap/fmap_rads_sub-006_run-08.nii.gz
flirt -in fmap/sub-006_run-08_magnitude_brain.nii.gz -ref func/rasub-006_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-006_run-08.nii.gz -ref func/rasub-006_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-006_run-08.nii.gz
fugue -i func/rasub-006_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-006_run-08.nii.gz --unwarpdir=y- -u func/urasub-006_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-006_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-006_run-01.nii.gz --unwarpdir=y- -u func/urasub-006_task-localizer_bold.nii.gz -v

%% SUB-007

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-007

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-007/fmap/sub-007_run-01_magnitude.nii fmap/sub-007_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-01_phasediff.nii -div 2 fmap/sub-007_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-01_phasediff_half.nii.gz fmap/sub-007_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-01.nii.gz -nan fmap/fmap_rads_sub-007_run-01.nii.gz
flirt -in fmap/sub-007_run-01_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-007_run-01.nii.gz -ref func/rasub-007_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-007_run-01.nii.gz
fugue -i func/rasub-007_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-01.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-007/fmap/sub-007_run-02_magnitude.nii fmap/sub-007_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-02_phasediff.nii -div 2 fmap/sub-007_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-02_phasediff_half.nii.gz fmap/sub-007_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-02.nii.gz -nan fmap/fmap_rads_sub-007_run-02.nii.gz
flirt -in fmap/sub-007_run-02_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-007_run-02.nii.gz -ref func/rasub-007_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-007_run-02.nii.gz
fugue -i func/rasub-007_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-02.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-007/fmap/sub-007_run-03_magnitude.nii fmap/sub-007_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-03_phasediff.nii -div 2 fmap/sub-007_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-03_phasediff_half.nii.gz fmap/sub-007_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-03.nii.gz -nan fmap/fmap_rads_sub-007_run-03.nii.gz
flirt -in fmap/sub-007_run-03_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-007_run-03.nii.gz -ref func/rasub-007_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-007_run-03.nii.gz
fugue -i func/rasub-007_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-03.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-007/fmap/sub-007_run-04_magnitude.nii fmap/sub-007_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-04_phasediff.nii -div 2 fmap/sub-007_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-04_phasediff_half.nii.gz fmap/sub-007_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-04.nii.gz -nan fmap/fmap_rads_sub-007_run-04.nii.gz
flirt -in fmap/sub-007_run-04_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-007_run-04.nii.gz -ref func/rasub-007_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-007_run-04.nii.gz
fugue -i func/rasub-007_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-04.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-007/fmap/sub-007_run-05_magnitude.nii fmap/sub-007_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-05_phasediff.nii -div 2 fmap/sub-007_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-05_phasediff_half.nii.gz fmap/sub-007_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-05.nii.gz -nan fmap/fmap_rads_sub-007_run-05.nii.gz
flirt -in fmap/sub-007_run-05_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-007_run-05.nii.gz -ref func/rasub-007_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-007_run-05.nii.gz
fugue -i func/rasub-007_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-05.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-007/fmap/sub-007_run-06_magnitude.nii fmap/sub-007_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-06_phasediff.nii -div 2 fmap/sub-007_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-06_phasediff_half.nii.gz fmap/sub-007_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-06.nii.gz -nan fmap/fmap_rads_sub-007_run-06.nii.gz
flirt -in fmap/sub-007_run-06_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-007_run-06.nii.gz -ref func/rasub-007_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-007_run-06.nii.gz
fugue -i func/rasub-007_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-06.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-007/fmap/sub-007_run-07_magnitude.nii fmap/sub-007_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-07_phasediff.nii -div 2 fmap/sub-007_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-07_phasediff_half.nii.gz fmap/sub-007_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-07.nii.gz -nan fmap/fmap_rads_sub-007_run-07.nii.gz
flirt -in fmap/sub-007_run-07_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-007_run-07.nii.gz -ref func/rasub-007_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-007_run-07.nii.gz
fugue -i func/rasub-007_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-07.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-007/fmap/sub-007_run-08_magnitude.nii fmap/sub-007_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-007/fmap/sub-007_run-08_phasediff.nii -div 2 fmap/sub-007_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-007_run-08_phasediff_half.nii.gz fmap/sub-007_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-007_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-007_run-08.nii.gz -nan fmap/fmap_rads_sub-007_run-08.nii.gz
flirt -in fmap/sub-007_run-08_magnitude_brain.nii.gz -ref func/rasub-007_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-007_run-08.nii.gz -ref func/rasub-007_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-007_run-08.nii.gz
fugue -i func/rasub-007_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-007_run-08.nii.gz --unwarpdir=y- -u func/urasub-007_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-007_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-007_run-01.nii.gz --unwarpdir=y- -u func/urasub-007_task-localizer_bold.nii.gz -v

%% SUB-008

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-008

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-008/fmap/sub-008_run-01_magnitude.nii fmap/sub-008_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-01_phasediff.nii -div 2 fmap/sub-008_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-01_phasediff_half.nii.gz fmap/sub-008_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-01.nii.gz -nan fmap/fmap_rads_sub-008_run-01.nii.gz
flirt -in fmap/sub-008_run-01_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-008_run-01.nii.gz -ref func/rasub-008_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-008_run-01.nii.gz
fugue -i func/rasub-008_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-01.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-008/fmap/sub-008_run-02_magnitude.nii fmap/sub-008_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-02_phasediff.nii -div 2 fmap/sub-008_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-02_phasediff_half.nii.gz fmap/sub-008_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-02.nii.gz -nan fmap/fmap_rads_sub-008_run-02.nii.gz
flirt -in fmap/sub-008_run-02_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-008_run-02.nii.gz -ref func/rasub-008_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-008_run-02.nii.gz
fugue -i func/rasub-008_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-02.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-008/fmap/sub-008_run-03_magnitude.nii fmap/sub-008_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-03_phasediff.nii -div 2 fmap/sub-008_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-03_phasediff_half.nii.gz fmap/sub-008_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-03.nii.gz -nan fmap/fmap_rads_sub-008_run-03.nii.gz
flirt -in fmap/sub-008_run-03_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-008_run-03.nii.gz -ref func/rasub-008_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-008_run-03.nii.gz
fugue -i func/rasub-008_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-03.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-008/fmap/sub-008_run-04_magnitude.nii fmap/sub-008_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-04_phasediff.nii -div 2 fmap/sub-008_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-04_phasediff_half.nii.gz fmap/sub-008_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-04.nii.gz -nan fmap/fmap_rads_sub-008_run-04.nii.gz
flirt -in fmap/sub-008_run-04_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-008_run-04.nii.gz -ref func/rasub-008_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-008_run-04.nii.gz
fugue -i func/rasub-008_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-04.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-008/fmap/sub-008_run-05_magnitude.nii fmap/sub-008_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-05_phasediff.nii -div 2 fmap/sub-008_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-05_phasediff_half.nii.gz fmap/sub-008_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-05.nii.gz -nan fmap/fmap_rads_sub-008_run-05.nii.gz
flirt -in fmap/sub-008_run-05_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-008_run-05.nii.gz -ref func/rasub-008_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-008_run-05.nii.gz
fugue -i func/rasub-008_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-05.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-008/fmap/sub-008_run-06_magnitude.nii fmap/sub-008_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-06_phasediff.nii -div 2 fmap/sub-008_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-06_phasediff_half.nii.gz fmap/sub-008_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-06.nii.gz -nan fmap/fmap_rads_sub-008_run-06.nii.gz
flirt -in fmap/sub-008_run-06_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-008_run-06.nii.gz -ref func/rasub-008_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-008_run-06.nii.gz
fugue -i func/rasub-008_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-06.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-008/fmap/sub-008_run-07_magnitude.nii fmap/sub-008_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-07_phasediff.nii -div 2 fmap/sub-008_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-07_phasediff_half.nii.gz fmap/sub-008_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-07.nii.gz -nan fmap/fmap_rads_sub-008_run-07.nii.gz
flirt -in fmap/sub-008_run-07_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-008_run-07.nii.gz -ref func/rasub-008_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-008_run-07.nii.gz
fugue -i func/rasub-008_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-07.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-008/fmap/sub-008_run-08_magnitude.nii fmap/sub-008_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-008/fmap/sub-008_run-08_phasediff.nii -div 2 fmap/sub-008_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-008_run-08_phasediff_half.nii.gz fmap/sub-008_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-008_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-008_run-08.nii.gz -nan fmap/fmap_rads_sub-008_run-08.nii.gz
flirt -in fmap/sub-008_run-08_magnitude_brain.nii.gz -ref func/rasub-008_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-008_run-08.nii.gz -ref func/rasub-008_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-008_run-08.nii.gz
fugue -i func/rasub-008_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-008_run-08.nii.gz --unwarpdir=y- -u func/urasub-008_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-008_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-008_run-01.nii.gz --unwarpdir=y- -u func/urasub-008_task-localizer_bold.nii.gz -v

%% SUB-009

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-009

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-009/fmap/sub-009_run-01_magnitude1.nii fmap/sub-009_run-01_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-009_run-01_magnitude_brain.nii.gz -ref ../../../rawdata/sub-009/fmap/sub-009_run-01_phasediff.nii -applyxfm -usesqform -out fmap/sub-009_run-01_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-01_phasediff.nii -div 2 fmap/sub-009_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-01_phasediff_half.nii.gz fmap/sub-009_run-01_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-009_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-01.nii.gz -nan fmap/fmap_rads_sub-009_run-01.nii.gz
flirt -in fmap/sub-009_run-01_magnitude_brain_matched.nii.gz -ref func/rasub-009_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-009_run-01.nii.gz -ref func/rasub-009_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-009_run-01.nii.gz
fugue -i func/rasub-009_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-01.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-009/fmap/sub-009_run-02_magnitude1.nii fmap/sub-009_run-02_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-009_run-02_magnitude_brain.nii.gz -ref ../../../rawdata/sub-009/fmap/sub-009_run-02_phasediff.nii -applyxfm -usesqform -out fmap/sub-009_run-02_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-02_phasediff.nii -div 2 fmap/sub-009_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-02_phasediff_half.nii.gz fmap/sub-009_run-02_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-009_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-02.nii.gz -nan fmap/fmap_rads_sub-009_run-02.nii.gz
flirt -in fmap/sub-009_run-02_magnitude_brain_matched.nii.gz -ref func/rasub-009_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-009_run-02.nii.gz -ref func/rasub-009_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-009_run-02.nii.gz
fugue -i func/rasub-009_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-02.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-009/fmap/sub-009_run-03_magnitude1.nii fmap/sub-009_run-03_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-009_run-03_magnitude_brain.nii.gz -ref ../../../rawdata/sub-009/fmap/sub-009_run-03_phasediff.nii -applyxfm -usesqform -out fmap/sub-009_run-03_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-03_phasediff.nii -div 2 fmap/sub-009_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-03_phasediff_half.nii.gz fmap/sub-009_run-03_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-009_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-03.nii.gz -nan fmap/fmap_rads_sub-009_run-03.nii.gz
flirt -in fmap/sub-009_run-03_magnitude_brain_matched.nii.gz -ref func/rasub-009_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-009_run-03.nii.gz -ref func/rasub-009_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-009_run-03.nii.gz
fugue -i func/rasub-009_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-03.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-009/fmap/sub-009_run-04_magnitude1.nii fmap/sub-009_run-04_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-009_run-04_magnitude_brain.nii.gz -ref ../../../rawdata/sub-009/fmap/sub-009_run-04_phasediff.nii -applyxfm -usesqform -out fmap/sub-009_run-04_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-04_phasediff.nii -div 2 fmap/sub-009_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-04_phasediff_half.nii.gz fmap/sub-009_run-04_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-009_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-04.nii.gz -nan fmap/fmap_rads_sub-009_run-04.nii.gz
flirt -in fmap/sub-009_run-04_magnitude_brain_matched.nii.gz -ref func/rasub-009_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-009_run-04.nii.gz -ref func/rasub-009_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-009_run-04.nii.gz
fugue -i func/rasub-009_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-04.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-009/fmap/sub-009_run-05_magnitude.nii fmap/sub-009_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-05_phasediff.nii -div 2 fmap/sub-009_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-05_phasediff_half.nii.gz fmap/sub-009_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-009_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-05.nii.gz -nan fmap/fmap_rads_sub-009_run-05.nii.gz
flirt -in fmap/sub-009_run-05_magnitude_brain.nii.gz -ref func/rasub-009_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-009_run-05.nii.gz -ref func/rasub-009_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-009_run-05.nii.gz
fugue -i func/rasub-009_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-05.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-009/fmap/sub-009_run-06_magnitude2.nii fmap/sub-009_run-06_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-009_run-06_magnitude_brain.nii.gz -ref ../../../rawdata/sub-009/fmap/sub-009_run-06_phasediff.nii -applyxfm -usesqform -out fmap/sub-009_run-06_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-06_phasediff.nii -div 2 fmap/sub-009_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-06_phasediff_half.nii.gz fmap/sub-009_run-06_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-009_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-06.nii.gz -nan fmap/fmap_rads_sub-009_run-06.nii.gz
flirt -in fmap/sub-009_run-06_magnitude_brain_matched.nii.gz -ref func/rasub-009_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-009_run-06.nii.gz -ref func/rasub-009_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-009_run-06.nii.gz
fugue -i func/rasub-009_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-06.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-009/fmap/sub-009_run-07_magnitude.nii fmap/sub-009_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-07_phasediff.nii -div 2 fmap/sub-009_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-07_phasediff_half.nii.gz fmap/sub-009_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-009_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-07.nii.gz -nan fmap/fmap_rads_sub-009_run-07.nii.gz
flirt -in fmap/sub-009_run-07_magnitude_brain.nii.gz -ref func/rasub-009_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-009_run-07.nii.gz -ref func/rasub-009_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-009_run-07.nii.gz
fugue -i func/rasub-009_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-07.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-009/fmap/sub-009_run-08_magnitude2.nii fmap/sub-009_run-08_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-009_run-08_magnitude_brain.nii.gz -ref ../../../rawdata/sub-009/fmap/sub-009_run-08_phasediff.nii -applyxfm -usesqform -out fmap/sub-009_run-08_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-009/fmap/sub-009_run-08_phasediff.nii -div 2 fmap/sub-009_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-009_run-08_phasediff_half.nii.gz fmap/sub-009_run-08_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-009_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-009_run-08.nii.gz -nan fmap/fmap_rads_sub-009_run-08.nii.gz
flirt -in fmap/sub-009_run-08_magnitude_brain_matched.nii.gz -ref func/rasub-009_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-009_run-08.nii.gz -ref func/rasub-009_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-009_run-08.nii.gz
fugue -i func/rasub-009_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-009_run-08.nii.gz --unwarpdir=y- -u func/urasub-009_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-009_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-009_run-01.nii.gz --unwarpdir=y- -u func/urasub-009_task-localizer_bold.nii.gz -v

%% SUB-011

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-011

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-011/fmap/sub-011_run-01_magnitude.nii fmap/sub-011_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-01_phasediff.nii -div 2 fmap/sub-011_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-01_phasediff_half.nii.gz fmap/sub-011_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-01.nii.gz -nan fmap/fmap_rads_sub-011_run-01.nii.gz
flirt -in fmap/sub-011_run-01_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-011_run-01.nii.gz -ref func/rasub-011_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-011_run-01.nii.gz
fugue -i func/rasub-011_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-01.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-011/fmap/sub-011_run-02_magnitude.nii fmap/sub-011_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-02_phasediff.nii -div 2 fmap/sub-011_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-02_phasediff_half.nii.gz fmap/sub-011_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-02.nii.gz -nan fmap/fmap_rads_sub-011_run-02.nii.gz
flirt -in fmap/sub-011_run-02_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-011_run-02.nii.gz -ref func/rasub-011_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-011_run-02.nii.gz
fugue -i func/rasub-011_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-02.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-011/fmap/sub-011_run-03_magnitude.nii fmap/sub-011_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-03_phasediff.nii -div 2 fmap/sub-011_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-03_phasediff_half.nii.gz fmap/sub-011_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-03.nii.gz -nan fmap/fmap_rads_sub-011_run-03.nii.gz
flirt -in fmap/sub-011_run-03_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-011_run-03.nii.gz -ref func/rasub-011_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-011_run-03.nii.gz
fugue -i func/rasub-011_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-03.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-011/fmap/sub-011_run-04_magnitude.nii fmap/sub-011_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-04_phasediff.nii -div 2 fmap/sub-011_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-04_phasediff_half.nii.gz fmap/sub-011_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-04.nii.gz -nan fmap/fmap_rads_sub-011_run-04.nii.gz
flirt -in fmap/sub-011_run-04_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-011_run-04.nii.gz -ref func/rasub-011_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-011_run-04.nii.gz
fugue -i func/rasub-011_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-04.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-011/fmap/sub-011_run-05_magnitude.nii fmap/sub-011_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-05_phasediff.nii -div 2 fmap/sub-011_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-05_phasediff_half.nii.gz fmap/sub-011_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-05.nii.gz -nan fmap/fmap_rads_sub-011_run-05.nii.gz
flirt -in fmap/sub-011_run-05_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-011_run-05.nii.gz -ref func/rasub-011_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-011_run-05.nii.gz
fugue -i func/rasub-011_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-05.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-011/fmap/sub-011_run-06_magnitude.nii fmap/sub-011_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-06_phasediff.nii -div 2 fmap/sub-011_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-06_phasediff_half.nii.gz fmap/sub-011_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-06.nii.gz -nan fmap/fmap_rads_sub-011_run-06.nii.gz
flirt -in fmap/sub-011_run-06_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-011_run-06.nii.gz -ref func/rasub-011_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-011_run-06.nii.gz
fugue -i func/rasub-011_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-06.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-011/fmap/sub-011_run-07_magnitude.nii fmap/sub-011_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-07_phasediff.nii -div 2 fmap/sub-011_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-07_phasediff_half.nii.gz fmap/sub-011_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-07.nii.gz -nan fmap/fmap_rads_sub-011_run-07.nii.gz
flirt -in fmap/sub-011_run-07_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-011_run-07.nii.gz -ref func/rasub-011_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-011_run-07.nii.gz
fugue -i func/rasub-011_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-07.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-011/fmap/sub-011_run-08_magnitude.nii fmap/sub-011_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-011/fmap/sub-011_run-08_phasediff.nii -div 2 fmap/sub-011_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-011_run-08_phasediff_half.nii.gz fmap/sub-011_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-011_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-011_run-08.nii.gz -nan fmap/fmap_rads_sub-011_run-08.nii.gz
flirt -in fmap/sub-011_run-08_magnitude_brain.nii.gz -ref func/rasub-011_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-011_run-08.nii.gz -ref func/rasub-011_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-011_run-08.nii.gz
fugue -i func/rasub-011_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-011_run-08.nii.gz --unwarpdir=y- -u func/urasub-011_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-011_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-011_run-01.nii.gz --unwarpdir=y- -u func/urasub-011_task-localizer_bold.nii.gz -v

%% SUB-012

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-012

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-012/fmap/sub-012_run-01_magnitude.nii fmap/sub-012_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-01_phasediff.nii -div 2 fmap/sub-012_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-01_phasediff_half.nii.gz fmap/sub-012_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-01.nii.gz -nan fmap/fmap_rads_sub-012_run-01.nii.gz
flirt -in fmap/sub-012_run-01_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-012_run-01.nii.gz -ref func/rasub-012_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-012_run-01.nii.gz
fugue -i func/rasub-012_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-01.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-012/fmap/sub-012_run-02_magnitude.nii fmap/sub-012_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-02_phasediff.nii -div 2 fmap/sub-012_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-02_phasediff_half.nii.gz fmap/sub-012_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-02.nii.gz -nan fmap/fmap_rads_sub-012_run-02.nii.gz
flirt -in fmap/sub-012_run-02_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-012_run-02.nii.gz -ref func/rasub-012_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-012_run-02.nii.gz
fugue -i func/rasub-012_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-02.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-012/fmap/sub-012_run-03_magnitude.nii fmap/sub-012_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-03_phasediff.nii -div 2 fmap/sub-012_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-03_phasediff_half.nii.gz fmap/sub-012_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-03.nii.gz -nan fmap/fmap_rads_sub-012_run-03.nii.gz
flirt -in fmap/sub-012_run-03_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-012_run-03.nii.gz -ref func/rasub-012_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-012_run-03.nii.gz
fugue -i func/rasub-012_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-03.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-012/fmap/sub-012_run-04_magnitude.nii fmap/sub-012_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-04_phasediff.nii -div 2 fmap/sub-012_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-04_phasediff_half.nii.gz fmap/sub-012_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-04.nii.gz -nan fmap/fmap_rads_sub-012_run-04.nii.gz
flirt -in fmap/sub-012_run-04_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-012_run-04.nii.gz -ref func/rasub-012_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-012_run-04.nii.gz
fugue -i func/rasub-012_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-04.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-012/fmap/sub-012_run-05_magnitude.nii fmap/sub-012_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-05_phasediff.nii -div 2 fmap/sub-012_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-05_phasediff_half.nii.gz fmap/sub-012_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-05.nii.gz -nan fmap/fmap_rads_sub-012_run-05.nii.gz
flirt -in fmap/sub-012_run-05_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-012_run-05.nii.gz -ref func/rasub-012_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-012_run-05.nii.gz
fugue -i func/rasub-012_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-05.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-012/fmap/sub-012_run-06_magnitude.nii fmap/sub-012_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-06_phasediff.nii -div 2 fmap/sub-012_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-06_phasediff_half.nii.gz fmap/sub-012_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-06.nii.gz -nan fmap/fmap_rads_sub-012_run-06.nii.gz
flirt -in fmap/sub-012_run-06_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-012_run-06.nii.gz -ref func/rasub-012_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-012_run-06.nii.gz
fugue -i func/rasub-012_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-06.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-012/fmap/sub-012_run-07_magnitude.nii fmap/sub-012_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-07_phasediff.nii -div 2 fmap/sub-012_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-07_phasediff_half.nii.gz fmap/sub-012_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-07.nii.gz -nan fmap/fmap_rads_sub-012_run-07.nii.gz
flirt -in fmap/sub-012_run-07_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-012_run-07.nii.gz -ref func/rasub-012_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-012_run-07.nii.gz
fugue -i func/rasub-012_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-07.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-012/fmap/sub-012_run-08_magnitude.nii fmap/sub-012_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-012/fmap/sub-012_run-08_phasediff.nii -div 2 fmap/sub-012_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-012_run-08_phasediff_half.nii.gz fmap/sub-012_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-012_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-012_run-08.nii.gz -nan fmap/fmap_rads_sub-012_run-08.nii.gz
flirt -in fmap/sub-012_run-08_magnitude_brain.nii.gz -ref func/rasub-012_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-012_run-08.nii.gz -ref func/rasub-012_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-012_run-08.nii.gz
fugue -i func/rasub-012_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-012_run-08.nii.gz --unwarpdir=y- -u func/urasub-012_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-012_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-012_run-01.nii.gz --unwarpdir=y- -u func/urasub-012_task-localizer_bold.nii.gz -v

%% SUB-013

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-013

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-013/fmap/sub-013_run-01_magnitude.nii fmap/sub-013_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-01_phasediff.nii -div 2 fmap/sub-013_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-01_phasediff_half.nii.gz fmap/sub-013_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-01.nii.gz -nan fmap/fmap_rads_sub-013_run-01.nii.gz
flirt -in fmap/sub-013_run-01_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-013_run-01.nii.gz -ref func/rasub-013_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-013_run-01.nii.gz
fugue -i func/rasub-013_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-01.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-013/fmap/sub-013_run-02_magnitude.nii fmap/sub-013_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-02_phasediff.nii -div 2 fmap/sub-013_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-02_phasediff_half.nii.gz fmap/sub-013_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-02.nii.gz -nan fmap/fmap_rads_sub-013_run-02.nii.gz
flirt -in fmap/sub-013_run-02_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-013_run-02.nii.gz -ref func/rasub-013_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-013_run-02.nii.gz
fugue -i func/rasub-013_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-02.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-013/fmap/sub-013_run-03_magnitude.nii fmap/sub-013_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-03_phasediff.nii -div 2 fmap/sub-013_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-03_phasediff_half.nii.gz fmap/sub-013_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-03.nii.gz -nan fmap/fmap_rads_sub-013_run-03.nii.gz
flirt -in fmap/sub-013_run-03_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-013_run-03.nii.gz -ref func/rasub-013_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-013_run-03.nii.gz
fugue -i func/rasub-013_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-03.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-013/fmap/sub-013_run-04_magnitude.nii fmap/sub-013_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-04_phasediff.nii -div 2 fmap/sub-013_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-04_phasediff_half.nii.gz fmap/sub-013_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-04.nii.gz -nan fmap/fmap_rads_sub-013_run-04.nii.gz
flirt -in fmap/sub-013_run-04_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-013_run-04.nii.gz -ref func/rasub-013_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-013_run-04.nii.gz
fugue -i func/rasub-013_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-04.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-013/fmap/sub-013_run-05_magnitude.nii fmap/sub-013_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-05_phasediff.nii -div 2 fmap/sub-013_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-05_phasediff_half.nii.gz fmap/sub-013_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-05.nii.gz -nan fmap/fmap_rads_sub-013_run-05.nii.gz
flirt -in fmap/sub-013_run-05_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-013_run-05.nii.gz -ref func/rasub-013_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-013_run-05.nii.gz
fugue -i func/rasub-013_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-05.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-013/fmap/sub-013_run-06_magnitude.nii fmap/sub-013_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-06_phasediff.nii -div 2 fmap/sub-013_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-06_phasediff_half.nii.gz fmap/sub-013_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-06.nii.gz -nan fmap/fmap_rads_sub-013_run-06.nii.gz
flirt -in fmap/sub-013_run-06_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-013_run-06.nii.gz -ref func/rasub-013_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-013_run-06.nii.gz
fugue -i func/rasub-013_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-06.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-013/fmap/sub-013_run-07_magnitude.nii fmap/sub-013_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-07_phasediff.nii -div 2 fmap/sub-013_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-07_phasediff_half.nii.gz fmap/sub-013_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-07.nii.gz -nan fmap/fmap_rads_sub-013_run-07.nii.gz
flirt -in fmap/sub-013_run-07_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-013_run-07.nii.gz -ref func/rasub-013_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-013_run-07.nii.gz
fugue -i func/rasub-013_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-07.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-013/fmap/sub-013_run-08_magnitude.nii fmap/sub-013_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-013/fmap/sub-013_run-08_phasediff.nii -div 2 fmap/sub-013_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-013_run-08_phasediff_half.nii.gz fmap/sub-013_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-013_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-013_run-08.nii.gz -nan fmap/fmap_rads_sub-013_run-08.nii.gz
flirt -in fmap/sub-013_run-08_magnitude_brain.nii.gz -ref func/rasub-013_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-013_run-08.nii.gz -ref func/rasub-013_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-013_run-08.nii.gz
fugue -i func/rasub-013_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-013_run-08.nii.gz --unwarpdir=y- -u func/urasub-013_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-013_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-013_run-01.nii.gz --unwarpdir=y- -u func/urasub-013_task-localizer_bold.nii.gz -v

%% SUB-014

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-014

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-014/fmap/sub-014_run-01_magnitude.nii fmap/sub-014_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-01_phasediff.nii -div 2 fmap/sub-014_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-01_phasediff_half.nii.gz fmap/sub-014_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-01.nii.gz -nan fmap/fmap_rads_sub-014_run-01.nii.gz
flirt -in fmap/sub-014_run-01_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-014_run-01.nii.gz -ref func/rasub-014_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-014_run-01.nii.gz
fugue -i func/rasub-014_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-01.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-014/fmap/sub-014_run-02_magnitude.nii fmap/sub-014_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-02_phasediff.nii -div 2 fmap/sub-014_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-02_phasediff_half.nii.gz fmap/sub-014_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-02.nii.gz -nan fmap/fmap_rads_sub-014_run-02.nii.gz
flirt -in fmap/sub-014_run-02_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-014_run-02.nii.gz -ref func/rasub-014_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-014_run-02.nii.gz
fugue -i func/rasub-014_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-02.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-014/fmap/sub-014_run-03_magnitude.nii fmap/sub-014_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-03_phasediff.nii -div 2 fmap/sub-014_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-03_phasediff_half.nii.gz fmap/sub-014_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-03.nii.gz -nan fmap/fmap_rads_sub-014_run-03.nii.gz
flirt -in fmap/sub-014_run-03_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-014_run-03.nii.gz -ref func/rasub-014_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-014_run-03.nii.gz
fugue -i func/rasub-014_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-03.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-014/fmap/sub-014_run-04_magnitude.nii fmap/sub-014_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-04_phasediff.nii -div 2 fmap/sub-014_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-04_phasediff_half.nii.gz fmap/sub-014_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-04.nii.gz -nan fmap/fmap_rads_sub-014_run-04.nii.gz
flirt -in fmap/sub-014_run-04_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-014_run-04.nii.gz -ref func/rasub-014_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-014_run-04.nii.gz
fugue -i func/rasub-014_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-04.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-014/fmap/sub-014_run-05_magnitude.nii fmap/sub-014_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-05_phasediff.nii -div 2 fmap/sub-014_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-05_phasediff_half.nii.gz fmap/sub-014_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-05.nii.gz -nan fmap/fmap_rads_sub-014_run-05.nii.gz
flirt -in fmap/sub-014_run-05_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-014_run-05.nii.gz -ref func/rasub-014_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-014_run-05.nii.gz
fugue -i func/rasub-014_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-05.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-014/fmap/sub-014_run-06_magnitude.nii fmap/sub-014_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-06_phasediff.nii -div 2 fmap/sub-014_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-06_phasediff_half.nii.gz fmap/sub-014_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-06.nii.gz -nan fmap/fmap_rads_sub-014_run-06.nii.gz
flirt -in fmap/sub-014_run-06_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-014_run-06.nii.gz -ref func/rasub-014_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-014_run-06.nii.gz
fugue -i func/rasub-014_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-06.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-014/fmap/sub-014_run-07_magnitude.nii fmap/sub-014_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-07_phasediff.nii -div 2 fmap/sub-014_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-07_phasediff_half.nii.gz fmap/sub-014_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-07.nii.gz -nan fmap/fmap_rads_sub-014_run-07.nii.gz
flirt -in fmap/sub-014_run-07_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-014_run-07.nii.gz -ref func/rasub-014_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-014_run-07.nii.gz
fugue -i func/rasub-014_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-07.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-014/fmap/sub-014_run-08_magnitude.nii fmap/sub-014_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-014/fmap/sub-014_run-08_phasediff.nii -div 2 fmap/sub-014_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-014_run-08_phasediff_half.nii.gz fmap/sub-014_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-014_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-014_run-08.nii.gz -nan fmap/fmap_rads_sub-014_run-08.nii.gz
flirt -in fmap/sub-014_run-08_magnitude_brain.nii.gz -ref func/rasub-014_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-014_run-08.nii.gz -ref func/rasub-014_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-014_run-08.nii.gz
fugue -i func/rasub-014_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-014_run-08.nii.gz --unwarpdir=y- -u func/urasub-014_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-014_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-014_run-01.nii.gz --unwarpdir=y- -u func/urasub-014_task-localizer_bold.nii.gz -v

%% SUB-015

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-015

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-015/fmap/sub-015_run-01_magnitude.nii fmap/sub-015_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-01_phasediff.nii -div 2 fmap/sub-015_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-01_phasediff_half.nii.gz fmap/sub-015_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-015_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-01.nii.gz -nan fmap/fmap_rads_sub-015_run-01.nii.gz
flirt -in fmap/sub-015_run-01_magnitude_brain.nii.gz -ref func/rasub-015_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-015_run-01.nii.gz -ref func/rasub-015_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-015_run-01.nii.gz
fugue -i func/rasub-015_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-01.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-015/fmap/sub-015_run-02_magnitude1.nii fmap/sub-015_run-02_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-015_run-02_magnitude_brain.nii.gz -ref ../../../rawdata/sub-015/fmap/sub-015_run-02_phasediff.nii -applyxfm -usesqform -out fmap/sub-015_run-02_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-02_phasediff.nii -div 2 fmap/sub-015_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-02_phasediff_half.nii.gz fmap/sub-015_run-02_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-015_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-02.nii.gz -nan fmap/fmap_rads_sub-015_run-02.nii.gz
flirt -in fmap/sub-015_run-02_magnitude_brain_matched.nii.gz -ref func/rasub-015_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-015_run-02.nii.gz -ref func/rasub-015_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-015_run-02.nii.gz
fugue -i func/rasub-015_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-02.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-015/fmap/sub-015_run-03_magnitude.nii fmap/sub-015_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-03_phasediff.nii -div 2 fmap/sub-015_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-03_phasediff_half.nii.gz fmap/sub-015_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-015_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-03.nii.gz -nan fmap/fmap_rads_sub-015_run-03.nii.gz
flirt -in fmap/sub-015_run-03_magnitude_brain.nii.gz -ref func/rasub-015_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-015_run-03.nii.gz -ref func/rasub-015_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-015_run-03.nii.gz
fugue -i func/rasub-015_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-03.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-015/fmap/sub-015_run-04_magnitude1.nii fmap/sub-015_run-04_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-015_run-04_magnitude_brain.nii.gz -ref ../../../rawdata/sub-015/fmap/sub-015_run-04_phasediff.nii -applyxfm -usesqform -out fmap/sub-015_run-04_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-04_phasediff.nii -div 2 fmap/sub-015_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-04_phasediff_half.nii.gz fmap/sub-015_run-04_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-015_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-04.nii.gz -nan fmap/fmap_rads_sub-015_run-04.nii.gz
flirt -in fmap/sub-015_run-04_magnitude_brain_matched.nii.gz -ref func/rasub-015_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-015_run-04.nii.gz -ref func/rasub-015_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-015_run-04.nii.gz
fugue -i func/rasub-015_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-04.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-015/fmap/sub-015_run-05_magnitude1.nii fmap/sub-015_run-05_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-015_run-05_magnitude_brain.nii.gz -ref ../../../rawdata/sub-015/fmap/sub-015_run-05_phasediff.nii -applyxfm -usesqform -out fmap/sub-015_run-05_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-05_phasediff.nii -div 2 fmap/sub-015_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-05_phasediff_half.nii.gz fmap/sub-015_run-05_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-015_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-05.nii.gz -nan fmap/fmap_rads_sub-015_run-05.nii.gz
flirt -in fmap/sub-015_run-05_magnitude_brain_matched.nii.gz -ref func/rasub-015_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-015_run-05.nii.gz -ref func/rasub-015_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-015_run-05.nii.gz
fugue -i func/rasub-015_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-05.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-015/fmap/sub-015_run-06_magnitude.nii fmap/sub-015_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-06_phasediff.nii -div 2 fmap/sub-015_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-06_phasediff_half.nii.gz fmap/sub-015_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-015_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-06.nii.gz -nan fmap/fmap_rads_sub-015_run-06.nii.gz
flirt -in fmap/sub-015_run-06_magnitude_brain.nii.gz -ref func/rasub-015_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-015_run-06.nii.gz -ref func/rasub-015_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-015_run-06.nii.gz
fugue -i func/rasub-015_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-06.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-015/fmap/sub-015_run-07_magnitude.nii fmap/sub-015_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-07_phasediff.nii -div 2 fmap/sub-015_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-07_phasediff_half.nii.gz fmap/sub-015_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-015_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-07.nii.gz -nan fmap/fmap_rads_sub-015_run-07.nii.gz
flirt -in fmap/sub-015_run-07_magnitude_brain.nii.gz -ref func/rasub-015_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-015_run-07.nii.gz -ref func/rasub-015_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-015_run-07.nii.gz
fugue -i func/rasub-015_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-07.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-015/fmap/sub-015_run-08_magnitude1.nii fmap/sub-015_run-08_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-015_run-08_magnitude_brain.nii.gz -ref ../../../rawdata/sub-015/fmap/sub-015_run-08_phasediff.nii -applyxfm -usesqform -out fmap/sub-015_run-08_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-015/fmap/sub-015_run-08_phasediff.nii -div 2 fmap/sub-015_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-015_run-08_phasediff_half.nii.gz fmap/sub-015_run-08_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-015_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-015_run-08.nii.gz -nan fmap/fmap_rads_sub-015_run-08.nii.gz
flirt -in fmap/sub-015_run-08_magnitude_brain_matched.nii.gz -ref func/rasub-015_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-015_run-08.nii.gz -ref func/rasub-015_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-015_run-08.nii.gz
fugue -i func/rasub-015_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-015_run-08.nii.gz --unwarpdir=y- -u func/urasub-015_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-015_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-015_run-01.nii.gz --unwarpdir=y- -u func/urasub-015_task-localizer_bold.nii.gz -v

%% SUB-016

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-016

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-016/fmap/sub-016_run-01_magnitude.nii fmap/sub-016_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-01_phasediff.nii -div 2 fmap/sub-016_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-01_phasediff_half.nii.gz fmap/sub-016_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-01.nii.gz -nan fmap/fmap_rads_sub-016_run-01.nii.gz
flirt -in fmap/sub-016_run-01_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-016_run-01.nii.gz -ref func/rasub-016_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-016_run-01.nii.gz
fugue -i func/rasub-016_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-01.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-016/fmap/sub-016_run-02_magnitude.nii fmap/sub-016_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-02_phasediff.nii -div 2 fmap/sub-016_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-02_phasediff_half.nii.gz fmap/sub-016_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-02.nii.gz -nan fmap/fmap_rads_sub-016_run-02.nii.gz
flirt -in fmap/sub-016_run-02_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-016_run-02.nii.gz -ref func/rasub-016_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-016_run-02.nii.gz
fugue -i func/rasub-016_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-02.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-016/fmap/sub-016_run-03_magnitude.nii fmap/sub-016_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-03_phasediff.nii -div 2 fmap/sub-016_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-03_phasediff_half.nii.gz fmap/sub-016_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-03.nii.gz -nan fmap/fmap_rads_sub-016_run-03.nii.gz
flirt -in fmap/sub-016_run-03_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-016_run-03.nii.gz -ref func/rasub-016_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-016_run-03.nii.gz
fugue -i func/rasub-016_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-03.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-016/fmap/sub-016_run-04_magnitude.nii fmap/sub-016_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-04_phasediff.nii -div 2 fmap/sub-016_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-04_phasediff_half.nii.gz fmap/sub-016_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-04.nii.gz -nan fmap/fmap_rads_sub-016_run-04.nii.gz
flirt -in fmap/sub-016_run-04_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-016_run-04.nii.gz -ref func/rasub-016_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-016_run-04.nii.gz
fugue -i func/rasub-016_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-04.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-016/fmap/sub-016_run-05_magnitude.nii fmap/sub-016_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-05_phasediff.nii -div 2 fmap/sub-016_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-05_phasediff_half.nii.gz fmap/sub-016_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-05.nii.gz -nan fmap/fmap_rads_sub-016_run-05.nii.gz
flirt -in fmap/sub-016_run-05_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-016_run-05.nii.gz -ref func/rasub-016_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-016_run-05.nii.gz
fugue -i func/rasub-016_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-05.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-016/fmap/sub-016_run-06_magnitude.nii fmap/sub-016_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-06_phasediff.nii -div 2 fmap/sub-016_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-06_phasediff_half.nii.gz fmap/sub-016_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-06.nii.gz -nan fmap/fmap_rads_sub-016_run-06.nii.gz
flirt -in fmap/sub-016_run-06_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-016_run-06.nii.gz -ref func/rasub-016_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-016_run-06.nii.gz
fugue -i func/rasub-016_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-06.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-016/fmap/sub-016_run-07_magnitude.nii fmap/sub-016_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-07_phasediff.nii -div 2 fmap/sub-016_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-07_phasediff_half.nii.gz fmap/sub-016_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-07.nii.gz -nan fmap/fmap_rads_sub-016_run-07.nii.gz
flirt -in fmap/sub-016_run-07_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-016_run-07.nii.gz -ref func/rasub-016_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-016_run-07.nii.gz
fugue -i func/rasub-016_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-07.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-016/fmap/sub-016_run-08_magnitude.nii fmap/sub-016_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-016/fmap/sub-016_run-08_phasediff.nii -div 2 fmap/sub-016_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-016_run-08_phasediff_half.nii.gz fmap/sub-016_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-016_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-016_run-08.nii.gz -nan fmap/fmap_rads_sub-016_run-08.nii.gz
flirt -in fmap/sub-016_run-08_magnitude_brain.nii.gz -ref func/rasub-016_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-016_run-08.nii.gz -ref func/rasub-016_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-016_run-08.nii.gz
fugue -i func/rasub-016_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-016_run-08.nii.gz --unwarpdir=y- -u func/urasub-016_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-016_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-016_run-01.nii.gz --unwarpdir=y- -u func/urasub-016_task-localizer_bold.nii.gz -v

%% SUB-017

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-017

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-017/fmap/sub-017_run-01_magnitude.nii fmap/sub-017_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-01_phasediff.nii -div 2 fmap/sub-017_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-01_phasediff_half.nii.gz fmap/sub-017_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-01.nii.gz -nan fmap/fmap_rads_sub-017_run-01.nii.gz
flirt -in fmap/sub-017_run-01_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-017_run-01.nii.gz -ref func/rasub-017_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-017_run-01.nii.gz
fugue -i func/rasub-017_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-01.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-017/fmap/sub-017_run-02_magnitude.nii fmap/sub-017_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-02_phasediff.nii -div 2 fmap/sub-017_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-02_phasediff_half.nii.gz fmap/sub-017_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-02.nii.gz -nan fmap/fmap_rads_sub-017_run-02.nii.gz
flirt -in fmap/sub-017_run-02_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-017_run-02.nii.gz -ref func/rasub-017_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-017_run-02.nii.gz
fugue -i func/rasub-017_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-02.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-017/fmap/sub-017_run-03_magnitude.nii fmap/sub-017_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-03_phasediff.nii -div 2 fmap/sub-017_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-03_phasediff_half.nii.gz fmap/sub-017_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-03.nii.gz -nan fmap/fmap_rads_sub-017_run-03.nii.gz
flirt -in fmap/sub-017_run-03_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-017_run-03.nii.gz -ref func/rasub-017_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-017_run-03.nii.gz
fugue -i func/rasub-017_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-03.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-017/fmap/sub-017_run-04_magnitude.nii fmap/sub-017_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-04_phasediff.nii -div 2 fmap/sub-017_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-04_phasediff_half.nii.gz fmap/sub-017_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-04.nii.gz -nan fmap/fmap_rads_sub-017_run-04.nii.gz
flirt -in fmap/sub-017_run-04_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-017_run-04.nii.gz -ref func/rasub-017_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-017_run-04.nii.gz
fugue -i func/rasub-017_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-04.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-017/fmap/sub-017_run-05_magnitude.nii fmap/sub-017_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-05_phasediff.nii -div 2 fmap/sub-017_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-05_phasediff_half.nii.gz fmap/sub-017_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-05.nii.gz -nan fmap/fmap_rads_sub-017_run-05.nii.gz
flirt -in fmap/sub-017_run-05_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-017_run-05.nii.gz -ref func/rasub-017_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-017_run-05.nii.gz
fugue -i func/rasub-017_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-05.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-017/fmap/sub-017_run-06_magnitude.nii fmap/sub-017_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-06_phasediff.nii -div 2 fmap/sub-017_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-06_phasediff_half.nii.gz fmap/sub-017_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-06.nii.gz -nan fmap/fmap_rads_sub-017_run-06.nii.gz
flirt -in fmap/sub-017_run-06_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-017_run-06.nii.gz -ref func/rasub-017_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-017_run-06.nii.gz
fugue -i func/rasub-017_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-06.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-017/fmap/sub-017_run-07_magnitude.nii fmap/sub-017_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-07_phasediff.nii -div 2 fmap/sub-017_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-07_phasediff_half.nii.gz fmap/sub-017_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-07.nii.gz -nan fmap/fmap_rads_sub-017_run-07.nii.gz
flirt -in fmap/sub-017_run-07_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-017_run-07.nii.gz -ref func/rasub-017_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-017_run-07.nii.gz
fugue -i func/rasub-017_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-07.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-017/fmap/sub-017_run-08_magnitude.nii fmap/sub-017_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-017/fmap/sub-017_run-08_phasediff.nii -div 2 fmap/sub-017_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-017_run-08_phasediff_half.nii.gz fmap/sub-017_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-017_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-017_run-08.nii.gz -nan fmap/fmap_rads_sub-017_run-08.nii.gz
flirt -in fmap/sub-017_run-08_magnitude_brain.nii.gz -ref func/rasub-017_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-017_run-08.nii.gz -ref func/rasub-017_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-017_run-08.nii.gz
fugue -i func/rasub-017_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-017_run-08.nii.gz --unwarpdir=y- -u func/urasub-017_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-017_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-017_run-01.nii.gz --unwarpdir=y- -u func/urasub-017_task-localizer_bold.nii.gz -v

%% SUB-018

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-018

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-018/fmap/sub-018_run-01_magnitude.nii fmap/sub-018_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-01_phasediff.nii -div 2 fmap/sub-018_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-01_phasediff_half.nii.gz fmap/sub-018_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-01.nii.gz -nan fmap/fmap_rads_sub-018_run-01.nii.gz
flirt -in fmap/sub-018_run-01_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-018_run-01.nii.gz -ref func/rasub-018_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-018_run-01.nii.gz
fugue -i func/rasub-018_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-01.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-018/fmap/sub-018_run-02_magnitude.nii fmap/sub-018_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-02_phasediff.nii -div 2 fmap/sub-018_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-02_phasediff_half.nii.gz fmap/sub-018_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-02.nii.gz -nan fmap/fmap_rads_sub-018_run-02.nii.gz
flirt -in fmap/sub-018_run-02_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-018_run-02.nii.gz -ref func/rasub-018_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-018_run-02.nii.gz
fugue -i func/rasub-018_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-02.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-018/fmap/sub-018_run-03_magnitude.nii fmap/sub-018_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-03_phasediff.nii -div 2 fmap/sub-018_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-03_phasediff_half.nii.gz fmap/sub-018_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-03.nii.gz -nan fmap/fmap_rads_sub-018_run-03.nii.gz
flirt -in fmap/sub-018_run-03_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-018_run-03.nii.gz -ref func/rasub-018_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-018_run-03.nii.gz
fugue -i func/rasub-018_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-03.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-018/fmap/sub-018_run-04_magnitude.nii fmap/sub-018_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-04_phasediff.nii -div 2 fmap/sub-018_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-04_phasediff_half.nii.gz fmap/sub-018_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-04.nii.gz -nan fmap/fmap_rads_sub-018_run-04.nii.gz
flirt -in fmap/sub-018_run-04_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-018_run-04.nii.gz -ref func/rasub-018_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-018_run-04.nii.gz
fugue -i func/rasub-018_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-04.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-018/fmap/sub-018_run-05_magnitude.nii fmap/sub-018_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-05_phasediff.nii -div 2 fmap/sub-018_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-05_phasediff_half.nii.gz fmap/sub-018_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-05.nii.gz -nan fmap/fmap_rads_sub-018_run-05.nii.gz
flirt -in fmap/sub-018_run-05_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-018_run-05.nii.gz -ref func/rasub-018_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-018_run-05.nii.gz
fugue -i func/rasub-018_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-05.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-018/fmap/sub-018_run-06_magnitude.nii fmap/sub-018_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-06_phasediff.nii -div 2 fmap/sub-018_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-06_phasediff_half.nii.gz fmap/sub-018_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-06.nii.gz -nan fmap/fmap_rads_sub-018_run-06.nii.gz
flirt -in fmap/sub-018_run-06_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-018_run-06.nii.gz -ref func/rasub-018_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-018_run-06.nii.gz
fugue -i func/rasub-018_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-06.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-018/fmap/sub-018_run-07_magnitude.nii fmap/sub-018_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-07_phasediff.nii -div 2 fmap/sub-018_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-07_phasediff_half.nii.gz fmap/sub-018_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-07.nii.gz -nan fmap/fmap_rads_sub-018_run-07.nii.gz
flirt -in fmap/sub-018_run-07_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-018_run-07.nii.gz -ref func/rasub-018_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-018_run-07.nii.gz
fugue -i func/rasub-018_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-07.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-018/fmap/sub-018_run-08_magnitude.nii fmap/sub-018_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-018/fmap/sub-018_run-08_phasediff.nii -div 2 fmap/sub-018_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-018_run-08_phasediff_half.nii.gz fmap/sub-018_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-018_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-018_run-08.nii.gz -nan fmap/fmap_rads_sub-018_run-08.nii.gz
flirt -in fmap/sub-018_run-08_magnitude_brain.nii.gz -ref func/rasub-018_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-018_run-08.nii.gz -ref func/rasub-018_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-018_run-08.nii.gz
fugue -i func/rasub-018_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-018_run-08.nii.gz --unwarpdir=y- -u func/urasub-018_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-018_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-018_run-01.nii.gz --unwarpdir=y- -u func/urasub-018_task-localizer_bold.nii.gz -v

%% SUB-019

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-019

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-019/fmap/sub-019_run-01_magnitude.nii fmap/sub-019_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-01_phasediff.nii -div 2 fmap/sub-019_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-01_phasediff_half.nii.gz fmap/sub-019_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-019_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-01.nii.gz -nan fmap/fmap_rads_sub-019_run-01.nii.gz
flirt -in fmap/sub-019_run-01_magnitude_brain.nii.gz -ref func/rasub-019_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-019_run-01.nii.gz -ref func/rasub-019_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-019_run-01.nii.gz
fugue -i func/rasub-019_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-01.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-019/fmap/sub-019_run-02_magnitude.nii fmap/sub-019_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-02_phasediff.nii -div 2 fmap/sub-019_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-02_phasediff_half.nii.gz fmap/sub-019_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-019_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-02.nii.gz -nan fmap/fmap_rads_sub-019_run-02.nii.gz
flirt -in fmap/sub-019_run-02_magnitude_brain.nii.gz -ref func/rasub-019_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-019_run-02.nii.gz -ref func/rasub-019_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-019_run-02.nii.gz
fugue -i func/rasub-019_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-02.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-019/fmap/sub-019_run-03_magnitude1.nii fmap/sub-019_run-03_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-019_run-03_magnitude_brain.nii.gz -ref ../../../rawdata/sub-019/fmap/sub-019_run-03_phasediff.nii -applyxfm -usesqform -out fmap/sub-019_run-03_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-03_phasediff.nii -div 2 fmap/sub-019_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-03_phasediff_half.nii.gz fmap/sub-019_run-03_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-019_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-03.nii.gz -nan fmap/fmap_rads_sub-019_run-03.nii.gz
flirt -in fmap/sub-019_run-03_magnitude_brain_matched.nii.gz -ref func/rasub-019_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-019_run-03.nii.gz -ref func/rasub-019_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-019_run-03.nii.gz
fugue -i func/rasub-019_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-03.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-019/fmap/sub-019_run-04_magnitude1.nii fmap/sub-019_run-04_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-019_run-04_magnitude_brain.nii.gz -ref ../../../rawdata/sub-019/fmap/sub-019_run-04_phasediff.nii -applyxfm -usesqform -out fmap/sub-019_run-04_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-04_phasediff.nii -div 2 fmap/sub-019_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-04_phasediff_half.nii.gz fmap/sub-019_run-04_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-019_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-04.nii.gz -nan fmap/fmap_rads_sub-019_run-04.nii.gz
flirt -in fmap/sub-019_run-04_magnitude_brain_matched.nii.gz -ref func/rasub-019_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-019_run-04.nii.gz -ref func/rasub-019_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-019_run-04.nii.gz
fugue -i func/rasub-019_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-04.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-019/fmap/sub-019_run-05_magnitude1.nii fmap/sub-019_run-05_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-019_run-05_magnitude_brain.nii.gz -ref ../../../rawdata/sub-019/fmap/sub-019_run-05_phasediff.nii -applyxfm -usesqform -out fmap/sub-019_run-05_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-05_phasediff.nii -div 2 fmap/sub-019_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-05_phasediff_half.nii.gz fmap/sub-019_run-05_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-019_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-05.nii.gz -nan fmap/fmap_rads_sub-019_run-05.nii.gz
flirt -in fmap/sub-019_run-05_magnitude_brain_matched.nii.gz -ref func/rasub-019_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-019_run-05.nii.gz -ref func/rasub-019_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-019_run-05.nii.gz
fugue -i func/rasub-019_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-05.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-019/fmap/sub-019_run-06_magnitude.nii fmap/sub-019_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-06_phasediff.nii -div 2 fmap/sub-019_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-06_phasediff_half.nii.gz fmap/sub-019_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-019_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-06.nii.gz -nan fmap/fmap_rads_sub-019_run-06.nii.gz
flirt -in fmap/sub-019_run-06_magnitude_brain.nii.gz -ref func/rasub-019_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-019_run-06.nii.gz -ref func/rasub-019_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-019_run-06.nii.gz
fugue -i func/rasub-019_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-06.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-019/fmap/sub-019_run-07_magnitude1.nii fmap/sub-019_run-07_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-019_run-07_magnitude_brain.nii.gz -ref ../../../rawdata/sub-019/fmap/sub-019_run-07_phasediff.nii -applyxfm -usesqform -out fmap/sub-019_run-07_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-07_phasediff.nii -div 2 fmap/sub-019_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-07_phasediff_half.nii.gz fmap/sub-019_run-07_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-019_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-07.nii.gz -nan fmap/fmap_rads_sub-019_run-07.nii.gz
flirt -in fmap/sub-019_run-07_magnitude_brain_matched.nii.gz -ref func/rasub-019_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-019_run-07.nii.gz -ref func/rasub-019_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-019_run-07.nii.gz
fugue -i func/rasub-019_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-07.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-019/fmap/sub-019_run-08_magnitude1.nii fmap/sub-019_run-08_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-019_run-08_magnitude_brain.nii.gz -ref ../../../rawdata/sub-019/fmap/sub-019_run-08_phasediff.nii -applyxfm -usesqform -out fmap/sub-019_run-08_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-019/fmap/sub-019_run-08_phasediff.nii -div 2 fmap/sub-019_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-019_run-08_phasediff_half.nii.gz fmap/sub-019_run-08_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-019_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-019_run-08.nii.gz -nan fmap/fmap_rads_sub-019_run-08.nii.gz
flirt -in fmap/sub-019_run-08_magnitude_brain_matched.nii.gz -ref func/rasub-019_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-019_run-08.nii.gz -ref func/rasub-019_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-019_run-08.nii.gz
fugue -i func/rasub-019_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-019_run-08.nii.gz --unwarpdir=y- -u func/urasub-019_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-019_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-019_run-01.nii.gz --unwarpdir=y- -u func/urasub-019_task-localizer_bold.nii.gz -v

%% SUB-020

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-020

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-020/fmap/sub-020_run-01_magnitude.nii fmap/sub-020_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-01_phasediff.nii -div 2 fmap/sub-020_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-01_phasediff_half.nii.gz fmap/sub-020_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-01.nii.gz -nan fmap/fmap_rads_sub-020_run-01.nii.gz
flirt -in fmap/sub-020_run-01_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-020_run-01.nii.gz -ref func/rasub-020_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-020_run-01.nii.gz
fugue -i func/rasub-020_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-01.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-020/fmap/sub-020_run-02_magnitude.nii fmap/sub-020_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-02_phasediff.nii -div 2 fmap/sub-020_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-02_phasediff_half.nii.gz fmap/sub-020_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-02.nii.gz -nan fmap/fmap_rads_sub-020_run-02.nii.gz
flirt -in fmap/sub-020_run-02_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-020_run-02.nii.gz -ref func/rasub-020_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-020_run-02.nii.gz
fugue -i func/rasub-020_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-02.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-020/fmap/sub-020_run-03_magnitude.nii fmap/sub-020_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-03_phasediff.nii -div 2 fmap/sub-020_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-03_phasediff_half.nii.gz fmap/sub-020_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-03.nii.gz -nan fmap/fmap_rads_sub-020_run-03.nii.gz
flirt -in fmap/sub-020_run-03_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-020_run-03.nii.gz -ref func/rasub-020_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-020_run-03.nii.gz
fugue -i func/rasub-020_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-03.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-020/fmap/sub-020_run-04_magnitude.nii fmap/sub-020_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-04_phasediff.nii -div 2 fmap/sub-020_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-04_phasediff_half.nii.gz fmap/sub-020_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-04.nii.gz -nan fmap/fmap_rads_sub-020_run-04.nii.gz
flirt -in fmap/sub-020_run-04_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-020_run-04.nii.gz -ref func/rasub-020_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-020_run-04.nii.gz
fugue -i func/rasub-020_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-04.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-020/fmap/sub-020_run-05_magnitude.nii fmap/sub-020_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-05_phasediff.nii -div 2 fmap/sub-020_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-05_phasediff_half.nii.gz fmap/sub-020_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-05.nii.gz -nan fmap/fmap_rads_sub-020_run-05.nii.gz
flirt -in fmap/sub-020_run-05_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-020_run-05.nii.gz -ref func/rasub-020_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-020_run-05.nii.gz
fugue -i func/rasub-020_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-05.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-020/fmap/sub-020_run-06_magnitude.nii fmap/sub-020_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-06_phasediff.nii -div 2 fmap/sub-020_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-06_phasediff_half.nii.gz fmap/sub-020_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-06.nii.gz -nan fmap/fmap_rads_sub-020_run-06.nii.gz
flirt -in fmap/sub-020_run-06_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-020_run-06.nii.gz -ref func/rasub-020_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-020_run-06.nii.gz
fugue -i func/rasub-020_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-06.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-020/fmap/sub-020_run-07_magnitude.nii fmap/sub-020_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-07_phasediff.nii -div 2 fmap/sub-020_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-07_phasediff_half.nii.gz fmap/sub-020_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-07.nii.gz -nan fmap/fmap_rads_sub-020_run-07.nii.gz
flirt -in fmap/sub-020_run-07_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-020_run-07.nii.gz -ref func/rasub-020_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-020_run-07.nii.gz
fugue -i func/rasub-020_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-07.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-020/fmap/sub-020_run-08_magnitude.nii fmap/sub-020_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-020/fmap/sub-020_run-08_phasediff.nii -div 2 fmap/sub-020_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-020_run-08_phasediff_half.nii.gz fmap/sub-020_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-020_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-020_run-08.nii.gz -nan fmap/fmap_rads_sub-020_run-08.nii.gz
flirt -in fmap/sub-020_run-08_magnitude_brain.nii.gz -ref func/rasub-020_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-020_run-08.nii.gz -ref func/rasub-020_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-020_run-08.nii.gz
fugue -i func/rasub-020_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-020_run-08.nii.gz --unwarpdir=y- -u func/urasub-020_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-020_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-020_run-01.nii.gz --unwarpdir=y- -u func/urasub-020_task-localizer_bold.nii.gz -v

%% SUB-021

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-021

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-021/fmap/sub-021_run-01_magnitude.nii fmap/sub-021_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-01_phasediff.nii -div 2 fmap/sub-021_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-01_phasediff_half.nii.gz fmap/sub-021_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-01.nii.gz -nan fmap/fmap_rads_sub-021_run-01.nii.gz
flirt -in fmap/sub-021_run-01_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-021_run-01.nii.gz -ref func/rasub-021_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-021_run-01.nii.gz
fugue -i func/rasub-021_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-01.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-021/fmap/sub-021_run-02_magnitude.nii fmap/sub-021_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-02_phasediff.nii -div 2 fmap/sub-021_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-02_phasediff_half.nii.gz fmap/sub-021_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-02.nii.gz -nan fmap/fmap_rads_sub-021_run-02.nii.gz
flirt -in fmap/sub-021_run-02_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-021_run-02.nii.gz -ref func/rasub-021_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-021_run-02.nii.gz
fugue -i func/rasub-021_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-02.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-021/fmap/sub-021_run-03_magnitude.nii fmap/sub-021_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-03_phasediff.nii -div 2 fmap/sub-021_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-03_phasediff_half.nii.gz fmap/sub-021_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-03.nii.gz -nan fmap/fmap_rads_sub-021_run-03.nii.gz
flirt -in fmap/sub-021_run-03_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-021_run-03.nii.gz -ref func/rasub-021_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-021_run-03.nii.gz
fugue -i func/rasub-021_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-03.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-021/fmap/sub-021_run-04_magnitude.nii fmap/sub-021_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-04_phasediff.nii -div 2 fmap/sub-021_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-04_phasediff_half.nii.gz fmap/sub-021_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-04.nii.gz -nan fmap/fmap_rads_sub-021_run-04.nii.gz
flirt -in fmap/sub-021_run-04_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-021_run-04.nii.gz -ref func/rasub-021_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-021_run-04.nii.gz
fugue -i func/rasub-021_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-04.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-021/fmap/sub-021_run-05_magnitude.nii fmap/sub-021_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-05_phasediff.nii -div 2 fmap/sub-021_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-05_phasediff_half.nii.gz fmap/sub-021_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-05.nii.gz -nan fmap/fmap_rads_sub-021_run-05.nii.gz
flirt -in fmap/sub-021_run-05_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-021_run-05.nii.gz -ref func/rasub-021_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-021_run-05.nii.gz
fugue -i func/rasub-021_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-05.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-021/fmap/sub-021_run-06_magnitude.nii fmap/sub-021_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-06_phasediff.nii -div 2 fmap/sub-021_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-06_phasediff_half.nii.gz fmap/sub-021_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-06.nii.gz -nan fmap/fmap_rads_sub-021_run-06.nii.gz
flirt -in fmap/sub-021_run-06_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-021_run-06.nii.gz -ref func/rasub-021_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-021_run-06.nii.gz
fugue -i func/rasub-021_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-06.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-06_bold.nii.gz -v
# RUN-07
bet ../../../rawdata/sub-021/fmap/sub-021_run-07_magnitude.nii fmap/sub-021_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-07_phasediff.nii -div 2 fmap/sub-021_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-07_phasediff_half.nii.gz fmap/sub-021_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-07.nii.gz -nan fmap/fmap_rads_sub-021_run-07.nii.gz
flirt -in fmap/sub-021_run-07_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-021_run-07.nii.gz -ref func/rasub-021_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-021_run-07.nii.gz
fugue -i func/rasub-021_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-07.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-021/fmap/sub-021_run-08_magnitude.nii fmap/sub-021_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-021/fmap/sub-021_run-08_phasediff.nii -div 2 fmap/sub-021_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-021_run-08_phasediff_half.nii.gz fmap/sub-021_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-021_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-021_run-08.nii.gz -nan fmap/fmap_rads_sub-021_run-08.nii.gz
flirt -in fmap/sub-021_run-08_magnitude_brain.nii.gz -ref func/rasub-021_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-021_run-08.nii.gz -ref func/rasub-021_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-021_run-08.nii.gz
fugue -i func/rasub-021_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-021_run-08.nii.gz --unwarpdir=y- -u func/urasub-021_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-021_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-021_run-01.nii.gz --unwarpdir=y- -u func/urasub-021_task-localizer_bold.nii.gz -v

%% SUB-022

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-022

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-022/fmap/sub-022_run-01_magnitude.nii fmap/sub-022_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-01_phasediff.nii -div 2 fmap/sub-022_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-01_phasediff_half.nii.gz fmap/sub-022_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-01.nii.gz -nan fmap/fmap_rads_sub-022_run-01.nii.gz
flirt -in fmap/sub-022_run-01_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-022_run-01.nii.gz -ref func/rasub-022_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-022_run-01.nii.gz
fugue -i func/rasub-022_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-01.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-022/fmap/sub-022_run-02_magnitude.nii fmap/sub-022_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-02_phasediff.nii -div 2 fmap/sub-022_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-02_phasediff_half.nii.gz fmap/sub-022_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-02.nii.gz -nan fmap/fmap_rads_sub-022_run-02.nii.gz
flirt -in fmap/sub-022_run-02_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-022_run-02.nii.gz -ref func/rasub-022_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-022_run-02.nii.gz
fugue -i func/rasub-022_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-02.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-022/fmap/sub-022_run-03_magnitude.nii fmap/sub-022_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-03_phasediff.nii -div 2 fmap/sub-022_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-03_phasediff_half.nii.gz fmap/sub-022_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-03.nii.gz -nan fmap/fmap_rads_sub-022_run-03.nii.gz
flirt -in fmap/sub-022_run-03_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-022_run-03.nii.gz -ref func/rasub-022_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-022_run-03.nii.gz
fugue -i func/rasub-022_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-03.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-022/fmap/sub-022_run-04_magnitude.nii fmap/sub-022_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-04_phasediff.nii -div 2 fmap/sub-022_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-04_phasediff_half.nii.gz fmap/sub-022_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-04.nii.gz -nan fmap/fmap_rads_sub-022_run-04.nii.gz
flirt -in fmap/sub-022_run-04_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-022_run-04.nii.gz -ref func/rasub-022_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-022_run-04.nii.gz
fugue -i func/rasub-022_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-04.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-022/fmap/sub-022_run-05_magnitude.nii fmap/sub-022_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-05_phasediff.nii -div 2 fmap/sub-022_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-05_phasediff_half.nii.gz fmap/sub-022_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-05.nii.gz -nan fmap/fmap_rads_sub-022_run-05.nii.gz
flirt -in fmap/sub-022_run-05_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-022_run-05.nii.gz -ref func/rasub-022_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-022_run-05.nii.gz
fugue -i func/rasub-022_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-05.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-022/fmap/sub-022_run-06_magnitude.nii fmap/sub-022_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-06_phasediff.nii -div 2 fmap/sub-022_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-06_phasediff_half.nii.gz fmap/sub-022_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-06.nii.gz -nan fmap/fmap_rads_sub-022_run-06.nii.gz
flirt -in fmap/sub-022_run-06_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-022_run-06.nii.gz -ref func/rasub-022_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-022_run-06.nii.gz
fugue -i func/rasub-022_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-06.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-022/fmap/sub-022_run-07_magnitude.nii fmap/sub-022_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-07_phasediff.nii -div 2 fmap/sub-022_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-07_phasediff_half.nii.gz fmap/sub-022_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-07.nii.gz -nan fmap/fmap_rads_sub-022_run-07.nii.gz
flirt -in fmap/sub-022_run-07_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-022_run-07.nii.gz -ref func/rasub-022_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-022_run-07.nii.gz
fugue -i func/rasub-022_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-07.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-022/fmap/sub-022_run-08_magnitude.nii fmap/sub-022_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-022/fmap/sub-022_run-08_phasediff.nii -div 2 fmap/sub-022_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-022_run-08_phasediff_half.nii.gz fmap/sub-022_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-022_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-022_run-08.nii.gz -nan fmap/fmap_rads_sub-022_run-08.nii.gz
flirt -in fmap/sub-022_run-08_magnitude_brain.nii.gz -ref func/rasub-022_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-022_run-08.nii.gz -ref func/rasub-022_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-022_run-08.nii.gz
fugue -i func/rasub-022_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-022_run-08.nii.gz --unwarpdir=y- -u func/urasub-022_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-022_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-022_run-01.nii.gz --unwarpdir=y- -u func/urasub-022_task-localizer_bold.nii.gz -v

%% SUB-023

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-023

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-023/fmap/sub-023_run-01_magnitude.nii fmap/sub-023_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-01_phasediff.nii -div 2 fmap/sub-023_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-01_phasediff_half.nii.gz fmap/sub-023_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-01.nii.gz -nan fmap/fmap_rads_sub-023_run-01.nii.gz
flirt -in fmap/sub-023_run-01_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-023_run-01.nii.gz -ref func/rasub-023_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -interp spline -out fmap/rfmap_rads_sub-023_run-01.nii.gz
fugue -i func/rasub-023_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-01.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-023/fmap/sub-023_run-02_magnitude.nii fmap/sub-023_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-02_phasediff.nii -div 2 fmap/sub-023_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-02_phasediff_half.nii.gz fmap/sub-023_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-02.nii.gz -nan fmap/fmap_rads_sub-023_run-02.nii.gz
flirt -in fmap/sub-023_run-02_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-023_run-02.nii.gz -ref func/rasub-023_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -interp spline -out fmap/rfmap_rads_sub-023_run-02.nii.gz
fugue -i func/rasub-023_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-02.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-023/fmap/sub-023_run-03_magnitude.nii fmap/sub-023_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-03_phasediff.nii -div 2 fmap/sub-023_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-03_phasediff_half.nii.gz fmap/sub-023_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-03.nii.gz -nan fmap/fmap_rads_sub-023_run-03.nii.gz
flirt -in fmap/sub-023_run-03_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-023_run-03.nii.gz -ref func/rasub-023_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -interp spline -out fmap/rfmap_rads_sub-023_run-03.nii.gz
fugue -i func/rasub-023_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-03.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-023/fmap/sub-023_run-04_magnitude.nii fmap/sub-023_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-04_phasediff.nii -div 2 fmap/sub-023_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-04_phasediff_half.nii.gz fmap/sub-023_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-04.nii.gz -nan fmap/fmap_rads_sub-023_run-04.nii.gz
flirt -in fmap/sub-023_run-04_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-023_run-04.nii.gz -ref func/rasub-023_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -interp spline -out fmap/rfmap_rads_sub-023_run-04.nii.gz
fugue -i func/rasub-023_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-04.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-023/fmap/sub-023_run-05_magnitude.nii fmap/sub-023_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-05_phasediff.nii -div 2 fmap/sub-023_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-05_phasediff_half.nii.gz fmap/sub-023_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-05.nii.gz -nan fmap/fmap_rads_sub-023_run-05.nii.gz
flirt -in fmap/sub-023_run-05_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-023_run-05.nii.gz -ref func/rasub-023_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -interp spline -out fmap/rfmap_rads_sub-023_run-05.nii.gz
fugue -i func/rasub-023_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-05.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-023/fmap/sub-023_run-06_magnitude.nii fmap/sub-023_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-06_phasediff.nii -div 2 fmap/sub-023_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-06_phasediff_half.nii.gz fmap/sub-023_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-06.nii.gz -nan fmap/fmap_rads_sub-023_run-06.nii.gz
flirt -in fmap/sub-023_run-06_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-023_run-06.nii.gz -ref func/rasub-023_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -interp spline -out fmap/rfmap_rads_sub-023_run-06.nii.gz
fugue -i func/rasub-023_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-06.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-023/fmap/sub-023_run-07_magnitude.nii fmap/sub-023_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-07_phasediff.nii -div 2 fmap/sub-023_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-07_phasediff_half.nii.gz fmap/sub-023_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-07.nii.gz -nan fmap/fmap_rads_sub-023_run-07.nii.gz
flirt -in fmap/sub-023_run-07_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-023_run-07.nii.gz -ref func/rasub-023_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -interp spline -out fmap/rfmap_rads_sub-023_run-07.nii.gz
fugue -i func/rasub-023_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-07.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-023/fmap/sub-023_run-08_magnitude.nii fmap/sub-023_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-023/fmap/sub-023_run-08_phasediff.nii -div 2 fmap/sub-023_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-023_run-08_phasediff_half.nii.gz fmap/sub-023_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-023_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-023_run-08.nii.gz -nan fmap/fmap_rads_sub-023_run-08.nii.gz
flirt -in fmap/sub-023_run-08_magnitude_brain.nii.gz -ref func/rasub-023_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-023_run-08.nii.gz -ref func/rasub-023_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -interp spline -out fmap/rfmap_rads_sub-023_run-08.nii.gz
fugue -i func/rasub-023_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-023_run-08.nii.gz --unwarpdir=y- -u func/urasub-023_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-023_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-023_run-01.nii.gz --unwarpdir=y- -u func/urasub-023_task-localizer_bold.nii.gz -v
