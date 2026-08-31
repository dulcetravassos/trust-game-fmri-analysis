%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Distortion Correction - Preparation, Coregistration, Unwarping (FSL) %
%                                                                        %
%   This step is performed entirely using FSL via a WSL terminal.        %
%   First, "real" magnitudes are skull-stripped using FSL BET. Second,   %
%   fieldmaps are prepared in native space using fsl_prepare_fieldmaps   %
%   ('fmap_rads_*.nii.gz'). Magnitude images are coregistered to the     %
%   functional space using FSL FLIRT. This spatial transformation is     %
%   then applied to the fieldmaps to create functionally-aligned         %
%   fieldmaps ('rfmap_rads_*.nii.gz'). Finally, FSL FUGUE applies these  %
%   resliced fieldmaps to the previously realigned BOLD images. The      %
%   output is a new set of functional images prefixed with 'u'           %
%   (unwarped) corrected for B0 magnetic field inhomogeneities.          %
%   This script handles multiple magnitudes (magnitude1, magnitude2)     %
%   with matrix size mismatches and "fake" magnitudes derived from T1w   %
%   (see scrip s04). Fieldmap smoothing prior to unwarping was           %
%   intentionally omitted to prevent signal degradation, with any        %
%   residual ghost voxels left to be addressed by smoothing and          %
%   implicit masking during 1st-level GLM estimation.                    %
%   Note: a 6 degree of freedom rigid-body transformation was enforced   %
%   in FLIRT, restricting the registration to translations and rotations %
%   only. This prevents the introduction of non-rigid (affine)           %
%   transformations that could artificially distort the geometry of the  %
%   fieldmap in order to better match the EPI data. This preserves the   %
%   physical integrity of the B0 fieldmap.                               %
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
bet ../../../rawdata/sub-915/fmap/sub-915_run-01_magnitude.nii fmap/sub-915_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-01_phasediff.nii -div 2 fmap/sub-915_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-01_phasediff_half.nii.gz fmap/sub-915_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-915_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-01.nii.gz -nan fmap/fmap_rads_sub-915_run-01.nii.gz
flirt -in fmap/sub-915_run-01_magnitude_brain.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-915_run-01.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-915_run-01.nii.gz
fugue -i func/rasub-915_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-01.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-01_bold.nii.gz -v
% ----------- s05_02 -----------
% Unzip rfmap* and ura* files and create JSONs (BIDS-compliant)

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with fmap run-02)

%% Special case: fake magnitude subjects

% The substitute/surrogate magnitude was already skull-stripped with SPM's native Segmentation tool.

% Example
% ----------- s05_01 -----------
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-01_phasediff.nii -div 2 fmap/sub-819_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-01_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-01.nii.gz -nan fmap/fmap_rads_sub-819_run-01.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-819_run-01.nii.gz -ref func/rasub-819_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-819_run-01.nii.gz
fugue -i func/rasub-819_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-01.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-01_bold.nii.gz -v
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

%% SUB-819

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-819

# RUN-01
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-01_phasediff.nii -div 2 fmap/sub-819_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-01_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-01.nii.gz -nan fmap/fmap_rads_sub-819_run-01.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-819_run-01.nii.gz -ref func/rasub-819_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-819_run-01.nii.gz
fugue -i func/rasub-819_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-01.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-01_bold.nii.gz -v

# RUN-02
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-02_phasediff.nii -div 2 fmap/sub-819_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-02_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-02.nii.gz -nan fmap/fmap_rads_sub-819_run-02.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-819_run-02.nii.gz -ref func/rasub-819_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-819_run-02.nii.gz
fugue -i func/rasub-819_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-02.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-02_bold.nii.gz -v

# RUN-03
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-03_phasediff.nii -div 2 fmap/sub-819_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-03_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-03.nii.gz -nan fmap/fmap_rads_sub-819_run-03.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-819_run-03.nii.gz -ref func/rasub-819_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-819_run-03.nii.gz
fugue -i func/rasub-819_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-03.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-03_bold.nii.gz -v

# RUN-04
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-04_phasediff.nii -div 2 fmap/sub-819_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-04_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-04.nii.gz -nan fmap/fmap_rads_sub-819_run-04.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-819_run-04.nii.gz -ref func/rasub-819_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-819_run-04.nii.gz
fugue -i func/rasub-819_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-04.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-04_bold.nii.gz -v

# RUN-05
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-05_phasediff.nii -div 2 fmap/sub-819_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-05_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-05.nii.gz -nan fmap/fmap_rads_sub-819_run-05.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-819_run-05.nii.gz -ref func/rasub-819_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-819_run-05.nii.gz
fugue -i func/rasub-819_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-05.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-05_bold.nii.gz -v

# RUN-06
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-06_phasediff.nii -div 2 fmap/sub-819_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-06_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-06.nii.gz -nan fmap/fmap_rads_sub-819_run-06.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-819_run-06.nii.gz -ref func/rasub-819_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-819_run-06.nii.gz
fugue -i func/rasub-819_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-06.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-06_bold.nii.gz -v

# RUN-07
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-07_phasediff.nii -div 2 fmap/sub-819_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-07_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-07.nii.gz -nan fmap/fmap_rads_sub-819_run-07.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-819_run-07.nii.gz -ref func/rasub-819_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-819_run-07.nii.gz
fugue -i func/rasub-819_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-07.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-07_bold.nii.gz -v

# RUN-08
fslmaths ../../../rawdata/sub-819/fmap/sub-819_run-08_phasediff.nii -div 2 fmap/sub-819_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-819_run-08_phasediff_half.nii.gz fmap/sub-819_run-01_magnitude.nii fmap/fmap_rads_sub-819_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-819_run-08.nii.gz -nan fmap/fmap_rads_sub-819_run-08.nii.gz
flirt -in fmap/sub-819_run-01_magnitude.nii -ref func/rasub-819_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-819_run-08.nii.gz -ref func/rasub-819_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-819_run-08.nii.gz
fugue -i func/rasub-819_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-819_run-08.nii.gz --unwarpdir=y- -u func/urasub-819_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-819_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-819_run-01.nii.gz --unwarpdir=y- -u func/urasub-819_task-localizer_bold.nii.gz -v

%% SUB-908

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-908

# RUN-01
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-01_phasediff.nii -div 2 fmap/sub-908_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-01_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-01.nii.gz -nan fmap/fmap_rads_sub-908_run-01.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-908_run-01.nii.gz -ref func/rasub-908_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-908_run-01.nii.gz
fugue -i func/rasub-908_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-01.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-01_bold.nii.gz -v

# RUN-02
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-02_phasediff.nii -div 2 fmap/sub-908_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-02_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-02.nii.gz -nan fmap/fmap_rads_sub-908_run-02.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-908_run-02.nii.gz -ref func/rasub-908_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-908_run-02.nii.gz
fugue -i func/rasub-908_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-02.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-02_bold.nii.gz -v

# RUN-03
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-03_phasediff.nii -div 2 fmap/sub-908_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-03_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-03.nii.gz -nan fmap/fmap_rads_sub-908_run-03.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-908_run-03.nii.gz -ref func/rasub-908_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-908_run-03.nii.gz
fugue -i func/rasub-908_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-03.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-03_bold.nii.gz -v

# RUN-04
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-04_phasediff.nii -div 2 fmap/sub-908_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-04_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-04.nii.gz -nan fmap/fmap_rads_sub-908_run-04.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-908_run-04.nii.gz -ref func/rasub-908_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-908_run-04.nii.gz
fugue -i func/rasub-908_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-04.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-04_bold.nii.gz -v

# RUN-05
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-05_phasediff.nii -div 2 fmap/sub-908_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-05_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-05.nii.gz -nan fmap/fmap_rads_sub-908_run-05.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-908_run-05.nii.gz -ref func/rasub-908_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-908_run-05.nii.gz
fugue -i func/rasub-908_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-05.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-05_bold.nii.gz -v

# RUN-06
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-06_phasediff.nii -div 2 fmap/sub-908_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-06_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-06.nii.gz -nan fmap/fmap_rads_sub-908_run-06.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-908_run-06.nii.gz -ref func/rasub-908_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-908_run-06.nii.gz
fugue -i func/rasub-908_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-06.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-06_bold.nii.gz -v

# RUN-07
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-07_phasediff.nii -div 2 fmap/sub-908_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-07_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-07.nii.gz -nan fmap/fmap_rads_sub-908_run-07.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-908_run-07.nii.gz -ref func/rasub-908_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-908_run-07.nii.gz
fugue -i func/rasub-908_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-07.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-07_bold.nii.gz -v

# RUN-08
fslmaths ../../../rawdata/sub-908/fmap/sub-908_run-08_phasediff.nii -div 2 fmap/sub-908_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-908_run-08_phasediff_half.nii.gz fmap/sub-908_run-01_magnitude.nii fmap/fmap_rads_sub-908_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-908_run-08.nii.gz -nan fmap/fmap_rads_sub-908_run-08.nii.gz
flirt -in fmap/sub-908_run-01_magnitude.nii -ref func/rasub-908_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-908_run-08.nii.gz -ref func/rasub-908_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-908_run-08.nii.gz
fugue -i func/rasub-908_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-908_run-08.nii.gz --unwarpdir=y- -u func/urasub-908_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-908_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-908_run-01.nii.gz --unwarpdir=y- -u func/urasub-908_task-localizer_bold.nii.gz -v

%% SUB-147

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-147

# RUN-01
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-01_phasediff.nii -div 2 fmap/sub-147_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-01_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-01.nii.gz -nan fmap/fmap_rads_sub-147_run-01.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-147_run-01.nii.gz -ref func/rasub-147_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-147_run-01.nii.gz
fugue -i func/rasub-147_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-01.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-01_bold.nii.gz -v

# RUN-02
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-02_phasediff.nii -div 2 fmap/sub-147_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-02_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-02.nii.gz -nan fmap/fmap_rads_sub-147_run-02.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-147_run-02.nii.gz -ref func/rasub-147_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-147_run-02.nii.gz
fugue -i func/rasub-147_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-02.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-02_bold.nii.gz -v

# RUN-03
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-03_phasediff.nii -div 2 fmap/sub-147_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-03_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-03.nii.gz -nan fmap/fmap_rads_sub-147_run-03.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-147_run-03.nii.gz -ref func/rasub-147_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-147_run-03.nii.gz
fugue -i func/rasub-147_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-03.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-03_bold.nii.gz -v

# RUN-04
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-04_phasediff.nii -div 2 fmap/sub-147_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-04_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-04.nii.gz -nan fmap/fmap_rads_sub-147_run-04.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-147_run-04.nii.gz -ref func/rasub-147_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-147_run-04.nii.gz
fugue -i func/rasub-147_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-04.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-04_bold.nii.gz -v

# RUN-05
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-05_phasediff.nii -div 2 fmap/sub-147_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-05_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-05.nii.gz -nan fmap/fmap_rads_sub-147_run-05.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-147_run-05.nii.gz -ref func/rasub-147_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-147_run-05.nii.gz
fugue -i func/rasub-147_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-05.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-05_bold.nii.gz -v

# RUN-06
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-06_phasediff.nii -div 2 fmap/sub-147_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-06_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-06.nii.gz -nan fmap/fmap_rads_sub-147_run-06.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-147_run-06.nii.gz -ref func/rasub-147_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-147_run-06.nii.gz
fugue -i func/rasub-147_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-06.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-06_bold.nii.gz -v

# RUN-07
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-07_phasediff.nii -div 2 fmap/sub-147_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-07_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-07.nii.gz -nan fmap/fmap_rads_sub-147_run-07.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-147_run-07.nii.gz -ref func/rasub-147_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-147_run-07.nii.gz
fugue -i func/rasub-147_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-07.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-07_bold.nii.gz -v

