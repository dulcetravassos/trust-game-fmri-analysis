## Source Code & Analysis Pipeline
This directory contains all the custom scripts developed to process, analyse, and evaluate the fMRI data for this project. 

The pipeline is highly modular and was designed to be executed sequentially. Therefore, the scripts are numbered to guide the user through their intended execution order.

For more detailed information, please check the root [`README file`](../README.md).

<br>

## Directory Structure and Execution Order

To ensure full reproducibility, the analytical pipeline is divided into distinct stages. Please navigate through the folders in the following chronological order:

#### [`01_preprocessing/`](01_preprocessing/)

Contains all the scripts required to take the raw/defaced BIDS-formated DICOM files to NIfTI, fully preprocessed, unwarped, and normalized images ready for statistical analysis.
  
#### [`02_analysis/`](02_analysis/)

Contains scripts for converting protocols from .prt format (BrainVoyager) to .mat (SPM-readable) and .tsv (BIDS-compliant), design matrices generation, 1st-level (within-subject) and 2nd-level (group) General Linear Model (GLM) specifications, contrast definitions, conjunction alayses, automated results exportation (statistical tables and thresholded NIfTI maps), Region of Interest (ROI) extraction and analysis, and design quality checks (e.g., collinearity tests).

<br>

> ***Note:** For detailed system requirements, specific step-by-step execution guides, and script-by-script breakdowns, please refer to the dedicated `README.md` files located inside each of the subfolders above.*
