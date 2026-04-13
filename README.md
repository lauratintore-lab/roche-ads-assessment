# roche-ads-assessment
Pharmaverse Expertise and Python Coding Assessment

This repository contains the solutions for the ADS technical assessment.

## Repository Structure

* **metadata/**: Contains the CDISC Controlled Terminology (sdtm_ct.csv) used for mapping.
* **question_1_sdtm/**:
  `01_create_ds_domain.R`: R script for the creation of the DS domain.
  `01_create_ds_domain.log`: Execution log showing error-free run.
  `ds_domain.csv`: Final SDTM DS dataset.

* **question_2_adam/**:
  `create_adsl.R` : R script to create the ADSL
  `create_adsl.log` : Execution log showing error-free run.
  `adsl.csv` : Final ADSL dataset.

* **question_3_tlg/**:
  `01_create_ae_summary_table.R` : R script for the summary table treatment AE.
  `AE_Summary_Log.txt` : Execution log showing error-free run.
  `AE_Summary_Table.png` : Gt summary table png format
  `ae_summary_table.html` : Gt summary table html format
  
* **question_4_agent/**:
  `agent.py` : Python file with agent
  `test.py` : Hardcoded example queries
  `adae.csv` : AE dataset
  `requirements.txt` : Requirements 