# RUN-08
fslmaths ../../../rawdata/sub-147/fmap/sub-147_run-08_phasediff.nii -div 2 fmap/sub-147_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-147_run-08_phasediff_half.nii.gz fmap/sub-147_run-01_magnitude.nii fmap/fmap_rads_sub-147_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-147_run-08.nii.gz -nan fmap/fmap_rads_sub-147_run-08.nii.gz
flirt -in fmap/sub-147_run-01_magnitude.nii -ref func/rasub-147_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-147_run-08.nii.gz -ref func/rasub-147_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-147_run-08.nii.gz
fugue -i func/rasub-147_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-147_run-08.nii.gz --unwarpdir=y- -u func/urasub-147_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-147_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-147_run-01.nii.gz --unwarpdir=y- -u func/urasub-147_task-localizer_bold.nii.gz -v

%% SUB-915

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-915

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-915/fmap/sub-915_run-01_magnitude.nii fmap/sub-915_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-01_phasediff.nii -div 2 fmap/sub-915_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-01_phasediff_half.nii.gz fmap/sub-915_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-915_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-01.nii.gz -nan fmap/fmap_rads_sub-915_run-01.nii.gz
flirt -in fmap/sub-915_run-01_magnitude_brain.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-915_run-01.nii.gz -ref func/rasub-915_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-915_run-01.nii.gz
fugue -i func/rasub-915_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-01.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-915/fmap/sub-915_run-02_magnitude1.nii fmap/sub-915_run-02_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-915_run-02_magnitude_brain.nii.gz -ref ../../../rawdata/sub-915/fmap/sub-915_run-02_phasediff.nii -applyxfm -usesqform -out fmap/sub-915_run-02_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-02_phasediff.nii -div 2 fmap/sub-915_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-02_phasediff_half.nii.gz fmap/sub-915_run-02_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-915_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-02.nii.gz -nan fmap/fmap_rads_sub-915_run-02.nii.gz
flirt -in fmap/sub-915_run-02_magnitude_brain_matched.nii.gz -ref func/rasub-915_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-915_run-02.nii.gz -ref func/rasub-915_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-915_run-02.nii.gz
fugue -i func/rasub-915_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-02.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-915/fmap/sub-915_run-03_magnitude1.nii fmap/sub-915_run-03_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-915_run-03_magnitude_brain.nii.gz -ref ../../../rawdata/sub-915/fmap/sub-915_run-03_phasediff.nii -applyxfm -usesqform -out fmap/sub-915_run-03_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-03_phasediff.nii -div 2 fmap/sub-915_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-03_phasediff_half.nii.gz fmap/sub-915_run-03_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-915_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-03.nii.gz -nan fmap/fmap_rads_sub-915_run-03.nii.gz
flirt -in fmap/sub-915_run-03_magnitude_brain_matched.nii.gz -ref func/rasub-915_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-915_run-03.nii.gz -ref func/rasub-915_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-915_run-03.nii.gz
fugue -i func/rasub-915_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-03.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-915/fmap/sub-915_run-04_magnitude.nii fmap/sub-915_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-04_phasediff.nii -div 2 fmap/sub-915_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-04_phasediff_half.nii.gz fmap/sub-915_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-915_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-04.nii.gz -nan fmap/fmap_rads_sub-915_run-04.nii.gz
flirt -in fmap/sub-915_run-04_magnitude_brain.nii.gz -ref func/rasub-915_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-915_run-04.nii.gz -ref func/rasub-915_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-915_run-04.nii.gz
fugue -i func/rasub-915_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-04.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-915/fmap/sub-915_run-05_magnitude.nii fmap/sub-915_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-05_phasediff.nii -div 2 fmap/sub-915_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-05_phasediff_half.nii.gz fmap/sub-915_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-915_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-05.nii.gz -nan fmap/fmap_rads_sub-915_run-05.nii.gz
flirt -in fmap/sub-915_run-05_magnitude_brain.nii.gz -ref func/rasub-915_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-915_run-05.nii.gz -ref func/rasub-915_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-915_run-05.nii.gz
fugue -i func/rasub-915_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-05.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-915/fmap/sub-915_run-06_magnitude1.nii fmap/sub-915_run-06_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-915_run-06_magnitude_brain.nii.gz -ref ../../../rawdata/sub-915/fmap/sub-915_run-06_phasediff.nii -applyxfm -usesqform -out fmap/sub-915_run-06_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-06_phasediff.nii -div 2 fmap/sub-915_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-06_phasediff_half.nii.gz fmap/sub-915_run-06_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-915_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-06.nii.gz -nan fmap/fmap_rads_sub-915_run-06.nii.gz
flirt -in fmap/sub-915_run-06_magnitude_brain_matched.nii.gz -ref func/rasub-915_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-915_run-06.nii.gz -ref func/rasub-915_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-915_run-06.nii.gz
fugue -i func/rasub-915_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-06.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-915/fmap/sub-915_run-07_magnitude1.nii fmap/sub-915_run-07_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-915_run-07_magnitude_brain.nii.gz -ref ../../../rawdata/sub-915/fmap/sub-915_run-07_phasediff.nii -applyxfm -usesqform -out fmap/sub-915_run-07_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-07_phasediff.nii -div 2 fmap/sub-915_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-07_phasediff_half.nii.gz fmap/sub-915_run-07_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-915_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-07.nii.gz -nan fmap/fmap_rads_sub-915_run-07.nii.gz
flirt -in fmap/sub-915_run-07_magnitude_brain_matched.nii.gz -ref func/rasub-915_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-915_run-07.nii.gz -ref func/rasub-915_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-915_run-07.nii.gz
fugue -i func/rasub-915_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-07.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-915/fmap/sub-915_run-08_magnitude.nii fmap/sub-915_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-915/fmap/sub-915_run-08_phasediff.nii -div 2 fmap/sub-915_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-915_run-08_phasediff_half.nii.gz fmap/sub-915_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-915_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-915_run-08.nii.gz -nan fmap/fmap_rads_sub-915_run-08.nii.gz
flirt -in fmap/sub-915_run-08_magnitude_brain.nii.gz -ref func/rasub-915_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-915_run-08.nii.gz -ref func/rasub-915_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-915_run-08.nii.gz
fugue -i func/rasub-915_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-915_run-08.nii.gz --unwarpdir=y- -u func/urasub-915_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-915_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-915_run-01.nii.gz --unwarpdir=y- -u func/urasub-915_task-localizer_bold.nii.gz -v

%% SUB-641

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-641

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-641/fmap/sub-641_run-01_magnitude.nii fmap/sub-641_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-01_phasediff.nii -div 2 fmap/sub-641_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-01_phasediff_half.nii.gz fmap/sub-641_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-01.nii.gz -nan fmap/fmap_rads_sub-641_run-01.nii.gz
flirt -in fmap/sub-641_run-01_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-641_run-01.nii.gz -ref func/rasub-641_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-641_run-01.nii.gz
fugue -i func/rasub-641_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-01.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-641/fmap/sub-641_run-02_magnitude.nii fmap/sub-641_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-02_phasediff.nii -div 2 fmap/sub-641_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-02_phasediff_half.nii.gz fmap/sub-641_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-02.nii.gz -nan fmap/fmap_rads_sub-641_run-02.nii.gz
flirt -in fmap/sub-641_run-02_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-641_run-02.nii.gz -ref func/rasub-641_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-641_run-02.nii.gz
fugue -i func/rasub-641_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-02.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-641/fmap/sub-641_run-03_magnitude.nii fmap/sub-641_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-03_phasediff.nii -div 2 fmap/sub-641_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-03_phasediff_half.nii.gz fmap/sub-641_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-03.nii.gz -nan fmap/fmap_rads_sub-641_run-03.nii.gz
flirt -in fmap/sub-641_run-03_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-641_run-03.nii.gz -ref func/rasub-641_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-641_run-03.nii.gz
fugue -i func/rasub-641_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-03.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-641/fmap/sub-641_run-04_magnitude.nii fmap/sub-641_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-04_phasediff.nii -div 2 fmap/sub-641_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-04_phasediff_half.nii.gz fmap/sub-641_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-04.nii.gz -nan fmap/fmap_rads_sub-641_run-04.nii.gz
flirt -in fmap/sub-641_run-04_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-641_run-04.nii.gz -ref func/rasub-641_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-641_run-04.nii.gz
fugue -i func/rasub-641_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-04.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-641/fmap/sub-641_run-05_magnitude.nii fmap/sub-641_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-05_phasediff.nii -div 2 fmap/sub-641_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-05_phasediff_half.nii.gz fmap/sub-641_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-05.nii.gz -nan fmap/fmap_rads_sub-641_run-05.nii.gz
flirt -in fmap/sub-641_run-05_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-641_run-05.nii.gz -ref func/rasub-641_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-641_run-05.nii.gz
fugue -i func/rasub-641_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-05.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-641/fmap/sub-641_run-06_magnitude.nii fmap/sub-641_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-06_phasediff.nii -div 2 fmap/sub-641_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-06_phasediff_half.nii.gz fmap/sub-641_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-06.nii.gz -nan fmap/fmap_rads_sub-641_run-06.nii.gz
flirt -in fmap/sub-641_run-06_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-641_run-06.nii.gz -ref func/rasub-641_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-641_run-06.nii.gz
fugue -i func/rasub-641_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-06.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-641/fmap/sub-641_run-07_magnitude.nii fmap/sub-641_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-07_phasediff.nii -div 2 fmap/sub-641_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-07_phasediff_half.nii.gz fmap/sub-641_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-07.nii.gz -nan fmap/fmap_rads_sub-641_run-07.nii.gz
flirt -in fmap/sub-641_run-07_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-641_run-07.nii.gz -ref func/rasub-641_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-641_run-07.nii.gz
fugue -i func/rasub-641_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-07.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-641/fmap/sub-641_run-08_magnitude.nii fmap/sub-641_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-641/fmap/sub-641_run-08_phasediff.nii -div 2 fmap/sub-641_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-641_run-08_phasediff_half.nii.gz fmap/sub-641_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-641_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-641_run-08.nii.gz -nan fmap/fmap_rads_sub-641_run-08.nii.gz
flirt -in fmap/sub-641_run-08_magnitude_brain.nii.gz -ref func/rasub-641_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-641_run-08.nii.gz -ref func/rasub-641_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-641_run-08.nii.gz
fugue -i func/rasub-641_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-641_run-08.nii.gz --unwarpdir=y- -u func/urasub-641_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-641_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-641_run-01.nii.gz --unwarpdir=y- -u func/urasub-641_task-localizer_bold.nii.gz -v

