# roche-ads-assessment
Pharmaverse Expertise and Python Coding Assessment

This repository contains the solutions for the ADS technical assessment.

## Repository Structure

* **metadata/**: Contains the CDISC Controlled Terminology (sdtm_ct.csv) used for mapping on question 1. 
* **question_1_sdtm/**:
  `01_create_ds_domain.R`: R script for the creation of the DS domain.
  `01_create_ds_domain.log`: Execution log showing error-free run.
  `ds_domain.csv`: Final SDTM DS dataset.

* **question_2_adam/**:
  `create_adsl.R` : R script to create the ADSL
  `create_adsl.log` : Execution log showing error-free run.
  `adsl.csv` : Final ADSL dataset.

* **question_3_tlg/**:
  `01_create_ae_summary_table.R` : R script for the gt summary table treatment AE.
  `02_create_visualizations.R` : R script for the stacked barplot for AE severity and AE incidence plot. 
  `ae_summary_table.log` : Execution log showing error-free run for the gt summary table.
  `02_create_visualizations.log` : Execution log showing error-free run for the visualizations.
  `ae_summary_table.html` : Gt summary table html format.
  `AE_Severity_Plot.png` : Bar plot for severity of AE in png format.
  `Top_10_AE_Plot.png` : Plot 10 most frequent AEs with Clopper-Pearson CIs.
  
* **question_4_agent/**:
  `agent.py` : Python file with agent
  `test.py` : Hardcoded example queries
  `adae.csv` : AE dataset
  `requirements.txt` : Requirements 

