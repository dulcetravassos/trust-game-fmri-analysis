%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   Distortion Correction (FSL FUGUE)                                    %
%                                                                        %
%   Distortion correction was performed using FSL, an outsider software. %
%   First, "real" magnitudes are skull-stripped using FSL BET. Second,   %
%   fieldmaps are prepared using fsl_prepare_fieldmaps. Last,            %
%   Distortion Correction itself uses FSL FUGUE.                         %
%   To install FSL, follow the guide:                                    %
%   https://fsl.fmrib.ox.ac.uk/fsl/docs/install/windows.html             %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 12/02/2026                                                  %
%   Last update: 20/02/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Note that the preprocessing pipeline would work without Distortion 
% Correction and would therefore stay inside the MATLAB/SPM environment 
% with minor changes.

% All theoretical information below was taken from:
% https://fsl.fmrib.ox.ac.uk/fsl/docs/registration/fugue.html
% https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/FUGUE(2f)Guide.html
% https://fsl.fmrib.ox.ac.uk/fsl/docs/structural/bet.html
% https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/BET(2f)UserGuide.html

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
bet rsub-006_run-01_magnitude.nii rsub-006_run-01_magnitude_brain.nii -f 0.5 -m
fsl_prepare_fieldmap SIEMENS rsub-006_run-01_phasediff.nii rsub-006_run-01_magnitude_brain.nii fmap_rads_sub-006_run-01.nii.gz 2.46
fugue -i rasub-006_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap_rads_sub-006_run-01.nii.gz --unwarpdir=y- -u urasub-006_task-main_run-01_bold.nii

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with fmap run-02)

%% Special case: fake magnitude subjects

% The substitute/surrogate magnitude was already skull-stripped with SPM's native Segmentation tool.

% Example
fsl_prepare_fieldmap SIEMENS rsub-002_run-01_phasediff.nii sub-002_run-01_magnitude.nii fmap_rads_sub-002_run-01.nii.gz 2.46
fugue -i rasub-002_task-main_run-01_bold.nii --dwell=0.00056 --loadfmap=fmap_rads_sub-002_run-01.nii.gz --unwarpdir=y- -u urasub-002_task-main_run-01_bold.nii

% Note that the -i and --loadfmap should match (e.g., functional run-02 should be paired with fmap run-02)

%% Final notices

% You can use the full paths to each file or, before running these scripts, change the terminal's directory using the 'cd' command
% (for example, cd /mnt/c/Users/User/Desktop/Tese/data/spm-data/derivatives/spm-preprocessing/sub-006/)

%% SUB-002

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-003

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-004

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-006

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-007

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-008

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-009

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-011

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-012

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-013

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-014

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-015

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-016

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-017

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-018

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-019

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-020

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-021

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-022

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08


%% SUB-023

% RUN-01

% RUN-02

% RUN-03

% RUN-04

% RUN-05

% RUN-06

% RUN-07

% RUN-08