%% SUB-119

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-119

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-119/fmap/sub-119_run-01_magnitude.nii fmap/sub-119_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-01_phasediff.nii -div 2 fmap/sub-119_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-01_phasediff_half.nii.gz fmap/sub-119_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-01.nii.gz -nan fmap/fmap_rads_sub-119_run-01.nii.gz
flirt -in fmap/sub-119_run-01_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-119_run-01.nii.gz -ref func/rasub-119_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-119_run-01.nii.gz
fugue -i func/rasub-119_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-01.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-119/fmap/sub-119_run-02_magnitude.nii fmap/sub-119_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-02_phasediff.nii -div 2 fmap/sub-119_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-02_phasediff_half.nii.gz fmap/sub-119_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-02.nii.gz -nan fmap/fmap_rads_sub-119_run-02.nii.gz
flirt -in fmap/sub-119_run-02_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-119_run-02.nii.gz -ref func/rasub-119_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-119_run-02.nii.gz
fugue -i func/rasub-119_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-02.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-119/fmap/sub-119_run-03_magnitude.nii fmap/sub-119_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-03_phasediff.nii -div 2 fmap/sub-119_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-03_phasediff_half.nii.gz fmap/sub-119_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-03.nii.gz -nan fmap/fmap_rads_sub-119_run-03.nii.gz
flirt -in fmap/sub-119_run-03_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-119_run-03.nii.gz -ref func/rasub-119_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-119_run-03.nii.gz
fugue -i func/rasub-119_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-03.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-119/fmap/sub-119_run-04_magnitude.nii fmap/sub-119_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-04_phasediff.nii -div 2 fmap/sub-119_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-04_phasediff_half.nii.gz fmap/sub-119_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-04.nii.gz -nan fmap/fmap_rads_sub-119_run-04.nii.gz
flirt -in fmap/sub-119_run-04_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-119_run-04.nii.gz -ref func/rasub-119_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-119_run-04.nii.gz
fugue -i func/rasub-119_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-04.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-119/fmap/sub-119_run-05_magnitude.nii fmap/sub-119_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-05_phasediff.nii -div 2 fmap/sub-119_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-05_phasediff_half.nii.gz fmap/sub-119_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-05.nii.gz -nan fmap/fmap_rads_sub-119_run-05.nii.gz
flirt -in fmap/sub-119_run-05_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-119_run-05.nii.gz -ref func/rasub-119_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-119_run-05.nii.gz
fugue -i func/rasub-119_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-05.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-119/fmap/sub-119_run-06_magnitude.nii fmap/sub-119_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-06_phasediff.nii -div 2 fmap/sub-119_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-06_phasediff_half.nii.gz fmap/sub-119_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-06.nii.gz -nan fmap/fmap_rads_sub-119_run-06.nii.gz
flirt -in fmap/sub-119_run-06_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-119_run-06.nii.gz -ref func/rasub-119_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-119_run-06.nii.gz
fugue -i func/rasub-119_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-06.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-119/fmap/sub-119_run-07_magnitude.nii fmap/sub-119_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-07_phasediff.nii -div 2 fmap/sub-119_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-07_phasediff_half.nii.gz fmap/sub-119_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-07.nii.gz -nan fmap/fmap_rads_sub-119_run-07.nii.gz
flirt -in fmap/sub-119_run-07_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-119_run-07.nii.gz -ref func/rasub-119_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-119_run-07.nii.gz
fugue -i func/rasub-119_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-07.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-119/fmap/sub-119_run-08_magnitude.nii fmap/sub-119_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-119/fmap/sub-119_run-08_phasediff.nii -div 2 fmap/sub-119_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-119_run-08_phasediff_half.nii.gz fmap/sub-119_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-119_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-119_run-08.nii.gz -nan fmap/fmap_rads_sub-119_run-08.nii.gz
flirt -in fmap/sub-119_run-08_magnitude_brain.nii.gz -ref func/rasub-119_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-119_run-08.nii.gz -ref func/rasub-119_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-119_run-08.nii.gz
fugue -i func/rasub-119_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-119_run-08.nii.gz --unwarpdir=y- -u func/urasub-119_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-119_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-119_run-01.nii.gz --unwarpdir=y- -u func/urasub-119_task-localizer_bold.nii.gz -v

%% SUB-295

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-295

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-295/fmap/sub-295_run-01_magnitude1.nii fmap/sub-295_run-01_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-295_run-01_magnitude_brain.nii.gz -ref ../../../rawdata/sub-295/fmap/sub-295_run-01_phasediff.nii -applyxfm -usesqform -out fmap/sub-295_run-01_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-01_phasediff.nii -div 2 fmap/sub-295_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-01_phasediff_half.nii.gz fmap/sub-295_run-01_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-295_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-01.nii.gz -nan fmap/fmap_rads_sub-295_run-01.nii.gz
flirt -in fmap/sub-295_run-01_magnitude_brain_matched.nii.gz -ref func/rasub-295_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-295_run-01.nii.gz -ref func/rasub-295_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-295_run-01.nii.gz
fugue -i func/rasub-295_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-01.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-295/fmap/sub-295_run-02_magnitude1.nii fmap/sub-295_run-02_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-295_run-02_magnitude_brain.nii.gz -ref ../../../rawdata/sub-295/fmap/sub-295_run-02_phasediff.nii -applyxfm -usesqform -out fmap/sub-295_run-02_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-02_phasediff.nii -div 2 fmap/sub-295_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-02_phasediff_half.nii.gz fmap/sub-295_run-02_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-295_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-02.nii.gz -nan fmap/fmap_rads_sub-295_run-02.nii.gz
flirt -in fmap/sub-295_run-02_magnitude_brain_matched.nii.gz -ref func/rasub-295_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-295_run-02.nii.gz -ref func/rasub-295_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-295_run-02.nii.gz
fugue -i func/rasub-295_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-02.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-295/fmap/sub-295_run-03_magnitude1.nii fmap/sub-295_run-03_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-295_run-03_magnitude_brain.nii.gz -ref ../../../rawdata/sub-295/fmap/sub-295_run-03_phasediff.nii -applyxfm -usesqform -out fmap/sub-295_run-03_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-03_phasediff.nii -div 2 fmap/sub-295_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-03_phasediff_half.nii.gz fmap/sub-295_run-03_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-295_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-03.nii.gz -nan fmap/fmap_rads_sub-295_run-03.nii.gz
flirt -in fmap/sub-295_run-03_magnitude_brain_matched.nii.gz -ref func/rasub-295_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-295_run-03.nii.gz -ref func/rasub-295_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-295_run-03.nii.gz
fugue -i func/rasub-295_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-03.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-295/fmap/sub-295_run-04_magnitude1.nii fmap/sub-295_run-04_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-295_run-04_magnitude_brain.nii.gz -ref ../../../rawdata/sub-295/fmap/sub-295_run-04_phasediff.nii -applyxfm -usesqform -out fmap/sub-295_run-04_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-04_phasediff.nii -div 2 fmap/sub-295_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-04_phasediff_half.nii.gz fmap/sub-295_run-04_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-295_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-04.nii.gz -nan fmap/fmap_rads_sub-295_run-04.nii.gz
flirt -in fmap/sub-295_run-04_magnitude_brain_matched.nii.gz -ref func/rasub-295_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-295_run-04.nii.gz -ref func/rasub-295_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-295_run-04.nii.gz
fugue -i func/rasub-295_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-04.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-295/fmap/sub-295_run-05_magnitude.nii fmap/sub-295_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-05_phasediff.nii -div 2 fmap/sub-295_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-05_phasediff_half.nii.gz fmap/sub-295_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-295_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-05.nii.gz -nan fmap/fmap_rads_sub-295_run-05.nii.gz
flirt -in fmap/sub-295_run-05_magnitude_brain.nii.gz -ref func/rasub-295_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-295_run-05.nii.gz -ref func/rasub-295_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-295_run-05.nii.gz
fugue -i func/rasub-295_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-05.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-295/fmap/sub-295_run-06_magnitude2.nii fmap/sub-295_run-06_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-295_run-06_magnitude_brain.nii.gz -ref ../../../rawdata/sub-295/fmap/sub-295_run-06_phasediff.nii -applyxfm -usesqform -out fmap/sub-295_run-06_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-06_phasediff.nii -div 2 fmap/sub-295_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-06_phasediff_half.nii.gz fmap/sub-295_run-06_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-295_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-06.nii.gz -nan fmap/fmap_rads_sub-295_run-06.nii.gz
flirt -in fmap/sub-295_run-06_magnitude_brain_matched.nii.gz -ref func/rasub-295_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-295_run-06.nii.gz -ref func/rasub-295_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-295_run-06.nii.gz
fugue -i func/rasub-295_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-06.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-295/fmap/sub-295_run-07_magnitude.nii fmap/sub-295_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-07_phasediff.nii -div 2 fmap/sub-295_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-07_phasediff_half.nii.gz fmap/sub-295_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-295_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-07.nii.gz -nan fmap/fmap_rads_sub-295_run-07.nii.gz
flirt -in fmap/sub-295_run-07_magnitude_brain.nii.gz -ref func/rasub-295_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-295_run-07.nii.gz -ref func/rasub-295_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-295_run-07.nii.gz
fugue -i func/rasub-295_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-07.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-295/fmap/sub-295_run-08_magnitude2.nii fmap/sub-295_run-08_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-295_run-08_magnitude_brain.nii.gz -ref ../../../rawdata/sub-295/fmap/sub-295_run-08_phasediff.nii -applyxfm -usesqform -out fmap/sub-295_run-08_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-295/fmap/sub-295_run-08_phasediff.nii -div 2 fmap/sub-295_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-295_run-08_phasediff_half.nii.gz fmap/sub-295_run-08_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-295_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-295_run-08.nii.gz -nan fmap/fmap_rads_sub-295_run-08.nii.gz
flirt -in fmap/sub-295_run-08_magnitude_brain_matched.nii.gz -ref func/rasub-295_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-295_run-08.nii.gz -ref func/rasub-295_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-295_run-08.nii.gz
fugue -i func/rasub-295_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-295_run-08.nii.gz --unwarpdir=y- -u func/urasub-295_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-295_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-295_run-01.nii.gz --unwarpdir=y- -u func/urasub-295_task-localizer_bold.nii.gz -v

%% SUB-557

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-557

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-557/fmap/sub-557_run-01_magnitude.nii fmap/sub-557_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-01_phasediff.nii -div 2 fmap/sub-557_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-01_phasediff_half.nii.gz fmap/sub-557_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-01.nii.gz -nan fmap/fmap_rads_sub-557_run-01.nii.gz
flirt -in fmap/sub-557_run-01_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-557_run-01.nii.gz -ref func/rasub-557_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-557_run-01.nii.gz
fugue -i func/rasub-557_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-01.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-557/fmap/sub-557_run-02_magnitude.nii fmap/sub-557_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-02_phasediff.nii -div 2 fmap/sub-557_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-02_phasediff_half.nii.gz fmap/sub-557_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-02.nii.gz -nan fmap/fmap_rads_sub-557_run-02.nii.gz
flirt -in fmap/sub-557_run-02_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-557_run-02.nii.gz -ref func/rasub-557_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-557_run-02.nii.gz
fugue -i func/rasub-557_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-02.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-557/fmap/sub-557_run-03_magnitude.nii fmap/sub-557_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-03_phasediff.nii -div 2 fmap/sub-557_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-03_phasediff_half.nii.gz fmap/sub-557_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-03.nii.gz -nan fmap/fmap_rads_sub-557_run-03.nii.gz
flirt -in fmap/sub-557_run-03_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-557_run-03.nii.gz -ref func/rasub-557_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-557_run-03.nii.gz
fugue -i func/rasub-557_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-03.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-557/fmap/sub-557_run-04_magnitude.nii fmap/sub-557_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-04_phasediff.nii -div 2 fmap/sub-557_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-04_phasediff_half.nii.gz fmap/sub-557_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-04.nii.gz -nan fmap/fmap_rads_sub-557_run-04.nii.gz
flirt -in fmap/sub-557_run-04_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-557_run-04.nii.gz -ref func/rasub-557_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-557_run-04.nii.gz
fugue -i func/rasub-557_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-04.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-557/fmap/sub-557_run-05_magnitude.nii fmap/sub-557_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-05_phasediff.nii -div 2 fmap/sub-557_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-05_phasediff_half.nii.gz fmap/sub-557_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-05.nii.gz -nan fmap/fmap_rads_sub-557_run-05.nii.gz
flirt -in fmap/sub-557_run-05_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-557_run-05.nii.gz -ref func/rasub-557_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-557_run-05.nii.gz
fugue -i func/rasub-557_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-05.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-557/fmap/sub-557_run-06_magnitude.nii fmap/sub-557_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-06_phasediff.nii -div 2 fmap/sub-557_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-06_phasediff_half.nii.gz fmap/sub-557_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-06.nii.gz -nan fmap/fmap_rads_sub-557_run-06.nii.gz
flirt -in fmap/sub-557_run-06_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-557_run-06.nii.gz -ref func/rasub-557_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-557_run-06.nii.gz
fugue -i func/rasub-557_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-06.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-557/fmap/sub-557_run-07_magnitude.nii fmap/sub-557_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-07_phasediff.nii -div 2 fmap/sub-557_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-07_phasediff_half.nii.gz fmap/sub-557_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-07.nii.gz -nan fmap/fmap_rads_sub-557_run-07.nii.gz
flirt -in fmap/sub-557_run-07_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-557_run-07.nii.gz -ref func/rasub-557_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-557_run-07.nii.gz
fugue -i func/rasub-557_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-07.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-557/fmap/sub-557_run-08_magnitude.nii fmap/sub-557_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-557/fmap/sub-557_run-08_phasediff.nii -div 2 fmap/sub-557_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-557_run-08_phasediff_half.nii.gz fmap/sub-557_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-557_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-557_run-08.nii.gz -nan fmap/fmap_rads_sub-557_run-08.nii.gz
flirt -in fmap/sub-557_run-08_magnitude_brain.nii.gz -ref func/rasub-557_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-557_run-08.nii.gz -ref func/rasub-557_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-557_run-08.nii.gz
fugue -i func/rasub-557_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-557_run-08.nii.gz --unwarpdir=y- -u func/urasub-557_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-557_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-557_run-01.nii.gz --unwarpdir=y- -u func/urasub-557_task-localizer_bold.nii.gz -v

