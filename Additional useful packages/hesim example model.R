#Individual continuous time state transition model example
#Example based on 'hesim: Health Economic Simulation Modeling and Decision Analysis' by Davin Incerti and Jeroen Jansen
#https://www.researchgate.net/publication/349424271_hesim_Health_Economic_Simulation_Modeling_and_Decision_Analysis/link/605c068192851cd8ce65e830/download

# Load packages ---------------
# These will need installing if they have not been used before
# install.packages("hesim")
# install.packages("data.table")
# install.packages("flexsurv")
# install.packages("survminer")
# install.packages("heemod")
# install.packages("magrittr")
library(hesim)      # Containing the mock trial data and the functions for model construction
library(data.table) # Used for organising the data in this example
library(flexsurv)   # used for fitting parametric models to the trial data
library(survminer)  # useful for easily presenting Kaplan–Meier plots. It also loads `ggplot2` as a dependent, which is a versatile package for producing 
                    # almost any type of graph
library(heemod)     # Can produce a really simple model diagram - also has other useful 
                    # functions for partitioned survival modelling
library(diagram)    # Assists with creating the diagram from heemod
library(magrittr)   # Structuring data sequences with left -> right formatting instead of nested functions

#If there are issues with downloading packages or running parts of the model, please refer to the session info of the development
#environment used to create this to crosscheck attached packages.
#readRDS("./Additional useful packages/SessionInfo.rds")

# Informing inputs --------------
# ~ States and transitions ---------
# ~~ Define matrix ---------------
tmat <- rbind(
 c(NA, 1, 2),
 c(NA, NA, 3),
 c(NA, NA, NA)
 )
colnames(tmat) <- rownames(tmat) <- c("Stable", "Progression", "Death")
print(tmat)

# ~~ Define transitions ---------------
transitions <- create_trans_dt(tmat)#
print(transitions)

Model_Diagram <- define_transition( #this function is part of the heemod package
  state_names = c("Stable", "Progression", "Death"),
  Stable,transition_id_1, transition_id_2,
  ,Progressed, transition_id_3,
  , , Death
)
plot(Model_Diagram)

# ~~ Outline states and IDs in separate table for easy referencing --------------
# Death is automatically added by get_labels() (below) in the code below in the default settings,
# but 'death_label = NULL' argument in get_labels() this will override this. Current setup is to maintain simplicity
states <- data.table(
  state_id = 1:2,
  state_name = c("Stable", "Progression")
)


# ~ Strategies ----------------------
# ~~ Outline strategy and IDs ----------------
strategies <- data.table(
  strategy_id = 1:3,
  strategy_name = c("SOC", "New 1", "New 2")
  )

print(strategies)

# ~ Patients -------------
# ~~ Create patient sample to model -------------
n_patients <- 1000
patients <- data.table(
  patient_id = 1:n_patients,
  age = rnorm(n_patients, mean = 45, sd = 7),
  female = rbinom(n_patients, size = 1, prob = .51)
)
# If groups are wanted, these can be defined in the 'grp_id' and 'grp_name' columns. Otherwise can be commented and left blank.
# patients[, grp_id := ifelse(female == 1, 1, 2)]
# patients[, grp_name := ifelse(female == 1, "Female", "Male")]

#This is a plot to show the patient samples - it is an example of how ggplot can be used
Patient_plot <- ggplot(patients, aes(x = age, fill = as.factor(female))) + 
  geom_histogram(binwidth = 1, colour = "#959595") + 
  theme_bw() + 
  scale_fill_manual("Gender:", values = c("#0D8E1E","#9552BB"),
                    labels = c("Male","Female"))

Patient_plot

# ~ Organising basic model settings ------------  
# ~~ Create hesim data object -----------
hesim_dat <- hesim_data(
   strategies = strategies,
   patients = patients,
   states = states,
   transitions = transitions
   )

print(hesim_dat)

# ~~ Setting up labels for state and strategy IDs ---------------
labs_indiv <- get_labels(hesim_dat)
print(labs_indiv)

# ~ 'Trial' data ----------
# hesim package includes the 'onc3' data.table. This separates the three transitions by 'transition_id', where the IDs match the 'transitions' data
# These individual transitions can be filtered for and have parametric models fitted
# Data example showing patients 1 and 2:
onc3[patient_id %in% c(1, 2)]

#view the data
transition_id_view <- 1
TransitionData <-
  survfit(as.formula(Surv(time, status) ~ strategy_name), data = onc3[which(transition_id == transition_id_view),])

trialdata_plot <- ggsurvplot(
  fit      = TransitionData,
  data     = onc3,
  # break.y.by = 0.1,
  # break.x.by = 0.5,
  xlab = 'Time (Years)',
  #xlim = c(0,5),
  ylab = 'Survival',
  #palette=c("red","blue","green"),
  risk.table = TRUE,
  #risk.table.y.text.col = TRUE,
  #risk.table.height = 0.3,
  #risk.table.title = 'Number at risk',
  #conf.int = T,
  #linetype = c(1,2),
  legend = "top"
)
trialdata_plot 

# ~~ Fit the survival data ------------------
n_trans <- max(tmat, na.rm = TRUE)
wei_fits <- vector(length = n_trans, mode = "list")
f <- as.formula(Surv(time, status) ~ factor(strategy_name) + female + age)


for (i in 1:length(wei_fits)){
  if (i == 3) {f <- update(f, .~.-factor(strategy_name))} 
  wei_fits[[i]] <- flexsurvreg(f, data = onc3,
                               subset = (transition_id == i),
                               dist = "weibull")
}

