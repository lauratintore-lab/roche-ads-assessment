log_file <- file("question_3_tlg/ae_summary_table.log", open = "wt")
sink(log_file, type = "output")
sink(log_file, type = "message")

cat("====================================================================\n")
cat("AE_Summary_Table.R")
cat("Generate AE Summary Table with Subject-Level Incidence")
cat("====================================================================\n\n")

#### Question 3.1: TLG - Adverse Events Reporting - AE Summary Table ####
library(gtsummary)
library(dplyr)
library(pharmaverseadam)
library(admiral)

# Load input datasets
adsl <- pharmaverseadam::adsl
adae <- pharmaverseadam::adae

#Convert blanks to NA
adsl <- convert_blanks_to_na(adsl)
adae <- convert_blanks_to_na(adae)

#### Step 1: Data preparation ####
#TRTEMFL -> Treatment Emergent Analysis Flag
#AESOC -> System Organ Class Grouping
#AETERM -> Reported Term nested to those classes (AESOC)
#ACTARM -> Description of treatment.

#Verify raw counts before processing
cat("Count of Treatment-Emergent Records (TRTEMFL == 'Y'):\n")
print(nrow(adae %>% filter(TRTEMFL == "Y"))) 

cat("Count of Unique Subjects with at least one TEAE:\n")
print(n_distinct(adae$USUBJID[which(adae$TRTEMFL == "Y")])) 

#Row 1: Treatment emergent AE records 
any_ae <- adae %>%
  filter(TRTEMFL == "Y") %>% 
  distinct(USUBJID, ACTARM) %>% #deduplication: keep unique rows for every term a patient had
  mutate(category = "Treatment Emergent AEs")

#Row 2: AESOC
soc_ae <- adae %>%
  filter(TRTEMFL == "Y") %>%
  distinct(USUBJID, AESOC, ACTARM) %>%
  rename(category = AESOC)

#Combined dataset
combined_ae <- bind_rows(any_ae, soc_ae) %>%
  mutate(category = factor(category, levels = c("Treatment Emergent AEs", unique(soc_ae$category)))) #force row Treatment Emergent AEs to be a factor to stay at the top

# Ensure no subjects were lost during binding/deduplication
cat("Final subject count in combined dataset")
print(n_distinct(combined_ae$USUBJID))

#### Step 2: Create summary table ####
total_n <- nrow(adsl) #total N for table label
cat("Total N (Denominator) from ADSL used for headers: ", total_n, "\n")

ae_table_final <- combined_ae %>%
  select(category, ACTARM) %>%
  tbl_summary(
    by = ACTARM,
    sort = all_categorical() ~ "frequency", # This will sort the SOCs below the top row
    label = list(category ~ "Adverse Event Category"),
    missing = "no"
  ) %>%
  add_overall(last = FALSE, col_label = paste0("**Total** \n (N = ", total_n, ")")) %>%
  modify_header(
    all_stat_cols() ~ "**{level}** \n (N={n})"
  ) %>%
  modify_caption("**Table: Summary of Treatment-Emergent Adverse Events**") %>%
  bold_labels()

print(ae_table_final)

cat("====================================================================\n")

sink(type = "message") # Stop capturing warnings
sink()                # Stop capturing console output
close(log_file)