%% SUB-958

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-958

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-958/fmap/sub-958_run-01_magnitude.nii fmap/sub-958_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-01_phasediff.nii -div 2 fmap/sub-958_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-01_phasediff_half.nii.gz fmap/sub-958_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-01.nii.gz -nan fmap/fmap_rads_sub-958_run-01.nii.gz
flirt -in fmap/sub-958_run-01_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-958_run-01.nii.gz -ref func/rasub-958_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-958_run-01.nii.gz
fugue -i func/rasub-958_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-01.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-958/fmap/sub-958_run-02_magnitude.nii fmap/sub-958_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-02_phasediff.nii -div 2 fmap/sub-958_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-02_phasediff_half.nii.gz fmap/sub-958_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-02.nii.gz -nan fmap/fmap_rads_sub-958_run-02.nii.gz
flirt -in fmap/sub-958_run-02_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-958_run-02.nii.gz -ref func/rasub-958_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-958_run-02.nii.gz
fugue -i func/rasub-958_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-02.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-958/fmap/sub-958_run-03_magnitude.nii fmap/sub-958_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-03_phasediff.nii -div 2 fmap/sub-958_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-03_phasediff_half.nii.gz fmap/sub-958_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-03.nii.gz -nan fmap/fmap_rads_sub-958_run-03.nii.gz
flirt -in fmap/sub-958_run-03_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-958_run-03.nii.gz -ref func/rasub-958_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-958_run-03.nii.gz
fugue -i func/rasub-958_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-03.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-958/fmap/sub-958_run-04_magnitude.nii fmap/sub-958_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-04_phasediff.nii -div 2 fmap/sub-958_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-04_phasediff_half.nii.gz fmap/sub-958_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-04.nii.gz -nan fmap/fmap_rads_sub-958_run-04.nii.gz
flirt -in fmap/sub-958_run-04_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-958_run-04.nii.gz -ref func/rasub-958_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-958_run-04.nii.gz
fugue -i func/rasub-958_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-04.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-958/fmap/sub-958_run-05_magnitude.nii fmap/sub-958_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-05_phasediff.nii -div 2 fmap/sub-958_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-05_phasediff_half.nii.gz fmap/sub-958_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-05.nii.gz -nan fmap/fmap_rads_sub-958_run-05.nii.gz
flirt -in fmap/sub-958_run-05_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-958_run-05.nii.gz -ref func/rasub-958_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-958_run-05.nii.gz
fugue -i func/rasub-958_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-05.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-958/fmap/sub-958_run-06_magnitude.nii fmap/sub-958_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-06_phasediff.nii -div 2 fmap/sub-958_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-06_phasediff_half.nii.gz fmap/sub-958_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-06.nii.gz -nan fmap/fmap_rads_sub-958_run-06.nii.gz
flirt -in fmap/sub-958_run-06_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-958_run-06.nii.gz -ref func/rasub-958_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-958_run-06.nii.gz
fugue -i func/rasub-958_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-06.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-958/fmap/sub-958_run-07_magnitude.nii fmap/sub-958_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-07_phasediff.nii -div 2 fmap/sub-958_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-07_phasediff_half.nii.gz fmap/sub-958_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-07.nii.gz -nan fmap/fmap_rads_sub-958_run-07.nii.gz
flirt -in fmap/sub-958_run-07_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-958_run-07.nii.gz -ref func/rasub-958_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-958_run-07.nii.gz
fugue -i func/rasub-958_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-07.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-958/fmap/sub-958_run-08_magnitude.nii fmap/sub-958_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-958/fmap/sub-958_run-08_phasediff.nii -div 2 fmap/sub-958_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-958_run-08_phasediff_half.nii.gz fmap/sub-958_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-958_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-958_run-08.nii.gz -nan fmap/fmap_rads_sub-958_run-08.nii.gz
flirt -in fmap/sub-958_run-08_magnitude_brain.nii.gz -ref func/rasub-958_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-958_run-08.nii.gz -ref func/rasub-958_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-958_run-08.nii.gz
fugue -i func/rasub-958_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-958_run-08.nii.gz --unwarpdir=y- -u func/urasub-958_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-958_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-958_run-01.nii.gz --unwarpdir=y- -u func/urasub-958_task-localizer_bold.nii.gz -v

%% SUB-965

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-965

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-965/fmap/sub-965_run-01_magnitude.nii fmap/sub-965_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-01_phasediff.nii -div 2 fmap/sub-965_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-01_phasediff_half.nii.gz fmap/sub-965_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-01.nii.gz -nan fmap/fmap_rads_sub-965_run-01.nii.gz
flirt -in fmap/sub-965_run-01_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-965_run-01.nii.gz -ref func/rasub-965_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-965_run-01.nii.gz
fugue -i func/rasub-965_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-01.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-965/fmap/sub-965_run-02_magnitude.nii fmap/sub-965_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-02_phasediff.nii -div 2 fmap/sub-965_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-02_phasediff_half.nii.gz fmap/sub-965_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-02.nii.gz -nan fmap/fmap_rads_sub-965_run-02.nii.gz
flirt -in fmap/sub-965_run-02_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-965_run-02.nii.gz -ref func/rasub-965_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-965_run-02.nii.gz
fugue -i func/rasub-965_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-02.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-965/fmap/sub-965_run-03_magnitude.nii fmap/sub-965_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-03_phasediff.nii -div 2 fmap/sub-965_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-03_phasediff_half.nii.gz fmap/sub-965_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-03.nii.gz -nan fmap/fmap_rads_sub-965_run-03.nii.gz
flirt -in fmap/sub-965_run-03_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-965_run-03.nii.gz -ref func/rasub-965_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-965_run-03.nii.gz
fugue -i func/rasub-965_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-03.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-965/fmap/sub-965_run-04_magnitude.nii fmap/sub-965_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-04_phasediff.nii -div 2 fmap/sub-965_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-04_phasediff_half.nii.gz fmap/sub-965_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-04.nii.gz -nan fmap/fmap_rads_sub-965_run-04.nii.gz
flirt -in fmap/sub-965_run-04_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-965_run-04.nii.gz -ref func/rasub-965_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-965_run-04.nii.gz
fugue -i func/rasub-965_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-04.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-965/fmap/sub-965_run-05_magnitude.nii fmap/sub-965_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-05_phasediff.nii -div 2 fmap/sub-965_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-05_phasediff_half.nii.gz fmap/sub-965_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-05.nii.gz -nan fmap/fmap_rads_sub-965_run-05.nii.gz
flirt -in fmap/sub-965_run-05_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-965_run-05.nii.gz -ref func/rasub-965_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-965_run-05.nii.gz
fugue -i func/rasub-965_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-05.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-965/fmap/sub-965_run-06_magnitude.nii fmap/sub-965_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-06_phasediff.nii -div 2 fmap/sub-965_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-06_phasediff_half.nii.gz fmap/sub-965_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-06.nii.gz -nan fmap/fmap_rads_sub-965_run-06.nii.gz
flirt -in fmap/sub-965_run-06_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-965_run-06.nii.gz -ref func/rasub-965_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-965_run-06.nii.gz
fugue -i func/rasub-965_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-06.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-965/fmap/sub-965_run-07_magnitude.nii fmap/sub-965_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-07_phasediff.nii -div 2 fmap/sub-965_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-07_phasediff_half.nii.gz fmap/sub-965_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-07.nii.gz -nan fmap/fmap_rads_sub-965_run-07.nii.gz
flirt -in fmap/sub-965_run-07_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-965_run-07.nii.gz -ref func/rasub-965_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-965_run-07.nii.gz
fugue -i func/rasub-965_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-07.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-965/fmap/sub-965_run-08_magnitude.nii fmap/sub-965_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-965/fmap/sub-965_run-08_phasediff.nii -div 2 fmap/sub-965_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-965_run-08_phasediff_half.nii.gz fmap/sub-965_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-965_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-965_run-08.nii.gz -nan fmap/fmap_rads_sub-965_run-08.nii.gz
flirt -in fmap/sub-965_run-08_magnitude_brain.nii.gz -ref func/rasub-965_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-965_run-08.nii.gz -ref func/rasub-965_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-965_run-08.nii.gz
fugue -i func/rasub-965_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-965_run-08.nii.gz --unwarpdir=y- -u func/urasub-965_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-965_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-965_run-01.nii.gz --unwarpdir=y- -u func/urasub-965_task-localizer_bold.nii.gz -v

