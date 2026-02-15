##################################################################################
#									         #
#  The code was developed and tested on a PC with the following specifications:  #
#									         #
#  Software: MATLAB R2024b (Update 4 - 24.2.0.2833386)			         #
#  	     SPM12 (7771)							 #
#	     Ubuntu v24.04.5 LTS						 #
#	     FSL vXX.XX.XX (FUGUS)						 #
#  OS: Microsoft Windows 10 (64-bit)					         #
#  CPU: Intel(R) Core(TM) i5-10300H CPU @ 2.50GHz			         #
#  RAM: 16GB								         #
#  GPU: NVIDIA GeForce RTX 2060 with Max-Q Design			         #
#									         #
##################################################################################

--------------------------------------------- s00_dicom_to_nifti --------------------------------------------- 

Converts raw DICOM MRI data (anatomical, functional, fieldmaps) into NIfTI files suitable for preprocessing and analysis in SPM12. Saves a JSON file with metadata. Output filenames follow BIDS conventions, when applicable.

--------------------------------------------- s00_convert_prt_to_spm ---------------------------------------------

The function prt_to_spm(), using the function read_prt(), reads multiple .prt files from a selected folder; confirms the resolution of time (converting msec to sec); skips empty conditions (meaning 0 trials); detects start time of an event and calculates its duration; and saves a .mat file with a BIDS compliant name. 

--------------------------------------------- s01_slice_timing --------------------------------------------- 

Slice Timing Correction script adapted to deal with subjects with reverse slice order and variable volumes. Saves output in derivatives folder with a JSON file (BIDS friendly). 
Time: ~20 minutes per subject (Main Task + Face Localizer).

--------------------------------------------- s02_set_the_origin --------------------------------------------- 

Makes a copy of the original/raw anatomic images to the correct BIDS derivative folder and opens that copy on the SPM display, to allow the user to set the origin (AC-PC).

--------------------------------------- s03_motion_correction_realignment ---------------------------------------

Performs the SPM12 operation "Realign: Estimate & Reslice" on slice-timed data ('a...' files). The "Estimate" calculates the motion parameters (rp_*.txt) and the "Reslice" applies these parameters and writes new 'r...' files and generates a mean image (mean*.nii).
Time: ~25 minutes per subject (Main Task + Face Localizer).

Note: Reslicing is performed at this stage to provide physical aligned files required for Distortion Correction in FSL.