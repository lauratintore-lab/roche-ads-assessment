log_file <- file("question_3_tlg/02_create_visualizations.log", open = "wt")
sink(log_file, type = "output")
sink(log_file, type = "message")

cat("====================================================================\n")
cat("02_create_visualizations.R\n")
cat("Generate AE Severity and Incidence Plots with 95% CI\n")
cat("====================================================================\n\n")

#### Question 3.2: TLG - Adverse Events Reporting - Visualizations ####
library(ggplot2)
library(dplyr)
library(pharmaverseadam)
library(tidyr)

# Load data
adae <- pharmaverseadam::adae
adsl <- pharmaverseadam::adsl
#### Plot 1: Stacked barplot AESEV ####
#### Step 1 Data processing for AE Severity Distribution by Treatment ####
arm_totals <- adsl %>%
  group_by(ACTARM) %>%
  summarise(N_total = n_distinct(USUBJID), .groups = "drop_last")

cat("Treatment Arm Denominators (N):\n")
print(arm_totals)
cat("\n")

cat("Filter for Safety population")
arm_totals <- adsl %>%
  filter(ACTARM != "Screen Failure" & !is.na(ACTARM) & ACTARM != "") %>% #Filter out screen failure within ACTARM
  group_by(ACTARM) %>%
  summarise(N_total = n_distinct(USUBJID), .groups = "drop_last")

cat("Treatment Arm Denominators (N):\n")
print(arm_totals)
cat("\n")


plot1_data <- adae %>%
  filter(TRTEMFL == "Y") %>% #Filter for treatment emergent Flag Yes
  group_by(ACTARM, AESEV) %>%  #Description of treatment and severity of AE
  summarise(n = n_distinct(USUBJID), .groups = "drop_last") %>% 
  left_join(arm_totals, by = "ACTARM") %>%
  mutate(pct = n)

# Ensure Severity is an ordered factor
plot1_data$AESEV <- factor(plot1_data$AESEV, levels = c("MILD", "MODERATE", "SEVERE"))

#### Step 2 Create stacked barplot ####
sev_plot <- ggplot(plot1_data, aes(x = ACTARM, y = pct, fill = AESEV)) +
  geom_bar(stat = "identity") +
  labs(
    title = "AE Severity Distribution by Treatment Arm",
    x = "Severity Level",
    y = "Count of AEs",
    fill = "Actual Treatment"
  )

ggsave("question_3_tlg/AE_Severity_Plot.png", sev_plot, width = 8, height = 6, dpi = 300)
cat("Severity plot saved as PNG.\n\n")

#### Plot 2: Top 10 Most Frequent AEs (with 95% CI) ####

cat("Calculating Incidence Rates and 95% CI for Top 10 AEs.\n")

#### Step 1 Calculate the top 10 most frequent AEs with CIs ####
# We use the total study N (denominator) for the overall Top 10 calculation
total_N <- n_distinct(adsl$USUBJID) 
cat ("Total number of unique subjects (N):\n")
print(total_N)
cat("\n")

ae_stats <- adae %>%
  filter(TRTEMFL == "Y") %>%
  group_by(AETERM) %>%
  summarise(n = n_distinct(USUBJID), .groups = "drop_last") %>%
  mutate( #Clopper-Pearson calculation
    p = n / total_N,
    lower = if_else(n == 0, 0, qbeta(0.025, n, total_N - n + 1)) * 100, #Lower CI
    upper = if_else(n == total_N, 1, qbeta(0.975, n + 1, total_N - n)) * 100, #Upper CI
    pct = p * 100 #percentage of patients
  ) %>%
  slice_max(n, n = 10, with_ties = FALSE) #Top 10

cat("DIAGNOSTIC: Top 10 AE Incidence Data:\n")
print(ae_stats %>% select(AETERM, n, pct, lower, upper))
cat("\n")

#### Step 2 Create ggplot 10 most frequent adverse events ####
top10_plot <- ggplot(ae_stats, aes(x = reorder(AETERM, pct), y = pct)) +
  geom_point(size = 5) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.3) +
  coord_flip() + 
  labs(
    title = "Top 10 Most Frequent Adverse Events",
    subtitle = paste0("n = ", total_N, " subjects; 95% Clopper-Pearson CIs"),
    x = "Adverse Event (Preferred Term)",
    y = "Percentage of Patients (%)"
  )

ggsave("question_3_tlg/Top_10_AE_Plot.png", top10_plot, width = 10, height = 7, dpi = 300)
cat("Top 10 AE plot saved as PNG.\n")

cat("====================================================================\n")

sink(type = "message") # Stop capturing warnings
sink()                # Stop capturing console output
close(log_file)