%% SUB-177

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-177

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-177/fmap/sub-177_run-01_magnitude.nii fmap/sub-177_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-01_phasediff.nii -div 2 fmap/sub-177_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-01_phasediff_half.nii.gz fmap/sub-177_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-01.nii.gz -nan fmap/fmap_rads_sub-177_run-01.nii.gz
flirt -in fmap/sub-177_run-01_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-177_run-01.nii.gz -ref func/rasub-177_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-177_run-01.nii.gz
fugue -i func/rasub-177_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-01.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-177/fmap/sub-177_run-02_magnitude.nii fmap/sub-177_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-02_phasediff.nii -div 2 fmap/sub-177_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-02_phasediff_half.nii.gz fmap/sub-177_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-02.nii.gz -nan fmap/fmap_rads_sub-177_run-02.nii.gz
flirt -in fmap/sub-177_run-02_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-177_run-02.nii.gz -ref func/rasub-177_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-177_run-02.nii.gz
fugue -i func/rasub-177_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-02.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-177/fmap/sub-177_run-03_magnitude.nii fmap/sub-177_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-03_phasediff.nii -div 2 fmap/sub-177_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-03_phasediff_half.nii.gz fmap/sub-177_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-03.nii.gz -nan fmap/fmap_rads_sub-177_run-03.nii.gz
flirt -in fmap/sub-177_run-03_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-177_run-03.nii.gz -ref func/rasub-177_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-177_run-03.nii.gz
fugue -i func/rasub-177_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-03.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-177/fmap/sub-177_run-04_magnitude.nii fmap/sub-177_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-04_phasediff.nii -div 2 fmap/sub-177_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-04_phasediff_half.nii.gz fmap/sub-177_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-04.nii.gz -nan fmap/fmap_rads_sub-177_run-04.nii.gz
flirt -in fmap/sub-177_run-04_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-177_run-04.nii.gz -ref func/rasub-177_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-177_run-04.nii.gz
fugue -i func/rasub-177_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-04.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-177/fmap/sub-177_run-05_magnitude.nii fmap/sub-177_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-05_phasediff.nii -div 2 fmap/sub-177_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-05_phasediff_half.nii.gz fmap/sub-177_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-05.nii.gz -nan fmap/fmap_rads_sub-177_run-05.nii.gz
flirt -in fmap/sub-177_run-05_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-177_run-05.nii.gz -ref func/rasub-177_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-177_run-05.nii.gz
fugue -i func/rasub-177_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-05.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-177/fmap/sub-177_run-06_magnitude.nii fmap/sub-177_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-06_phasediff.nii -div 2 fmap/sub-177_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-06_phasediff_half.nii.gz fmap/sub-177_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-06.nii.gz -nan fmap/fmap_rads_sub-177_run-06.nii.gz
flirt -in fmap/sub-177_run-06_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-177_run-06.nii.gz -ref func/rasub-177_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-177_run-06.nii.gz
fugue -i func/rasub-177_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-06.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-177/fmap/sub-177_run-07_magnitude.nii fmap/sub-177_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-07_phasediff.nii -div 2 fmap/sub-177_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-07_phasediff_half.nii.gz fmap/sub-177_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-07.nii.gz -nan fmap/fmap_rads_sub-177_run-07.nii.gz
flirt -in fmap/sub-177_run-07_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-177_run-07.nii.gz -ref func/rasub-177_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-177_run-07.nii.gz
fugue -i func/rasub-177_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-07.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-177/fmap/sub-177_run-08_magnitude.nii fmap/sub-177_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-177/fmap/sub-177_run-08_phasediff.nii -div 2 fmap/sub-177_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-177_run-08_phasediff_half.nii.gz fmap/sub-177_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-177_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-177_run-08.nii.gz -nan fmap/fmap_rads_sub-177_run-08.nii.gz
flirt -in fmap/sub-177_run-08_magnitude_brain.nii.gz -ref func/rasub-177_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-177_run-08.nii.gz -ref func/rasub-177_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-177_run-08.nii.gz
fugue -i func/rasub-177_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-177_run-08.nii.gz --unwarpdir=y- -u func/urasub-177_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-177_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-177_run-01.nii.gz --unwarpdir=y- -u func/urasub-177_task-localizer_bold.nii.gz -v

%% SUB-971

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-971

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-971/fmap/sub-971_run-01_magnitude.nii fmap/sub-971_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-01_phasediff.nii -div 2 fmap/sub-971_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-01_phasediff_half.nii.gz fmap/sub-971_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-971_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-01.nii.gz -nan fmap/fmap_rads_sub-971_run-01.nii.gz
flirt -in fmap/sub-971_run-01_magnitude_brain.nii.gz -ref func/rasub-971_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-971_run-01.nii.gz -ref func/rasub-971_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-971_run-01.nii.gz
fugue -i func/rasub-971_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-01.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-971/fmap/sub-971_run-02_magnitude1.nii fmap/sub-971_run-02_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-971_run-02_magnitude_brain.nii.gz -ref ../../../rawdata/sub-971/fmap/sub-971_run-02_phasediff.nii -applyxfm -usesqform -out fmap/sub-971_run-02_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-02_phasediff.nii -div 2 fmap/sub-971_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-02_phasediff_half.nii.gz fmap/sub-971_run-02_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-971_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-02.nii.gz -nan fmap/fmap_rads_sub-971_run-02.nii.gz
flirt -in fmap/sub-971_run-02_magnitude_brain_matched.nii.gz -ref func/rasub-971_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-971_run-02.nii.gz -ref func/rasub-971_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-971_run-02.nii.gz
fugue -i func/rasub-971_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-02.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-971/fmap/sub-971_run-03_magnitude.nii fmap/sub-971_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-03_phasediff.nii -div 2 fmap/sub-971_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-03_phasediff_half.nii.gz fmap/sub-971_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-971_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-03.nii.gz -nan fmap/fmap_rads_sub-971_run-03.nii.gz
flirt -in fmap/sub-971_run-03_magnitude_brain.nii.gz -ref func/rasub-971_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-971_run-03.nii.gz -ref func/rasub-971_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-971_run-03.nii.gz
fugue -i func/rasub-971_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-03.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-971/fmap/sub-971_run-04_magnitude1.nii fmap/sub-971_run-04_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-971_run-04_magnitude_brain.nii.gz -ref ../../../rawdata/sub-971/fmap/sub-971_run-04_phasediff.nii -applyxfm -usesqform -out fmap/sub-971_run-04_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-04_phasediff.nii -div 2 fmap/sub-971_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-04_phasediff_half.nii.gz fmap/sub-971_run-04_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-971_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-04.nii.gz -nan fmap/fmap_rads_sub-971_run-04.nii.gz
flirt -in fmap/sub-971_run-04_magnitude_brain_matched.nii.gz -ref func/rasub-971_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-971_run-04.nii.gz -ref func/rasub-971_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-971_run-04.nii.gz
fugue -i func/rasub-971_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-04.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-971/fmap/sub-971_run-05_magnitude1.nii fmap/sub-971_run-05_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-971_run-05_magnitude_brain.nii.gz -ref ../../../rawdata/sub-971/fmap/sub-971_run-05_phasediff.nii -applyxfm -usesqform -out fmap/sub-971_run-05_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-05_phasediff.nii -div 2 fmap/sub-971_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-05_phasediff_half.nii.gz fmap/sub-971_run-05_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-971_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-05.nii.gz -nan fmap/fmap_rads_sub-971_run-05.nii.gz
flirt -in fmap/sub-971_run-05_magnitude_brain_matched.nii.gz -ref func/rasub-971_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-971_run-05.nii.gz -ref func/rasub-971_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-971_run-05.nii.gz
fugue -i func/rasub-971_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-05.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-971/fmap/sub-971_run-06_magnitude.nii fmap/sub-971_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-06_phasediff.nii -div 2 fmap/sub-971_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-06_phasediff_half.nii.gz fmap/sub-971_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-971_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-06.nii.gz -nan fmap/fmap_rads_sub-971_run-06.nii.gz
flirt -in fmap/sub-971_run-06_magnitude_brain.nii.gz -ref func/rasub-971_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-971_run-06.nii.gz -ref func/rasub-971_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-971_run-06.nii.gz
fugue -i func/rasub-971_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-06.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-971/fmap/sub-971_run-07_magnitude.nii fmap/sub-971_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-07_phasediff.nii -div 2 fmap/sub-971_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-07_phasediff_half.nii.gz fmap/sub-971_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-971_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-07.nii.gz -nan fmap/fmap_rads_sub-971_run-07.nii.gz
flirt -in fmap/sub-971_run-07_magnitude_brain.nii.gz -ref func/rasub-971_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-971_run-07.nii.gz -ref func/rasub-971_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-971_run-07.nii.gz
fugue -i func/rasub-971_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-07.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-971/fmap/sub-971_run-08_magnitude1.nii fmap/sub-971_run-08_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-971_run-08_magnitude_brain.nii.gz -ref ../../../rawdata/sub-971/fmap/sub-971_run-08_phasediff.nii -applyxfm -usesqform -out fmap/sub-971_run-08_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-971/fmap/sub-971_run-08_phasediff.nii -div 2 fmap/sub-971_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-971_run-08_phasediff_half.nii.gz fmap/sub-971_run-08_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-971_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-971_run-08.nii.gz -nan fmap/fmap_rads_sub-971_run-08.nii.gz
flirt -in fmap/sub-971_run-08_magnitude_brain_matched.nii.gz -ref func/rasub-971_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-971_run-08.nii.gz -ref func/rasub-971_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-971_run-08.nii.gz
fugue -i func/rasub-971_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-971_run-08.nii.gz --unwarpdir=y- -u func/urasub-971_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-971_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-971_run-01.nii.gz --unwarpdir=y- -u func/urasub-971_task-localizer_bold.nii.gz -v

%% SUB-664

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-664

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-664/fmap/sub-664_run-01_magnitude.nii fmap/sub-664_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-01_phasediff.nii -div 2 fmap/sub-664_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-01_phasediff_half.nii.gz fmap/sub-664_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-01.nii.gz -nan fmap/fmap_rads_sub-664_run-01.nii.gz
flirt -in fmap/sub-664_run-01_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-664_run-01.nii.gz -ref func/rasub-664_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-664_run-01.nii.gz
fugue -i func/rasub-664_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-01.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-664/fmap/sub-664_run-02_magnitude.nii fmap/sub-664_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-02_phasediff.nii -div 2 fmap/sub-664_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-02_phasediff_half.nii.gz fmap/sub-664_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-02.nii.gz -nan fmap/fmap_rads_sub-664_run-02.nii.gz
flirt -in fmap/sub-664_run-02_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-664_run-02.nii.gz -ref func/rasub-664_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-664_run-02.nii.gz
fugue -i func/rasub-664_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-02.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-664/fmap/sub-664_run-03_magnitude.nii fmap/sub-664_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-03_phasediff.nii -div 2 fmap/sub-664_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-03_phasediff_half.nii.gz fmap/sub-664_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-03.nii.gz -nan fmap/fmap_rads_sub-664_run-03.nii.gz
flirt -in fmap/sub-664_run-03_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-664_run-03.nii.gz -ref func/rasub-664_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-664_run-03.nii.gz
fugue -i func/rasub-664_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-03.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-664/fmap/sub-664_run-04_magnitude.nii fmap/sub-664_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-04_phasediff.nii -div 2 fmap/sub-664_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-04_phasediff_half.nii.gz fmap/sub-664_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-04.nii.gz -nan fmap/fmap_rads_sub-664_run-04.nii.gz
flirt -in fmap/sub-664_run-04_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-664_run-04.nii.gz -ref func/rasub-664_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-664_run-04.nii.gz
fugue -i func/rasub-664_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-04.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-664/fmap/sub-664_run-05_magnitude.nii fmap/sub-664_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-05_phasediff.nii -div 2 fmap/sub-664_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-05_phasediff_half.nii.gz fmap/sub-664_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-05.nii.gz -nan fmap/fmap_rads_sub-664_run-05.nii.gz
flirt -in fmap/sub-664_run-05_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-664_run-05.nii.gz -ref func/rasub-664_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-664_run-05.nii.gz
fugue -i func/rasub-664_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-05.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-664/fmap/sub-664_run-06_magnitude.nii fmap/sub-664_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-06_phasediff.nii -div 2 fmap/sub-664_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-06_phasediff_half.nii.gz fmap/sub-664_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-06.nii.gz -nan fmap/fmap_rads_sub-664_run-06.nii.gz
flirt -in fmap/sub-664_run-06_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-664_run-06.nii.gz -ref func/rasub-664_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-664_run-06.nii.gz
fugue -i func/rasub-664_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-06.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-664/fmap/sub-664_run-07_magnitude.nii fmap/sub-664_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-07_phasediff.nii -div 2 fmap/sub-664_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-07_phasediff_half.nii.gz fmap/sub-664_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-07.nii.gz -nan fmap/fmap_rads_sub-664_run-07.nii.gz
flirt -in fmap/sub-664_run-07_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-664_run-07.nii.gz -ref func/rasub-664_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-664_run-07.nii.gz
fugue -i func/rasub-664_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-07.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-664/fmap/sub-664_run-08_magnitude.nii fmap/sub-664_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-664/fmap/sub-664_run-08_phasediff.nii -div 2 fmap/sub-664_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-664_run-08_phasediff_half.nii.gz fmap/sub-664_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-664_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-664_run-08.nii.gz -nan fmap/fmap_rads_sub-664_run-08.nii.gz
flirt -in fmap/sub-664_run-08_magnitude_brain.nii.gz -ref func/rasub-664_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-664_run-08.nii.gz -ref func/rasub-664_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-664_run-08.nii.gz
fugue -i func/rasub-664_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-664_run-08.nii.gz --unwarpdir=y- -u func/urasub-664_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-664_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-664_run-01.nii.gz --unwarpdir=y- -u func/urasub-664_task-localizer_bold.nii.gz -v

