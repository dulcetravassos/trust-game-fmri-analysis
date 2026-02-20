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
Time: ~15 minutes per subject (Main Task + Face Localizer).


--------------------------------------------- s02_set_the_origin --------------------------------------------- 

Makes a copy of the original/raw anatomic images to the correct BIDS derivative folder and opens that copy on the SPM display, to allow the user to set the origin (AC-PC).


--------------------------------------- s03_motion_correction_realignment ---------------------------------------

Performs the SPM12 operation "Realign: Estimate & Reslice" on slice-timed data ('a...' files). The "Estimate" calculates the motion parameters (rp_*.txt) and the "Reslice" applies these parameters and writes new 'r...' files and generates a mean image (mean*.nii).
Time: ~25 minutes per subject (Main Task + Face Localizer).

Note: Reslicing is performed at this stage to provide physical aligned files required for Distortion Correction in FSL.


------------------------------------------ s04_get_magnitude_substitute ------------------------------------------

Creates a 'fake magnitude' (surrogate) by skull-stripping the T1w image for subjects missing magnitude files, since performing Distortion Correction in FSL requires complete fieldmaps (magnitude + phasediff).
The process involves Segmentation (generates tissue probability maps for grey matter, white matter and CSF) and ImCalc (applies the expression "i1.*((i2+i3+i4)>0.5)" to keep only voxels with >50% probability of actually being brain tisse).
Finally, the alignment to the phasediff space is done in a 2-step coregistration process to avoid SPM crashes:
1) Estimate & Reslice to the Mean Functional image (aligns the structural mask to the subject's functional head position using mutual information);
2) Write (Reslice ONLY) to the Native Phasediff (forcing the functional-aligned T1w into the exact spatial grid and voxel dimensions of the raw phasediff without attempting mutual information estimation).
This script automatically cleans up the intermediate files generated mid-operation (e.g., c1, c2, m_*) to prevent overwriting conflicts in later pipeline stages.


---------------------------------------------- s05_01_prepare_native_fmap_fsl ----------------------------------------------

Processes the raw phasediff and magnitude files to generate a continuous, unwrapped fieldmap (in rad/s) strictly within the Native space.
Methodological note: Phasediff images are never resampled/resliced while wrapped (-pi to +pi) to avoid severe boundary overshoots caused by spatial interpolation.
This script performs three key corrections:
1) SIEMENS Scaling Bug: Divides the raw Siemens phasediff by 2 using 'fslmaths' to correct the amplitude scale back to the standard 4096 expected by FSL;
2) Skull-stripping: Applies FSL 'bet' to extract the brain from real magnitude files;
3) SIEMENS Slice Dimension Bug: Uses FSL 'flirt' to truncate the magnitude image when the scanner reconstructs it with +1 slice compared to the phasediff (cases where magnitude1 or magnitude2 instead of regular magnitude).
Finally, it runs 'fsl_prepare_fieldmap' to output 'fmap_rads_*.nii.gz'.
Being a .m file with bash code, you are supposed to copy-paste the code lines for each subject to a WSL interpreter (Linux) instead of running the script itself on Matlab.


---------------------------------------------- s05_02_align_fmap_to_func_spm ----------------------------------------------

Bridges the continuous Native Space fieldmaps back to the Functional Space. It automatically unzips the *.nii.gz files and performs Coregistration (Estimate & Reslice) to align them with the Mean Functional image.
This returns an image geometrically matched to the functional data and ready for Unwarping via FSL FUGUE.


---------------------------------------------- s05_03_distortion_correction_fsl ----------------------------------------------

Applies the calculated and functionally-aligned fieldmaps ('rfmap_rads') to the previously realigned BOLD images ('ra*_bold.nii') using FSL FUGUE. This step unwarps the EPI distortions caused by B0 magnetic field inhomogeneities, outputting the final 'ura*_bold.nii' images.