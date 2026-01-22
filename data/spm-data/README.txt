
Folder created in 19.01.2026 by Dulce Travassos.
Last updated in 22.01.2026 by Dulce Travassos.

From BIDS specifications 1.2.1
https://bids-specification.readthedocs.io/en/stable/02-common-principles.html

Derivatives of the raw data (other than products of DICOM to NIfTI conversion) are kept separate from the raw / source data.

----------------------------------------------------------------------------------------

The folder derivatives contains sub-folders concerning non-imaging objects that improve reproducibility:
- scripts, 
- settings files, 
- etc...

----------------------------------------------------------------------------------------

README FILE GOAL: describe the nature of the derived data. 

Details about how the results were generated:

- software stack (which programs were used):
. MATLAB R2024b 24.2
. SPM12


***
- settings used:
a. MATLAB R2024b 24.2 + SPM12
. preprocessing:
...
. creation of single design matrix (SDM) files:
...
. creation of multi-subject design matrix (MDM) files:
...
. deconvolution options:
...
. 
