log_file <- file("question_1_sdtm/01_create_ds_domain.log", open = "wt")
sink(log_file, type = "output")
sink(log_file, type = "message")

cat("====================================================================\n")
cat("01_create_ds_domain.R\n")
cat("Create SDTM DS Domain from Raw Source Data\n")
cat("====================================================================\n\n")

#### EXERCISE 1: Create SDTM Disposition (DS) domain dataframe ####
library(sdtm.oak)
library(pharmaverseraw)
library(dplyr)
library(tidyverse)

ds_raw <- pharmaverseraw::ds_raw #Raw deposition file
dm <- pharmaversesdtm::dm #demographics domain

cat("INFO: Input datasets loaded.\n")
cat("Row count in raw DS (ds_raw): ", nrow(ds_raw), "\n")
cat("Subject count in raw DS: ", n_distinct(ds_raw$PATNUM), "\n\n")

#### Step 1: ID Generation ####
# Create unique identifiers for each raw record
ds_raw <- ds_raw %>%
  generate_oak_id_vars(pat_var = "PATNUM", 
                       raw_src = "ds_raw")

study_ct <- read.csv("metadata/sdtm_ct.csv") #controlled terminology

#### Step 2: Assignment with Controlled Terminology ####
# Map DSTERM to IT.DSTERM or OTHERSP if OTHERSP it is not null
ds_raw <- ds_raw %>%
  mutate(DSTERM_READY = if_else(!is.na(OTHERSP) & OTHERSP !="", OTHERSP, IT.DSTERM))

# Move raw discontinuation reason into standard term
ds <- assign_no_ct(raw_dat = ds_raw, 
                   raw_var = "DSTERM_READY", 
                   tgt_var = "DSTERM", 
                   id_vars = oak_id_vars())

cat("Verbatim term mapping (DSTERM).\n\n")

#### Step 3: Direct Assignment ####
# Map DSDECOD to IT.DSDECOD or OTHERSP if OTHERSP is not null
ds_raw <- ds_raw %>%
  mutate(DSDECOD_RAW = if_else(!is.na(OTHERSP) & OTHERSP !="", OTHERSP, IT.DSDECOD),
         DSDECOD_RAWC = toupper(DSDECOD_RAW), #Capital letters
         DSDECOD_READY = case_match(
           DSDECOD_RAWC,
           "RANDOMIZED"           ~ "COMPLETED",
           "FINAL LAB VISIT"       ~ "COMPLETED",
           "FINAL RETRIEVAL VISIT" ~ "COMPLETED",
           .default = DSDECOD_RAWC)) #Convert raw clinical terms "RANDOMIZED", "FINAL LAB VISIT", and "FINAL RETRIEVAL VISIT" that cannot be mapped to controlled terminology to dictionary-ready terms

# For column Discontinuation Reason, Visit and visitnum apply controlled terminology. 
ds <- ds %>%
  assign_ct(raw_dat = ds_raw,
            raw_var = "DSDECOD_READY",
            tgt_var = "DSDECOD",
            ct_spec = study_ct,
            ct_clst = "C66727",
            id_vars = oak_id_vars()
  )

ds <- ds %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISIT",
    ct_spec = study_ct,
    ct_clst = "VISIT",
    id_vars = oak_id_vars()
  ) %>%
  assign_ct(
    raw_dat = ds_raw,
    raw_var = "INSTANCE",
    tgt_var = "VISITNUM",
    ct_spec = study_ct,
    ct_clst = "VISITNUM",
    id_vars = oak_id_vars()
  )

# For VISITNUM fix terms that could not be mapped to controlled terminology "Ambul Ecg Removal" and Unscheduled visits different to 3.1
ds <- ds %>%
  mutate(
    VISITNUM = case_when(VISIT == "AMBUL ECG REMOVAL" ~ 6,
                         str_detect(VISIT, "UNSCHEDULED") ~ as.numeric(str_extract(VISIT, "[0-9.]+")),
                         TRUE ~ as.numeric(VISITNUM)
                         
    )
  )

cat("Controlled Terminology Mapping.\n")
cat("Count of records with missing DSDECOD: ", sum(is.na(ds$DSDECOD)), "\n")
cat("Frequency check for DSDECOD:\n")
print(table(ds$DSDECOD, useNA = "always"))
cat("\n")

#### Step 4: Define Disposition category ####
# If IT.DSDECOD = Randomized; Map DSCAT = PROTOCOL MILESTONE, else DSCAT = DISPOSITION EVENT
# If OTHERSP is not null; Map DSCAT = OTHER EVENT
ds <- ds %>%
  mutate(DSCAT = case_when(
    ds_raw$IT.DSDECOD == "Randomized" ~ "PROTOCOL MILESTONE",
    !is.na(ds_raw$OTHERSP) & ds_raw$OTHERSP != "" ~ "OTHER EVENT",
    TRUE ~ "DISPOSITION EVENT"
  )
  )

cat("Disposition Category (DSCAT) assigned.\n")
cat("Frequency check for DSCAT:\n")
print(table(ds$DSCAT, useNA = "always"))
cat("\n")

#### Step 5: Datetime mapping ####
# Covert raw dates into ISO 8601 format.
#Date of subject completion/discontinuation of the study
ds <- ds %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = "IT.DSSTDAT",
    tgt_var = "DSSTDTC",
    raw_fmt = "m-d-y",
    id_vars = oak_id_vars()
  )
#Date/Time of collection
ds <- ds %>%
  assign_datetime(
    raw_dat = ds_raw,
    raw_var = c("DSDTCOL", "DSTMCOL"),
    tgt_var = "DSDTC", 
    raw_fmt = c("m-d-y", "H:M"),
    id_vars = oak_id_vars()
  )

cat("ISO 8601 Date/Time mapping.\n")
cat("Count of records with missing DSSTDTC (Start Date): ", sum(is.na(ds$DSSTDTC)), "\n\n")

#### Step 6: Derivations ####
# Add Global IDs, Record Numbers and Trial Timelines. 
ds <- ds %>%
  mutate(
    STUDYID = ds_raw$STUDY, #study code
    DOMAIN = "DS", #domain
    USUBJID = paste0("01-", ds_raw$PATNUM) #prefix patient number
  ) %>%
  derive_seq(
    tgt_var = "DSSEQ", #discontinuation sequence for patents with more than one discontinuation event
    rec_vars = c("USUBJID","DSTERM")
  ) %>%
  derive_study_day(  #Calculate what day of the trial the discontinuation happened (Event Date  - Trial Start Date (Reference date))
    sdtm_in = .,
    dm_domain = dm,
    tgdt = "DSSTDTC",
    refdt = "RFSTDTC",
    study_day_var = "DSSTDY"
  ) %>%
  
  select(
    STUDYID, DOMAIN, USUBJID, DSSEQ, DSTERM, DSDECOD, DSCAT,
    VISITNUM, VISIT, DSDTC, DSSTDTC, DSSTDY) #select variables we want

cat("Final derivations and variable selection complete.\n")
cat("Final subject count in DS domain: ", n_distinct(ds$USUBJID), "\n")
cat("Final DS domain dimensions: ", paste(dim(ds), collapse = " x "), "\n\n")

write.csv(ds, "question_1_sdtm/ds_domain.csv", row.names = FALSE)

cat("====================================================================\n")

sink(type = "message")
sink()
close(log_file)
