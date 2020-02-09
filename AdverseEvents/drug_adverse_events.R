#' ---
#' title: FDA Drug Adverse Events - Data Exploration
#' date: "`r format(Sys.time(), format = '%B %d, %Y')`" 
#' output:
#'    html_document:
#'      theme: readable
#'      highlight: pygments
#' ---


#' #' <style>
#'  .main-container {
#'    max-width: 1600px !important;
#'  }
#' </style>


#+ r setup, echo = F
knitr::opts_chunk$set(message = F, warning = F, fig.width = 9, fig.height = 7, echo = F)

#+ r load_pks
library(httr)
library(jsonlite)
library(tidyverse)
library(data.table)
library(lubridate)
library(forecast)

# take apikey as input
apikey = rstudioapi::askForPassword("Enter API Key:")

base_url <- "https://api.fda.gov/"
endpoint <- "drug/event.json"

#' ## {.tabset}

#' ### How many Records per day?

## Fetch count of records received data ----

#' - **Just for this section, let's keep the timeframe to Jan 2017 to 2019 Q3**
#' - There is an API that returns a timeseries - let's use it
#' - Ref: https://open.fda.gov/apis/timeseries/
records_perday_call <- paste(base_url, endpoint,"?search=receivedate:[2017-01-01+TO+2019-12-20]", "&count=receiptdate", sep = "")

records_perday_call_request <- GET(records_perday_call)
ts_response <- content(records_perday_call_request, as = "text", encoding = "UTF-8")

ts_df <- fromJSON(ts_response, flatten = TRUE) %>%
  data.frame() %>%
  ## keep only date and count columns
  select(results.time, results.count) %>%
  # change date to proper format
  mutate(results.time = ymd(results.time))

range(ts_df$results.time)

ts_df_m <- ts_df %>%
  mutate(ym = format(results.time, '%Y-%m-01')) %>%
  group_by(ym) %>%
  summarise(ym_sum = sum(results.count))

ts_obj <- ts(ts_df_m$ym_sum, start = c(2017,1), frequency = 12)
autoplot(ts_obj) + labs(y = "Number of Reports Received per month", 
                        title = paste("Number of Reports Received since",
                                      paste(range(ts_df_m$ym), collapse = " to ")))

ggseasonplot(ts_obj, year.labels = TRUE)
ggsubseriesplot(ts_obj)

#' ### Explore 2019 Q3 data {.tabset}
#' - **This analysis is primarily restricted to events within 2019 Q3.**

## load dataset
data_df <- readRDS("/home/ubuntu/adverse_events_fda/combined_df.RDS")
## 441477 39

glimpse(data_df)

#+ r check_colnames, results = "hide"
names(data_df)
sapply(data_df, class)

## results.safetyreportid is the unique id
#' - Number of Unique reports received by FDA: `r n_distinct(data_df$safetyreportid)`
# 441477

#' - Timerange of reports received 
#' - Note that receiptdate is Date that the most recent information in the report was received by FDA
#' - Range of receiptdate: `r range(data_df$receiptdate)`
#' - receivedate is Date that the report was first received by FDA. If this report has multiple versions, this will be the date the first version was received by FDA.
#' - Range of receivedate: `r range(data_df$receivedate)`
data_df <- data_df %>%
  mutate(receivedate = ymd(receivedate),
         receivedate_year = year(receivedate))

data_df %>% 
  group_by(receivedate_year) %>%
  summarise(NumReports = n_distinct(safetyreportid)) %>%
  arrange(desc(NumReports))

#' - **Makes sense to keep reports received in year 2019**

data_df_2019 <- data_df %>%
  filter(receivedate_year == 2019)
## we see that reaction and drug columns are lists with dataframes
## definitions of columns are available here:  https://open.fda.gov/apis/drug/event/searchable-fields
## let's create seperate dataframes for reaction & drug info
reaction_df <- data_df_2019 %>%
  select(safetyreportid, patient.reaction) %>%
  unnest(patient.reaction)

drug_df <-  data_df_2019 %>%
  select(safetyreportid, patient.drug) %>%
  unnest(patient.drug)

#' #### Gender, Age, Weight
## gender
gender_map <- tibble(code = c("0", "1", "2"), gender = c("Unknown", "Male", "Female"))
data_df_2019 <- data_df_2019 %>%
  left_join(gender_map, by = c("patient.patientsex" = "code"))

data_df_2019 %>%
  group_by(gender) %>%
  summarise(NumReports = n_distinct(safetyreportid),
            FractionReports = scales::percent(NumReports/nrow(.), accuracy = 1L)) %>%
  arrange(desc(NumReports))

