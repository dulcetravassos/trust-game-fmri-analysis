##################################################################################
#									         #
#  The code was developed and tested on a PC with the following specifications:  #
#									         #
#  Software: MATLAB R2024b (Update 4 - 24.2.0.2833386)			         #
#  	     SPM12 (7771)							 #
#  OS: Microsoft Windows 10 (64-bit)					         #
#  CPU: Intel(R) Core(TM) i5-10300H CPU @ 2.50GHz			         #
#  RAM: 16GB								         #
#  GPU: NVIDIA GeForce RTX 2060 with Max-Q Design			         #
#									         #
##################################################################################

Note*: Scripts not specifying time of running took only a couple of minutes. Time is only specified for scripts that took longer to run.

--------------------------------------------- s00_convert_prt_to_spm ---------------------------------------------

The function prt_to_spm(), using the function read_prt(), reads multiple .prt files from a selected folder; confirms the resolution of time (converting msec to sec); skips empty conditions (meaning 0 trials); detects start time of an event and calculates its duration; and saves a .mat file with a BIDS compliant name. Additionally, it features subject filtering (processing only a predefined list of subjects) and supports the distribution of a universal protocol (for the face localizer task).


--------------------------------------------- s01_get_design_matrix --------------------------------------------- 

Creates a subject-specific explicit brain mask using tissue probability maps (GM + WM + CSF) to exclude ghost voxels and out-of-brain artifacts. Additionally, it generates the Design Matrix for each task and session, incorporating the 6 motion regressors. It relies on BIDS-compliant event files converted from .prt to .mat (see s00_convert_prt_to_spm).


--------------------------------------------- s02_beta_estimation ---------------------------------------------

Reads the Design Matrix (SPM.mat) for each subject and task, and runs the estimation algorithm (Classical - Restricted Maximum Likelihood). Generates the estimated regression coefficients (Beta images), the error variance image (ResMS), the analysis mask, and the estimated resels per voxel (RPV) image. To save disk space, individual volume residuals are not saved.
The residuals are not directly saved, but written in the header.
Time: ~aa minutes per subject (Main Task + Face Localizer).