%% SUB-497

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-497

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-497/fmap/sub-497_run-01_magnitude.nii fmap/sub-497_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-01_phasediff.nii -div 2 fmap/sub-497_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-01_phasediff_half.nii.gz fmap/sub-497_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-01.nii.gz -nan fmap/fmap_rads_sub-497_run-01.nii.gz
flirt -in fmap/sub-497_run-01_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-497_run-01.nii.gz -ref func/rasub-497_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-497_run-01.nii.gz
fugue -i func/rasub-497_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-01.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-497/fmap/sub-497_run-02_magnitude.nii fmap/sub-497_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-02_phasediff.nii -div 2 fmap/sub-497_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-02_phasediff_half.nii.gz fmap/sub-497_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-02.nii.gz -nan fmap/fmap_rads_sub-497_run-02.nii.gz
flirt -in fmap/sub-497_run-02_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-497_run-02.nii.gz -ref func/rasub-497_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-497_run-02.nii.gz
fugue -i func/rasub-497_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-02.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-497/fmap/sub-497_run-03_magnitude.nii fmap/sub-497_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-03_phasediff.nii -div 2 fmap/sub-497_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-03_phasediff_half.nii.gz fmap/sub-497_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-03.nii.gz -nan fmap/fmap_rads_sub-497_run-03.nii.gz
flirt -in fmap/sub-497_run-03_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-497_run-03.nii.gz -ref func/rasub-497_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-497_run-03.nii.gz
fugue -i func/rasub-497_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-03.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-497/fmap/sub-497_run-04_magnitude.nii fmap/sub-497_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-04_phasediff.nii -div 2 fmap/sub-497_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-04_phasediff_half.nii.gz fmap/sub-497_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-04.nii.gz -nan fmap/fmap_rads_sub-497_run-04.nii.gz
flirt -in fmap/sub-497_run-04_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-497_run-04.nii.gz -ref func/rasub-497_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-497_run-04.nii.gz
fugue -i func/rasub-497_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-04.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-497/fmap/sub-497_run-05_magnitude.nii fmap/sub-497_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-05_phasediff.nii -div 2 fmap/sub-497_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-05_phasediff_half.nii.gz fmap/sub-497_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-05.nii.gz -nan fmap/fmap_rads_sub-497_run-05.nii.gz
flirt -in fmap/sub-497_run-05_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-497_run-05.nii.gz -ref func/rasub-497_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-497_run-05.nii.gz
fugue -i func/rasub-497_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-05.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-497/fmap/sub-497_run-06_magnitude.nii fmap/sub-497_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-06_phasediff.nii -div 2 fmap/sub-497_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-06_phasediff_half.nii.gz fmap/sub-497_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-06.nii.gz -nan fmap/fmap_rads_sub-497_run-06.nii.gz
flirt -in fmap/sub-497_run-06_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-497_run-06.nii.gz -ref func/rasub-497_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-497_run-06.nii.gz
fugue -i func/rasub-497_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-06.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-497/fmap/sub-497_run-07_magnitude.nii fmap/sub-497_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-07_phasediff.nii -div 2 fmap/sub-497_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-07_phasediff_half.nii.gz fmap/sub-497_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-07.nii.gz -nan fmap/fmap_rads_sub-497_run-07.nii.gz
flirt -in fmap/sub-497_run-07_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-497_run-07.nii.gz -ref func/rasub-497_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-497_run-07.nii.gz
fugue -i func/rasub-497_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-07.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-497/fmap/sub-497_run-08_magnitude.nii fmap/sub-497_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-497/fmap/sub-497_run-08_phasediff.nii -div 2 fmap/sub-497_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-497_run-08_phasediff_half.nii.gz fmap/sub-497_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-497_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-497_run-08.nii.gz -nan fmap/fmap_rads_sub-497_run-08.nii.gz
flirt -in fmap/sub-497_run-08_magnitude_brain.nii.gz -ref func/rasub-497_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-497_run-08.nii.gz -ref func/rasub-497_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-497_run-08.nii.gz
fugue -i func/rasub-497_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-497_run-08.nii.gz --unwarpdir=y- -u func/urasub-497_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-497_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-497_run-01.nii.gz --unwarpdir=y- -u func/urasub-497_task-localizer_bold.nii.gz -v

%% SUB-805

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-805

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-805/fmap/sub-805_run-01_magnitude.nii fmap/sub-805_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-01_phasediff.nii -div 2 fmap/sub-805_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-01_phasediff_half.nii.gz fmap/sub-805_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-01.nii.gz -nan fmap/fmap_rads_sub-805_run-01.nii.gz
flirt -in fmap/sub-805_run-01_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-805_run-01.nii.gz -ref func/rasub-805_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-805_run-01.nii.gz
fugue -i func/rasub-805_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-01.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-805/fmap/sub-805_run-02_magnitude.nii fmap/sub-805_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-02_phasediff.nii -div 2 fmap/sub-805_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-02_phasediff_half.nii.gz fmap/sub-805_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-02.nii.gz -nan fmap/fmap_rads_sub-805_run-02.nii.gz
flirt -in fmap/sub-805_run-02_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-805_run-02.nii.gz -ref func/rasub-805_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-805_run-02.nii.gz
fugue -i func/rasub-805_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-02.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-805/fmap/sub-805_run-03_magnitude.nii fmap/sub-805_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-03_phasediff.nii -div 2 fmap/sub-805_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-03_phasediff_half.nii.gz fmap/sub-805_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-03.nii.gz -nan fmap/fmap_rads_sub-805_run-03.nii.gz
flirt -in fmap/sub-805_run-03_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-805_run-03.nii.gz -ref func/rasub-805_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-805_run-03.nii.gz
fugue -i func/rasub-805_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-03.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-805/fmap/sub-805_run-04_magnitude.nii fmap/sub-805_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-04_phasediff.nii -div 2 fmap/sub-805_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-04_phasediff_half.nii.gz fmap/sub-805_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-04.nii.gz -nan fmap/fmap_rads_sub-805_run-04.nii.gz
flirt -in fmap/sub-805_run-04_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-805_run-04.nii.gz -ref func/rasub-805_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-805_run-04.nii.gz
fugue -i func/rasub-805_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-04.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-805/fmap/sub-805_run-05_magnitude.nii fmap/sub-805_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-05_phasediff.nii -div 2 fmap/sub-805_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-05_phasediff_half.nii.gz fmap/sub-805_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-05.nii.gz -nan fmap/fmap_rads_sub-805_run-05.nii.gz
flirt -in fmap/sub-805_run-05_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-805_run-05.nii.gz -ref func/rasub-805_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-805_run-05.nii.gz
fugue -i func/rasub-805_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-05.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-805/fmap/sub-805_run-06_magnitude.nii fmap/sub-805_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-06_phasediff.nii -div 2 fmap/sub-805_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-06_phasediff_half.nii.gz fmap/sub-805_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-06.nii.gz -nan fmap/fmap_rads_sub-805_run-06.nii.gz
flirt -in fmap/sub-805_run-06_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-805_run-06.nii.gz -ref func/rasub-805_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-805_run-06.nii.gz
fugue -i func/rasub-805_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-06.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-805/fmap/sub-805_run-07_magnitude.nii fmap/sub-805_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-07_phasediff.nii -div 2 fmap/sub-805_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-07_phasediff_half.nii.gz fmap/sub-805_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-07.nii.gz -nan fmap/fmap_rads_sub-805_run-07.nii.gz
flirt -in fmap/sub-805_run-07_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-805_run-07.nii.gz -ref func/rasub-805_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-805_run-07.nii.gz
fugue -i func/rasub-805_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-07.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-805/fmap/sub-805_run-08_magnitude.nii fmap/sub-805_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-805/fmap/sub-805_run-08_phasediff.nii -div 2 fmap/sub-805_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-805_run-08_phasediff_half.nii.gz fmap/sub-805_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-805_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-805_run-08.nii.gz -nan fmap/fmap_rads_sub-805_run-08.nii.gz
flirt -in fmap/sub-805_run-08_magnitude_brain.nii.gz -ref func/rasub-805_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-805_run-08.nii.gz -ref func/rasub-805_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-805_run-08.nii.gz
fugue -i func/rasub-805_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-805_run-08.nii.gz --unwarpdir=y- -u func/urasub-805_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-805_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-805_run-01.nii.gz --unwarpdir=y- -u func/urasub-805_task-localizer_bold.nii.gz -v