## age
age_map <- tibble(code = c("1","2","3","4","5","6"),
                  age_group = c("Neonate", "Infant", "Child", 
                                "Adolescent", "Adult", "Elderly"))
data_df_2019 <- data_df_2019 %>%
  left_join(age_map, by = c("patient.patientagegroup" = "code"))

data_df_2019 %>%
  group_by(age_group) %>%
  summarise(NumReports = n_distinct(safetyreportid),
            FractionReports = scales::percent(NumReports/nrow(.), accuracy = 1L)) %>%
  arrange(desc(NumReports))

# weight
data_df_2019 %>% 
  summarise(NoWeightInfo = sum(is.na(patient.patientweight)),
            HasWeightInfo = sum(!is.na(patient.patientweight)),
            HasWeight_Fraction = scales::percent(HasWeightInfo/nrow(.)))

data_df_2019 %>%
  ggplot(aes(x = as.numeric(patient.patientweight))) + geom_density()

#' #### Adverse Events and Occuring countries
#' - Let's attempt to answer if different adverse events are reported in different countries?

#' - Adverse Events definition is available here:https://www.fda.gov/safety/reporting-serious-problems-fda/what-serious-adverse-event
#' - 1 = The adverse event resulted in death, a life threatening condition, hospitalization, disability, congenital anomaly, or other serious condition
#' - 2 = The adverse event did not result in any of the above
table(data_df_2019$serious, exclude = NULL)

## occurcountry column should help with this
## as per definitions - this column is the name of the country where the event occurred.
#' - Number of distinct countries where events occured: `r n_distinct(data_df_2019$occurcountry)`
sort(table(data_df_2019$occurcountry, exclude = NULL), decreasing = TRUE)
occurcountry_names <- read_csv("https://datahub.io/core/country-list/r/data.csv")
data_df_2019 <- data_df_2019 %>%
  left_join(occurcountry_names, by = c("occurcountry" = "Code"))
#' - Top 20 occuring countries with names
sort(table(data_df_2019$Name, exclude = NULL), decreasing = TRUE) %>% head(20)

data_df_2019 %>% 
  group_by(serious, Name) %>%
  summarise(NumReports = n_distinct(safetyreportid)) %>%
  #arrange(desc(NumReports))
  top_n(10, wt = NumReports) %>%
  ggplot(aes(x = reorder(Name, NumReports), y = NumReports)) +
  geom_col(fill = "steelblue") +
  coord_flip() +
  facet_wrap(serious ~ ., scales = "free") +
  geom_label(aes(label = NumReports), size = 3) +
  labs(x = "Country in which Event Occured", y = "Number of Reports")

data_df_2019 %>% 
  group_by(serious) %>%
  summarise(NumCountries = n_distinct(Name)) %>%
  arrange(desc(NumCountries))

serious1_event_cols <- names(data_df_2019)[grepl("seriousness", names(data_df_2019))]

num_reports <- sapply(serious1_event_cols, function(e) sum(data_df_2019[[e]]==1, na.rm=T))

serious1_df <- tibble(category = serious1_event_cols,
                      NumReports = num_reports) %>%
  mutate(FractionSerious1 = scales::percent(NumReports/nrow(data_df_2019[data_df_2019$serious==1,]))) %>%
  arrange(desc(NumReports))

serious1_df

#' #### Adverse Reactions and Occuring countries  
#' - What are different adverse reactions? 
#' - Number of distinct adverse reactions: `r n_distinct(reaction_df$reactionmeddrapt)`

reaction_df <- reaction_df %>% 
  left_join(data_df_2019 %>% select(safetyreportid, Name), by = "safetyreportid")

#' - Let's get what are the top 10 adverse reactions 
reaction_df <- data.table(reaction_df)
top10_ae <- reaction_df[, .(NumReports = uniqueN(safetyreportid)), by = .(reactionmeddrapt)][order(-NumReports)][1:10]

top10_ae %>%
  ggplot(aes(x= reorder(reactionmeddrapt, NumEvents), y = NumReports)) +
  geom_col(fill = "steelblue") +
  geom_label(aes(label = NumReports)) +
  labs(title = "Top 10 adverse reactions", 
       x = "Adverse Reaction", 
       y = "# Events Reported") +
  coord_flip() 
  
#' - What are the top 5 countries for each of the top 10 adverse reactions?
reaction_df[reactionmeddrapt %in% top10_ae$reactionmeddrapt, .(NumReports = uniqueN(safetyreportid)), by = .(reactionmeddrapt, Name)][order(-NumReports), head(.SD, 5), by = .(reactionmeddrapt)]