wei_fits <- flexsurvreg_list(wei_fits)

# ~ Costs ---------------------
# ~~ Create time-dependent drug costs per strategy --------------
# The time units are in years.
drugcost_dt <- matrix(c(
  1, 1, 1, 0.00, 0.25,  2000,
  1, 1, 2, 0.25, Inf, 2000,
  1, 2, 1, 0.00, 0.25,  1500,
  1, 2, 2, 0.25, Inf , 1200,
  2, 1, 1, 0.00, 0.25,  12000,
  2, 1, 2, 0.25, Inf , 12000,
  2, 2, 1, 0.00, 0.25,  1500,
  2, 2, 2, 0.25, Inf , 1200,
  3, 1, 1, 0.00, 0.25,  15000,
  3, 1, 2, 0.25, Inf , 15000,
  3, 2, 1, 0.00, 0.25,  1500,
  3, 2, 2, 0.25, Inf , 1200
),byrow = TRUE, ncol = 6, dimnames = list(NULL, c("strategy_id", "state_id", "time_id", "time_start", "time_stop","est")))
drugcost_dt <- data.table(drugcost_dt)
print(drugcost_dt)

drugcost_tbl <- stateval_tbl(
  drugcost_dt,
  dist = "fixed")
print(drugcost_tbl)

# ~~ Medical costs ---------------
medcost_tbl <- stateval_tbl(
  data.table(state_id = states$state_id,
             mean = c(2000, 9500),
             se = c(2000, 9500)
  ),
  dist = "gamma")
print(medcost_tbl)

# ~ Utilities ----------------
utility_tbl <- stateval_tbl(
  data.table(state_id = states$state_id,
             mean = c(.8, .6),
             se = c(0.02, .05)
             ),
  dist = "beta")
print(utility_tbl)



# Setting up the model --------------
# ~ Number of parameter samples is needed to use for the PSA
n_samples <- 1000

# ~ Expanding the data input dataframe to set up for running all patients with all strategies
transmod_data <- expand(hesim_dat,
                        by = c("strategies", "patients"))
head(transmod_data)

# ~ Wrapping inputs in hesim functions for use in model -------------
# ~~ Efficacy -----------------
transmod <- create_IndivCtstmTrans(object = wei_fits, 
                                   input_data = transmod_data,
                                   trans_mat = tmat, n = n_samples,
                                   uncertainty = "normal",
                                   clock = "reset",
                                   start_age = patients$age)

# ~~ Utilities -----------------
utilitymod <- create_StateVals(utility_tbl, n = n_samples,
                               hesim_data = hesim_dat)

# ~~ Costs ------------------
drugcostmod <- create_StateVals(drugcost_tbl, n = n_samples,
                                time_reset = TRUE, hesim_data = hesim_dat)
medcostmod <- create_StateVals(medcost_tbl, n = n_samples,
                                 hesim_data = hesim_dat)
costmods <- list(Drug = drugcostmod,
                   Medical = medcostmod)

# ~ Combining input into economic model -------------------
ictstm <- IndivCtstm$new(trans_model = transmod,
                         utility_model = utilitymod,
                         cost_models = costmods)


# Run the disease simulation ----------------
# ~ Run simulation -------------
# This runs the disease simulation, and assumed that the max patient age is 100 (after which they automatically transfer to 'Death' state)
ictstm$sim_disease(max_age = 100, progress = TRUE)
# This is the event data simulated for each patient
head(ictstm$disprog_)

# ~ Generate outcomes --------------
# ~~ Survival --------------
# Create survival curves with set time intervals
# Time is in years, so this will measure from 0 to 30 years, with 1/12 (1 month) intervals 
ictstm$sim_stateprobs(t = seq(0, 30 , 1/12))
head(ictstm$stateprobs_)

Results_plot <- autoplot(ictstm$stateprobs_, labels = labs_indiv,
            ci = FALSE) + theme_bw()

Results_plot 

# ~~ QALYS -------------
# QALYs and costs are simulated separately from the simulation of the disease
ictstm$sim_qalys(dr = c(0,.03))
head(ictstm$qalys_)

# ~~ Costs ------------ 
ictstm$sim_costs(dr = c(0,.01))
head(ictstm$costs_)


# ~ Summarize ----------------
ce_sim_ictstm <- ictstm$summarize()

summary(ce_sim_ictstm, labels = labs_indiv) %>%
  format()


# REPORT ------------------------
library(rmarkdown)   # For creating markdown outputs (html and pdf)
library(bookdown)    # For creating markdown outputs (html and pdf)
library(knitr)       # For creating markdown outputs (html and pdf)
library(kableExtra)  # For creating nice-looking tables in rmarkdown

Export_params <- list(
  # Main results
  Stateprobs            = ictstm$stateprobs_,
  Summarisedf           = ce_sim_ictstm,
  labs_indiv            = labs_indiv
)

Markdown_location <- "./Additional useful packages/R Markdown scripts/"

# html document
rmarkdown::render(
  input = file.path(Markdown_location,"hesim html report.Rmd"),
  output_format = 'bookdown::html_document2',
  output_file = "./Additional useful packages/hesim-html-report.html",
  params = Export_params,
  envir = environment()
)

# pdf document
rmarkdown::render(
  input = file.path(Markdown_location,"hesim pdf report.Rmd"),
  output_format = 'bookdown::pdf_document2',
  output_file = "./Additional useful packages/hesim-pdf-report.pdf", 
  params = Export_params,
  envir = environment()
)