%% SUB-162

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-162

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-162/fmap/sub-162_run-01_magnitude.nii fmap/sub-162_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-01_phasediff.nii -div 2 fmap/sub-162_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-01_phasediff_half.nii.gz fmap/sub-162_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-162_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-01.nii.gz -nan fmap/fmap_rads_sub-162_run-01.nii.gz
flirt -in fmap/sub-162_run-01_magnitude_brain.nii.gz -ref func/rasub-162_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-162_run-01.nii.gz -ref func/rasub-162_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-162_run-01.nii.gz
fugue -i func/rasub-162_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-01.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-162/fmap/sub-162_run-02_magnitude.nii fmap/sub-162_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-02_phasediff.nii -div 2 fmap/sub-162_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-02_phasediff_half.nii.gz fmap/sub-162_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-162_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-02.nii.gz -nan fmap/fmap_rads_sub-162_run-02.nii.gz
flirt -in fmap/sub-162_run-02_magnitude_brain.nii.gz -ref func/rasub-162_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-162_run-02.nii.gz -ref func/rasub-162_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-162_run-02.nii.gz
fugue -i func/rasub-162_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-02.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-162/fmap/sub-162_run-03_magnitude1.nii fmap/sub-162_run-03_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-162_run-03_magnitude_brain.nii.gz -ref ../../../rawdata/sub-162/fmap/sub-162_run-03_phasediff.nii -applyxfm -usesqform -out fmap/sub-162_run-03_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-03_phasediff.nii -div 2 fmap/sub-162_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-03_phasediff_half.nii.gz fmap/sub-162_run-03_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-162_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-03.nii.gz -nan fmap/fmap_rads_sub-162_run-03.nii.gz
flirt -in fmap/sub-162_run-03_magnitude_brain_matched.nii.gz -ref func/rasub-162_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-162_run-03.nii.gz -ref func/rasub-162_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-162_run-03.nii.gz
fugue -i func/rasub-162_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-03.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-162/fmap/sub-162_run-04_magnitude1.nii fmap/sub-162_run-04_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-162_run-04_magnitude_brain.nii.gz -ref ../../../rawdata/sub-162/fmap/sub-162_run-04_phasediff.nii -applyxfm -usesqform -out fmap/sub-162_run-04_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-04_phasediff.nii -div 2 fmap/sub-162_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-04_phasediff_half.nii.gz fmap/sub-162_run-04_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-162_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-04.nii.gz -nan fmap/fmap_rads_sub-162_run-04.nii.gz
flirt -in fmap/sub-162_run-04_magnitude_brain_matched.nii.gz -ref func/rasub-162_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-162_run-04.nii.gz -ref func/rasub-162_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-162_run-04.nii.gz
fugue -i func/rasub-162_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-04.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-162/fmap/sub-162_run-05_magnitude1.nii fmap/sub-162_run-05_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-162_run-05_magnitude_brain.nii.gz -ref ../../../rawdata/sub-162/fmap/sub-162_run-05_phasediff.nii -applyxfm -usesqform -out fmap/sub-162_run-05_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-05_phasediff.nii -div 2 fmap/sub-162_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-05_phasediff_half.nii.gz fmap/sub-162_run-05_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-162_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-05.nii.gz -nan fmap/fmap_rads_sub-162_run-05.nii.gz
flirt -in fmap/sub-162_run-05_magnitude_brain_matched.nii.gz -ref func/rasub-162_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-162_run-05.nii.gz -ref func/rasub-162_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-162_run-05.nii.gz
fugue -i func/rasub-162_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-05.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-162/fmap/sub-162_run-06_magnitude.nii fmap/sub-162_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-06_phasediff.nii -div 2 fmap/sub-162_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-06_phasediff_half.nii.gz fmap/sub-162_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-162_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-06.nii.gz -nan fmap/fmap_rads_sub-162_run-06.nii.gz
flirt -in fmap/sub-162_run-06_magnitude_brain.nii.gz -ref func/rasub-162_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-162_run-06.nii.gz -ref func/rasub-162_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-162_run-06.nii.gz
fugue -i func/rasub-162_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-06.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-162/fmap/sub-162_run-07_magnitude1.nii fmap/sub-162_run-07_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-162_run-07_magnitude_brain.nii.gz -ref ../../../rawdata/sub-162/fmap/sub-162_run-07_phasediff.nii -applyxfm -usesqform -out fmap/sub-162_run-07_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-07_phasediff.nii -div 2 fmap/sub-162_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-07_phasediff_half.nii.gz fmap/sub-162_run-07_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-162_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-07.nii.gz -nan fmap/fmap_rads_sub-162_run-07.nii.gz
flirt -in fmap/sub-162_run-07_magnitude_brain_matched.nii.gz -ref func/rasub-162_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-162_run-07.nii.gz -ref func/rasub-162_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-162_run-07.nii.gz
fugue -i func/rasub-162_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-07.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-162/fmap/sub-162_run-08_magnitude1.nii fmap/sub-162_run-08_magnitude_brain.nii.gz -f 0.5 -m
flirt -in fmap/sub-162_run-08_magnitude_brain.nii.gz -ref ../../../rawdata/sub-162/fmap/sub-162_run-08_phasediff.nii -applyxfm -usesqform -out fmap/sub-162_run-08_magnitude_brain_matched.nii.gz
fslmaths ../../../rawdata/sub-162/fmap/sub-162_run-08_phasediff.nii -div 2 fmap/sub-162_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-162_run-08_phasediff_half.nii.gz fmap/sub-162_run-08_magnitude_brain_matched.nii.gz fmap/fmap_rads_sub-162_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-162_run-08.nii.gz -nan fmap/fmap_rads_sub-162_run-08.nii.gz
flirt -in fmap/sub-162_run-08_magnitude_brain_matched.nii.gz -ref func/rasub-162_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-162_run-08.nii.gz -ref func/rasub-162_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-162_run-08.nii.gz
fugue -i func/rasub-162_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-162_run-08.nii.gz --unwarpdir=y- -u func/urasub-162_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-162_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-162_run-01.nii.gz --unwarpdir=y- -u func/urasub-162_task-localizer_bold.nii.gz -v

%% SUB-435

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-435

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-435/fmap/sub-435_run-01_magnitude.nii fmap/sub-435_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-01_phasediff.nii -div 2 fmap/sub-435_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-01_phasediff_half.nii.gz fmap/sub-435_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-01.nii.gz -nan fmap/fmap_rads_sub-435_run-01.nii.gz
flirt -in fmap/sub-435_run-01_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-435_run-01.nii.gz -ref func/rasub-435_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-435_run-01.nii.gz
fugue -i func/rasub-435_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-01.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-435/fmap/sub-435_run-02_magnitude.nii fmap/sub-435_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-02_phasediff.nii -div 2 fmap/sub-435_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-02_phasediff_half.nii.gz fmap/sub-435_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-02.nii.gz -nan fmap/fmap_rads_sub-435_run-02.nii.gz
flirt -in fmap/sub-435_run-02_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-435_run-02.nii.gz -ref func/rasub-435_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-435_run-02.nii.gz
fugue -i func/rasub-435_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-02.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-435/fmap/sub-435_run-03_magnitude.nii fmap/sub-435_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-03_phasediff.nii -div 2 fmap/sub-435_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-03_phasediff_half.nii.gz fmap/sub-435_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-03.nii.gz -nan fmap/fmap_rads_sub-435_run-03.nii.gz
flirt -in fmap/sub-435_run-03_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-435_run-03.nii.gz -ref func/rasub-435_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-435_run-03.nii.gz
fugue -i func/rasub-435_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-03.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-435/fmap/sub-435_run-04_magnitude.nii fmap/sub-435_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-04_phasediff.nii -div 2 fmap/sub-435_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-04_phasediff_half.nii.gz fmap/sub-435_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-04.nii.gz -nan fmap/fmap_rads_sub-435_run-04.nii.gz
flirt -in fmap/sub-435_run-04_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-435_run-04.nii.gz -ref func/rasub-435_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-435_run-04.nii.gz
fugue -i func/rasub-435_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-04.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-435/fmap/sub-435_run-05_magnitude.nii fmap/sub-435_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-05_phasediff.nii -div 2 fmap/sub-435_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-05_phasediff_half.nii.gz fmap/sub-435_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-05.nii.gz -nan fmap/fmap_rads_sub-435_run-05.nii.gz
flirt -in fmap/sub-435_run-05_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-435_run-05.nii.gz -ref func/rasub-435_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-435_run-05.nii.gz
fugue -i func/rasub-435_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-05.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-435/fmap/sub-435_run-06_magnitude.nii fmap/sub-435_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-06_phasediff.nii -div 2 fmap/sub-435_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-06_phasediff_half.nii.gz fmap/sub-435_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-06.nii.gz -nan fmap/fmap_rads_sub-435_run-06.nii.gz
flirt -in fmap/sub-435_run-06_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-435_run-06.nii.gz -ref func/rasub-435_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-435_run-06.nii.gz
fugue -i func/rasub-435_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-06.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-435/fmap/sub-435_run-07_magnitude.nii fmap/sub-435_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-07_phasediff.nii -div 2 fmap/sub-435_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-07_phasediff_half.nii.gz fmap/sub-435_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-07.nii.gz -nan fmap/fmap_rads_sub-435_run-07.nii.gz
flirt -in fmap/sub-435_run-07_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-435_run-07.nii.gz -ref func/rasub-435_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-435_run-07.nii.gz
fugue -i func/rasub-435_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-07.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-435/fmap/sub-435_run-08_magnitude.nii fmap/sub-435_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-435/fmap/sub-435_run-08_phasediff.nii -div 2 fmap/sub-435_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-435_run-08_phasediff_half.nii.gz fmap/sub-435_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-435_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-435_run-08.nii.gz -nan fmap/fmap_rads_sub-435_run-08.nii.gz
flirt -in fmap/sub-435_run-08_magnitude_brain.nii.gz -ref func/rasub-435_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-435_run-08.nii.gz -ref func/rasub-435_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-435_run-08.nii.gz
fugue -i func/rasub-435_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-435_run-08.nii.gz --unwarpdir=y- -u func/urasub-435_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-435_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-435_run-01.nii.gz --unwarpdir=y- -u func/urasub-435_task-localizer_bold.nii.gz -v

%% SUB-917

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-917

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-917/fmap/sub-917_run-01_magnitude.nii fmap/sub-917_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-01_phasediff.nii -div 2 fmap/sub-917_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-01_phasediff_half.nii.gz fmap/sub-917_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-01.nii.gz -nan fmap/fmap_rads_sub-917_run-01.nii.gz
flirt -in fmap/sub-917_run-01_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-917_run-01.nii.gz -ref func/rasub-917_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-917_run-01.nii.gz
fugue -i func/rasub-917_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-01.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-917/fmap/sub-917_run-02_magnitude.nii fmap/sub-917_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-02_phasediff.nii -div 2 fmap/sub-917_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-02_phasediff_half.nii.gz fmap/sub-917_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-02.nii.gz -nan fmap/fmap_rads_sub-917_run-02.nii.gz
flirt -in fmap/sub-917_run-02_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-917_run-02.nii.gz -ref func/rasub-917_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-917_run-02.nii.gz
fugue -i func/rasub-917_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-02.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-917/fmap/sub-917_run-03_magnitude.nii fmap/sub-917_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-03_phasediff.nii -div 2 fmap/sub-917_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-03_phasediff_half.nii.gz fmap/sub-917_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-03.nii.gz -nan fmap/fmap_rads_sub-917_run-03.nii.gz
flirt -in fmap/sub-917_run-03_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-917_run-03.nii.gz -ref func/rasub-917_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-917_run-03.nii.gz
fugue -i func/rasub-917_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-03.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-917/fmap/sub-917_run-04_magnitude.nii fmap/sub-917_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-04_phasediff.nii -div 2 fmap/sub-917_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-04_phasediff_half.nii.gz fmap/sub-917_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-04.nii.gz -nan fmap/fmap_rads_sub-917_run-04.nii.gz
flirt -in fmap/sub-917_run-04_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-917_run-04.nii.gz -ref func/rasub-917_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-917_run-04.nii.gz
fugue -i func/rasub-917_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-04.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-917/fmap/sub-917_run-05_magnitude.nii fmap/sub-917_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-05_phasediff.nii -div 2 fmap/sub-917_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-05_phasediff_half.nii.gz fmap/sub-917_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-05.nii.gz -nan fmap/fmap_rads_sub-917_run-05.nii.gz
flirt -in fmap/sub-917_run-05_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-917_run-05.nii.gz -ref func/rasub-917_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-917_run-05.nii.gz
fugue -i func/rasub-917_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-05.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-917/fmap/sub-917_run-06_magnitude.nii fmap/sub-917_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-06_phasediff.nii -div 2 fmap/sub-917_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-06_phasediff_half.nii.gz fmap/sub-917_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-06.nii.gz -nan fmap/fmap_rads_sub-917_run-06.nii.gz
flirt -in fmap/sub-917_run-06_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-917_run-06.nii.gz -ref func/rasub-917_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-917_run-06.nii.gz
fugue -i func/rasub-917_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-06.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-06_bold.nii.gz -v
# RUN-07
bet ../../../rawdata/sub-917/fmap/sub-917_run-07_magnitude.nii fmap/sub-917_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-07_phasediff.nii -div 2 fmap/sub-917_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-07_phasediff_half.nii.gz fmap/sub-917_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-07.nii.gz -nan fmap/fmap_rads_sub-917_run-07.nii.gz
flirt -in fmap/sub-917_run-07_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-917_run-07.nii.gz -ref func/rasub-917_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-917_run-07.nii.gz
fugue -i func/rasub-917_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-07.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-917/fmap/sub-917_run-08_magnitude.nii fmap/sub-917_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-917/fmap/sub-917_run-08_phasediff.nii -div 2 fmap/sub-917_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-917_run-08_phasediff_half.nii.gz fmap/sub-917_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-917_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-917_run-08.nii.gz -nan fmap/fmap_rads_sub-917_run-08.nii.gz
flirt -in fmap/sub-917_run-08_magnitude_brain.nii.gz -ref func/rasub-917_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-917_run-08.nii.gz -ref func/rasub-917_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-917_run-08.nii.gz
fugue -i func/rasub-917_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-917_run-08.nii.gz --unwarpdir=y- -u func/urasub-917_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-917_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-917_run-01.nii.gz --unwarpdir=y- -u func/urasub-917_task-localizer_bold.nii.gz -v