#' - How many countries have these top 10 adverse reactions
reaction_df[reactionmeddrapt %in% top10_ae$reactionmeddrapt, .(NumCountries = uniqueN(Name)), by = .(reactionmeddrapt)] %>%
  ggplot(aes(x = forcats::fct_relevel(reactionmeddrapt, levels = rev(top10_ae$reactionmeddrapt)), y = NumCountries)) +
  geom_col(fill = "steelblue") +
  geom_label(aes(label = NumCountries)) +
  labs(title = "Top 10 adverse reactions and # countries they occured in",
       y = "# countries",
       x = "Adverse Event") +
  coord_flip()

#' #### Adverse Events and disease areas
#' - What are different adverse events associated with different disease conditions?
#' - Disease areas can be identified from drugindication column within drug_df
#' - What are different disease areas?
#' - Number of distinct disease areas: `r n_distinct(drug_df$drugindication[!is.na(drug_df$drugindication)])`
drug_df <- data.table(drug_df)
top_10_diseases <- drug_df[!is.na(drugindication) & drugindication != "PRODUCT USED FOR UNKNOWN INDICATION", 
        .(NumReports = uniqueN(safetyreportid)), 
        by = .(drugindication)][order(-NumReports)][1:10]

print(top_10_diseases)

#' - What are adverse events within top 10 diseases
ae_disease <- drug_df[drugindication %in% top_10_diseases$drugindication, c("safetyreportid", "drugindication")] %>%
  left_join(data_df_2019 %>% select(safetyreportid, serious, starts_with("seriousness")),
            by = "safetyreportid")

ae_disease %>%
  group_by(drugindication, serious) %>%
  summarise(NumReports = n_distinct(safetyreportid)) %>%
  ggplot(aes(x = forcats::fct_relevel(drugindication, 
                                      levels = rev(top_10_diseases$drugindication)), 
             y = NumReports, fill = serious)) +
  geom_bar(stat = "identity", position = "dodge", width = 0.7) +
  geom_label(aes(label = NumReports), 
             position = position_dodge(width = 0.7),
             size = 3.4) +
  labs(y = "Number of Reports", x = "",
       title = "Top 10 diseases and adverse event type") +
  coord_flip() 

ae_disease <- data.table(ae_disease)
ae_melt <- melt(ae_disease, 
                id.vars = c("safetyreportid", "drugindication"),
                measure.vars = serious1_event_cols)
ae_melt <- ae_melt[!is.na(value)]
ae_melt$variable = gsub("seriousness","", ae_melt$variable)

ae_melt %>%
  group_by(drugindication, variable) %>%
  summarise(NumReports = n_distinct(safetyreportid)) %>%
  ggplot(aes(x = forcats::fct_relevel(drugindication, 
                                      levels = rev(top_10_diseases$drugindication)), 
             y = NumReports, fill = variable)) +
  geom_bar(stat = "identity", position = "dodge", width = 0.7) +
  #geom_label(aes(label = NumReports), 
  #           position = position_dodge(width = 0.7),
  #          size = 3.4) +
  labs(y = "Number of Reports", x = "",
       title = "Top 10 diseases and serious1 adverse event type") +
  coord_flip() 

# for(e in serious1_event_cols){
#   cat(e, "\n")
#   ae_disease <- data_df_2019 %>% 
#     filter(!!rlang::sym(e) == 1) %>%
#     select(safetyreportid, e) %>%
#     inner_join(drug_df[!is.na(drugindication) & drugindication != "PRODUCT USED FOR UNKNOWN INDICATION",
#                        c("safetyreportid", "drugindication")], by = "safetyreportid") %>%
#     distinct() 
#   
#   ae_disease %>%
#     group_by(drugindication) %>%
#     summarise(NumReports = n_distinct(safetyreportid)) %>%
#     top_n(10, wt = NumReports) %>%
#     arrange(desc(NumReports))
# }

rm(ae_disease, ae_melt)

#' #### Drugs frequent itemsets
#' - What are the drugs frequently taken together
library(arules, lib.loc = "/home/ubuntu/R/x86_64-pc-linux-gnu-library/3.6")

#' - medicinalproduct is the drug info
#' - Number of distinct drugs: `r n_distinct(drug_df$medicinalproduct)`
#' - Our objective is to find out what drugs are commonly taken together. 
#' - We can use arules R package to identify frequent itemsets

## convert drugs data to transactions format
set(drug_df, j = "safetyreportid", )
dt_data <- as(drug_df[,c("safetyreportid", "medicinalproduct")], "transactions")

