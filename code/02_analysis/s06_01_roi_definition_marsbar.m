%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                        %
%   ROI Definition (MarsBaR toolbox)                                     %
%                                                                        %
%   This script describes the manual steps taken to define spherical     %
%   ROIs centered in pre-selected peak voxel coordinates, using the      %
%   MarsBaR SPM toolbox.                                                 %
%                                                                        %
%   Author: Dulce Travassos                                              %
%   Created: 30/05/2026                                                  %
%   Last update: 30/05/2026                                              %
%                                                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Credits to Andy's Brain Book: https://andysbrainbook.readthedocs.io/en/latest/SPM/SPM_Short_Course/SPM_09_ROIAnalysis.html

%% ROI Definition

% Create the /derivatives/spm-rois/ folder with the sub-00x folders inside

% Create the sphere (.mat file)
% 1. Click on ROI definition -> Build...
% 2. Type of ROI -> Sphere
% 3. Enter the coordinates (in our case, pre-selected peak voxel coordinates manually chosen - check the next section)
% 4. Radius of 10 (default)
% 5. Choose a name for the ROI (e.g., 'r-pSTS_roi', 'rFFA_avg_roi', etc)
% 6. Save the .mat file on the corresponding folder (/derivatives/spm-rois/sub-00x/)

% Generate ROI as a NIfTI (.nii file)
% 1. Click on ROI definition -> Export...
% 2. Select 'image' and choose the .mat ROI to convert
% 3. Space for ROI image: Base space for ROIs (default)
% 4. Select the output folder (in our case, the same as the .mat)

%% Coordinates chosen for the ROI center

% To define the final ROIs, a standardized peak selection procedure was consistently applied across all subjects.
% When available, a subject-specific ROI was defined. For subjects lacking a functionally identifiable peak for a 
% given region, we used  the mean coordinates of that ROI across the participants showing activations.
% You can find more information on this process on this study's manuscript.