%% SUB-797

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-797

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-797/fmap/sub-797_run-01_magnitude.nii fmap/sub-797_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-01_phasediff.nii -div 2 fmap/sub-797_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-01_phasediff_half.nii.gz fmap/sub-797_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-01.nii.gz -nan fmap/fmap_rads_sub-797_run-01.nii.gz
flirt -in fmap/sub-797_run-01_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-797_run-01.nii.gz -ref func/rasub-797_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-797_run-01.nii.gz
fugue -i func/rasub-797_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-01.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-797/fmap/sub-797_run-02_magnitude.nii fmap/sub-797_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-02_phasediff.nii -div 2 fmap/sub-797_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-02_phasediff_half.nii.gz fmap/sub-797_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-02.nii.gz -nan fmap/fmap_rads_sub-797_run-02.nii.gz
flirt -in fmap/sub-797_run-02_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-797_run-02.nii.gz -ref func/rasub-797_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-797_run-02.nii.gz
fugue -i func/rasub-797_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-02.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-797/fmap/sub-797_run-03_magnitude.nii fmap/sub-797_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-03_phasediff.nii -div 2 fmap/sub-797_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-03_phasediff_half.nii.gz fmap/sub-797_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-03.nii.gz -nan fmap/fmap_rads_sub-797_run-03.nii.gz
flirt -in fmap/sub-797_run-03_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-797_run-03.nii.gz -ref func/rasub-797_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-797_run-03.nii.gz
fugue -i func/rasub-797_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-03.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-797/fmap/sub-797_run-04_magnitude.nii fmap/sub-797_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-04_phasediff.nii -div 2 fmap/sub-797_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-04_phasediff_half.nii.gz fmap/sub-797_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-04.nii.gz -nan fmap/fmap_rads_sub-797_run-04.nii.gz
flirt -in fmap/sub-797_run-04_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-797_run-04.nii.gz -ref func/rasub-797_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-797_run-04.nii.gz
fugue -i func/rasub-797_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-04.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-797/fmap/sub-797_run-05_magnitude.nii fmap/sub-797_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-05_phasediff.nii -div 2 fmap/sub-797_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-05_phasediff_half.nii.gz fmap/sub-797_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-05.nii.gz -nan fmap/fmap_rads_sub-797_run-05.nii.gz
flirt -in fmap/sub-797_run-05_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-797_run-05.nii.gz -ref func/rasub-797_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-797_run-05.nii.gz
fugue -i func/rasub-797_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-05.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-797/fmap/sub-797_run-06_magnitude.nii fmap/sub-797_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-06_phasediff.nii -div 2 fmap/sub-797_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-06_phasediff_half.nii.gz fmap/sub-797_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-06.nii.gz -nan fmap/fmap_rads_sub-797_run-06.nii.gz
flirt -in fmap/sub-797_run-06_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-797_run-06.nii.gz -ref func/rasub-797_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-797_run-06.nii.gz
fugue -i func/rasub-797_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-06.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-797/fmap/sub-797_run-07_magnitude.nii fmap/sub-797_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-07_phasediff.nii -div 2 fmap/sub-797_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-07_phasediff_half.nii.gz fmap/sub-797_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-07.nii.gz -nan fmap/fmap_rads_sub-797_run-07.nii.gz
flirt -in fmap/sub-797_run-07_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-797_run-07.nii.gz -ref func/rasub-797_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-797_run-07.nii.gz
fugue -i func/rasub-797_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-07.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-797/fmap/sub-797_run-08_magnitude.nii fmap/sub-797_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-797/fmap/sub-797_run-08_phasediff.nii -div 2 fmap/sub-797_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-797_run-08_phasediff_half.nii.gz fmap/sub-797_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-797_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-797_run-08.nii.gz -nan fmap/fmap_rads_sub-797_run-08.nii.gz
flirt -in fmap/sub-797_run-08_magnitude_brain.nii.gz -ref func/rasub-797_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-797_run-08.nii.gz -ref func/rasub-797_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-797_run-08.nii.gz
fugue -i func/rasub-797_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-797_run-08.nii.gz --unwarpdir=y- -u func/urasub-797_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-797_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-797_run-01.nii.gz --unwarpdir=y- -u func/urasub-797_task-localizer_bold.nii.gz -v

%% SUB-960

cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-960

mkdir -p fmap

# RUN-01
bet ../../../rawdata/sub-960/fmap/sub-960_run-01_magnitude.nii fmap/sub-960_run-01_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-01_phasediff.nii -div 2 fmap/sub-960_run-01_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-01_phasediff_half.nii.gz fmap/sub-960_run-01_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-01.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-01.nii.gz -nan fmap/fmap_rads_sub-960_run-01.nii.gz
flirt -in fmap/sub-960_run-01_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-01_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-01.mat
flirt -in fmap/fmap_rads_sub-960_run-01.nii.gz -ref func/rasub-960_task-main_run-01_bold.nii -applyxfm -init fmap/fieldmap2epi_run-01.mat -out fmap/rfmap_rads_sub-960_run-01.nii.gz
fugue -i func/rasub-960_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-01.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-01_bold.nii.gz -v

# RUN-02
bet ../../../rawdata/sub-960/fmap/sub-960_run-02_magnitude.nii fmap/sub-960_run-02_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-02_phasediff.nii -div 2 fmap/sub-960_run-02_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-02_phasediff_half.nii.gz fmap/sub-960_run-02_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-02.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-02.nii.gz -nan fmap/fmap_rads_sub-960_run-02.nii.gz
flirt -in fmap/sub-960_run-02_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-02_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-02.mat
flirt -in fmap/fmap_rads_sub-960_run-02.nii.gz -ref func/rasub-960_task-main_run-02_bold.nii -applyxfm -init fmap/fieldmap2epi_run-02.mat -out fmap/rfmap_rads_sub-960_run-02.nii.gz
fugue -i func/rasub-960_task-main_run-02_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-02.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-02_bold.nii.gz -v

# RUN-03
bet ../../../rawdata/sub-960/fmap/sub-960_run-03_magnitude.nii fmap/sub-960_run-03_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-03_phasediff.nii -div 2 fmap/sub-960_run-03_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-03_phasediff_half.nii.gz fmap/sub-960_run-03_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-03.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-03.nii.gz -nan fmap/fmap_rads_sub-960_run-03.nii.gz
flirt -in fmap/sub-960_run-03_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-03_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-03.mat
flirt -in fmap/fmap_rads_sub-960_run-03.nii.gz -ref func/rasub-960_task-main_run-03_bold.nii -applyxfm -init fmap/fieldmap2epi_run-03.mat -out fmap/rfmap_rads_sub-960_run-03.nii.gz
fugue -i func/rasub-960_task-main_run-03_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-03.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-03_bold.nii.gz -v

# RUN-04
bet ../../../rawdata/sub-960/fmap/sub-960_run-04_magnitude.nii fmap/sub-960_run-04_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-04_phasediff.nii -div 2 fmap/sub-960_run-04_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-04_phasediff_half.nii.gz fmap/sub-960_run-04_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-04.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-04.nii.gz -nan fmap/fmap_rads_sub-960_run-04.nii.gz
flirt -in fmap/sub-960_run-04_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-04_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-04.mat
flirt -in fmap/fmap_rads_sub-960_run-04.nii.gz -ref func/rasub-960_task-main_run-04_bold.nii -applyxfm -init fmap/fieldmap2epi_run-04.mat -out fmap/rfmap_rads_sub-960_run-04.nii.gz
fugue -i func/rasub-960_task-main_run-04_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-04.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-04_bold.nii.gz -v

# RUN-05
bet ../../../rawdata/sub-960/fmap/sub-960_run-05_magnitude.nii fmap/sub-960_run-05_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-05_phasediff.nii -div 2 fmap/sub-960_run-05_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-05_phasediff_half.nii.gz fmap/sub-960_run-05_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-05.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-05.nii.gz -nan fmap/fmap_rads_sub-960_run-05.nii.gz
flirt -in fmap/sub-960_run-05_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-05_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-05.mat
flirt -in fmap/fmap_rads_sub-960_run-05.nii.gz -ref func/rasub-960_task-main_run-05_bold.nii -applyxfm -init fmap/fieldmap2epi_run-05.mat -out fmap/rfmap_rads_sub-960_run-05.nii.gz
fugue -i func/rasub-960_task-main_run-05_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-05.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-05_bold.nii.gz -v

# RUN-06
bet ../../../rawdata/sub-960/fmap/sub-960_run-06_magnitude.nii fmap/sub-960_run-06_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-06_phasediff.nii -div 2 fmap/sub-960_run-06_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-06_phasediff_half.nii.gz fmap/sub-960_run-06_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-06.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-06.nii.gz -nan fmap/fmap_rads_sub-960_run-06.nii.gz
flirt -in fmap/sub-960_run-06_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-06_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-06.mat
flirt -in fmap/fmap_rads_sub-960_run-06.nii.gz -ref func/rasub-960_task-main_run-06_bold.nii -applyxfm -init fmap/fieldmap2epi_run-06.mat -out fmap/rfmap_rads_sub-960_run-06.nii.gz
fugue -i func/rasub-960_task-main_run-06_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-06.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-06_bold.nii.gz -v

# RUN-07
bet ../../../rawdata/sub-960/fmap/sub-960_run-07_magnitude.nii fmap/sub-960_run-07_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-07_phasediff.nii -div 2 fmap/sub-960_run-07_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-07_phasediff_half.nii.gz fmap/sub-960_run-07_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-07.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-07.nii.gz -nan fmap/fmap_rads_sub-960_run-07.nii.gz
flirt -in fmap/sub-960_run-07_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-07_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-07.mat
flirt -in fmap/fmap_rads_sub-960_run-07.nii.gz -ref func/rasub-960_task-main_run-07_bold.nii -applyxfm -init fmap/fieldmap2epi_run-07.mat -out fmap/rfmap_rads_sub-960_run-07.nii.gz
fugue -i func/rasub-960_task-main_run-07_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-07.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-07_bold.nii.gz -v

# RUN-08
bet ../../../rawdata/sub-960/fmap/sub-960_run-08_magnitude.nii fmap/sub-960_run-08_magnitude_brain.nii.gz -f 0.5 -m
fslmaths ../../../rawdata/sub-960/fmap/sub-960_run-08_phasediff.nii -div 2 fmap/sub-960_run-08_phasediff_half.nii.gz
fsl_prepare_fieldmap SIEMENS fmap/sub-960_run-08_phasediff_half.nii.gz fmap/sub-960_run-08_magnitude_brain.nii.gz fmap/fmap_rads_sub-960_run-08.nii.gz 2.46 --nocheck
fslmaths fmap/fmap_rads_sub-960_run-08.nii.gz -nan fmap/fmap_rads_sub-960_run-08.nii.gz
flirt -in fmap/sub-960_run-08_magnitude_brain.nii.gz -ref func/rasub-960_task-main_run-08_bold.nii -dof 6 -omat fmap/fieldmap2epi_run-08.mat
flirt -in fmap/fmap_rads_sub-960_run-08.nii.gz -ref func/rasub-960_task-main_run-08_bold.nii -applyxfm -init fmap/fieldmap2epi_run-08.mat -out fmap/rfmap_rads_sub-960_run-08.nii.gz
fugue -i func/rasub-960_task-main_run-08_bold.nii --dwell=0.00056 --loadfmap=fmap/rfmap_rads_sub-960_run-08.nii.gz --unwarpdir=y- -u func/urasub-960_task-main_run-08_bold.nii.gz -v

# Face Localizer
fugue -i func/rasub-960_task-localizer_bold.nii --dwell=0.00069 --loadfmap=fmap/rfmap_rads_sub-960_run-01.nii.gz --unwarpdir=y- -u func/urasub-960_task-localizer_bold.nii.gz -v
