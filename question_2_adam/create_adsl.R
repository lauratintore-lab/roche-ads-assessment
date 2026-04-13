log_file <- file("question_2_adam/create_adsl.log", open = "wt")
sink(log_file, type = "output")
sink(log_file, type = "message")

# Program Header for Log
cat("====================================================================\n")
cat("create_adsl.R\n")
cat("====================================================================\n\n")

#### EXERCISE 2: Create ADSL (Subject level) dataset using SDTM source data, the {admiral} family of packages, and tidyverse tools tidyverse tools.####
library(admiral)
library(dplyr)
library(pharmaversesdtm)
library(lubridate)
library(tidyverse)

#STDM data
dm <- pharmaversesdtm::dm
vs <- pharmaversesdtm::vs
ex <- pharmaversesdtm::ex
ds <- pharmaversesdtm::ds
ae <- pharmaversesdtm::ae

cat("Input SDTM datasets loaded.\n")
cat("Number of subjects in DM: ", n_distinct(dm$USUBJID), "\n\n")

#Convert blanks to NA for all domains
dm <- convert_blanks_to_na(dm) #demographics
vs <- convert_blanks_to_na(vs) #vital signs
ex <- convert_blanks_to_na(ex) #exposure
ds <- convert_blanks_to_na(ds) #disposition
ae <- convert_blanks_to_na(ae) #adverse event

#Assing pharmaversesdtm::dm to an adsl object
adsl <- dm %>%
  select(-DOMAIN)

#### Step 1: Derive variables AGEGR9 & AGEGR9N (dm domain)####
#Age categorization
#Define the lookup table for the categorical variable AGER9 and numerical variable AGER9N
age_lookup <- exprs(
  ~condition, ~AGEGR9,    ~AGEGR9N,
  AGE < 18, "<18", 1,
  between(AGE, 18,50), "18 - 50", 2,
  AGE > 50, ">50", 3,
  is.na(AGE), "Missing", 99 #force missing category to the end of the list
)

#Apply to adsl
adsl <- adsl %>%
  derive_vars_cat(definition = age_lookup)

cat("STEP 1: Age group derivation\n")
cat("Frequency of AGEGR9:\n")
print(table(adsl$AGEGR9, useNA = "always"))
cat("\n")

#### Step 2: Derive variable ITTFL (dm domain)####
#Binary check for patients: study treatment group (randomized) or not (screen failure)
adsl <- adsl %>%
  mutate(
    ITTFL = (if_else(!is.na(ARM) & ARM !="" & ARM !="Screen Failure", "Y", "N")) #Y if ARM not missing, N if missing
  )

cat("Intent-to-Treat (ITTFL) derivation.\n")
cat("ITTFL counts:\n")
print(table(adsl$ITTFL, useNA = "always"))
cat("\n")

#### Step 3: Derive variables TRTSDTM & TRTSTMF (ex domain)####
#First valid dose of medication or placebo for patients
#Process exposure start data - convert text to datetime
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXSTDTC, #Start date/time of treatment
    new_vars_prefix = "EXST", #Prefix for naming columns
    highest_imputation = "h", #Impute if hours and minutes are missing
    time_imputation = "00:00:00"
  )

#Find the first dose for all patients
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 | #Dose >0
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXSTDTM), #When Dose = 0 + Placebo as name of the treatment in records where there is a Start Date
    new_vars = exprs(TRTSDTM = EXSTDTM, TRTSTMF = EXSTTMF), #rename columns
    order = exprs(EXSTDTM, EXSEQ),
    mode = "first", #get only the first occurrence
    by_vars = exprs(STUDYID, USUBJID)
  )

cat("Treatment Start DateTime (TRTSDTM) derivation.\n")
cat("Subjects with a Treatment Start Date: ", sum(!is.na(adsl$TRTSDTM)), "\n\n")

#### Step 4: Derive variable LSTAVLDT (vs, ds, ex and ae domain) ####
#Last alive date using vs, ae, ds, ex
#Process exposure end data - convert text to datetime
ex_ext <- ex %>%
  derive_vars_dtm(
    dtc = EXENDTC, #End date/time of treatment
    new_vars_prefix = "EXEN", #Prefix for naming columns
    highest_imputation = "h", #Impute if hours and minutes are missing
    time_imputation = "23:59:59" #end of the day
  )

#Derive treatment end time
adsl <- adsl %>%
  derive_vars_merged(
    dataset_add = ex_ext,
    filter_add = (EXDOSE > 0 | #Dose >0
                    (EXDOSE == 0 &
                       str_detect(EXTRT, "PLACEBO"))) & !is.na(EXENDTM), #When Dose = 0 + Placebo as name of the treatment in records where there is a Start Date
    new_vars = exprs(TRTEDTM = EXENDTM, TRTETMF = EXENTMF), #rename columns
    order = exprs(EXENDTM, EXSEQ),
    mode = "last", #get only the last occurrence
    by_vars = exprs(STUDYID, USUBJID)
  )

#Derivation across all sources
adsl <- adsl %>%
  derive_vars_extreme_event(
    by_vars = exprs(STUDYID, USUBJID),
    events = list(
      #Vital Signs
      event(
        dataset_name = "vs",
        condition = !(is.na(VSSTRESN) & is.na(VSSTRESC)) & !is.na(VSDTC), #(Numeric result and character result of VS not missing) and date of measurement of VS not missing. 
        set_values_to = exprs(LSTALVDT = convert_dtc_to_dt(VSDTC), seq = VSSEQ), #rename LSTALVDT, transform into date object
        order = exprs(LSTALVDT, VSSEQ)
      ),
      #Adverse Events
      event(
        dataset_name = "ae",
        condition = !is.na(AESTDTC), #start date-time of AE not missing
        set_values_to = exprs(LSTALVDT = convert_dtc_to_dt(AESTDTC), seq = AESEQ), 
        order = exprs(LSTALVDT, AESEQ) #if there are multiple AE on the same day, it will pick the one with the highest seq number
      ),
      #Disposition
      event(
        dataset_name = "ds",
        condition = !is.na(DSSTDTC), #start date-time of DS event not missing
        set_values_to = exprs(LSTALVDT = convert_dtc_to_dt(DSSTDTC), seq = DSSEQ),
        order = exprs(LSTALVDT, DSSEQ)
      ),
      #Exposure
      event(
        dataset_name = "adsl",
        condition = !is.na(TRTEDTM), #date-time of last EX to treatment not missing
        order = exprs(TRTEDTM),
        set_values_to = exprs(LSTALVDT = date(TRTEDTM), seq = 0) #dm domain and adsl contains one row per patient, no variable seq
      )
    ),
    source_datasets = list(ae = ae, vs = vs, ds = ds, adsl = adsl),
    tmp_event_nr_var = event_nr,
    order = exprs(LSTALVDT, seq, event_nr),
    mode = "last",
    new_vars = exprs(LSTALVDT),
  )

cat("Last Alive Date (LSTALVDT) derivation.\n")
cat("Subjects with LSTALVDT: ", sum(!is.na(adsl$LSTALVDT)), "\n\n")

#Relocate variables based on the variable they were derived from
adsl <- adsl %>%
  relocate(AGEGR9, AGEGR9N, .after = AGE) %>%
  relocate(ITTFL, .after = ARM) %>%
  relocate(TRTSDTM, TRTSTMF, TRTEDTM, TRTETMF, .after = ITTFL)

cat("Relocation of variables complete.\n")
cat("Final ADSL dimensions: ", paste(dim(adsl), collapse = " x "), "\n")

write.csv(adsl, "question_2_adam/adsl.csv", row.names = FALSE)

cat("====================================================================\n")

sink(type = "message")
sink()
close(log_file)
