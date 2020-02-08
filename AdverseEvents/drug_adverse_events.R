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
knitr::opts_chunk$set(message = F, warning = F, fig.width = 8, fig.height = 6, echo = F)

#+ r load_pks
library(httr)
library(jsonlite)
library(tidyverse)
library(data.table)
library(lubridate)

# take apikey as input
apikey = rstudioapi::askForPassword("Enter API Key:")

base_url <- "https://api.fda.gov/"
endpoint <- "drug/event.json"

#' ## {.tabset}

#' ### How many Records per day?

## Fetch count of records received data ----

#' - **Just for this section, let's keep the timeframe to Jan 2017 to 2019 Q3**
#' - There is an API that returns a timeseries - let's use it
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
autoplot(ts_obj) + labs(y = "Number of Reports Received", 
                        title = paste("Number of Reports Received since",
                                      paste(range(ts_df_m$ym), collapse = " to ")))

ggseasonplot(ts_obj, year.labels = TRUE)
ggsubseriesplot(ts_obj)


#' ### Explore 2019 Q3 data 
#' - **This analysis is primarily restricted to events within 2019 Q3.**

## load dataset
data_df <- readRDS("/home/rstudio/combined_df.RDS")

#+ r check_colnames, results = "hide"
names(data_df)
sapply(data_df, class)

## we see that reaction and drug columns are lists with dataframes

## definitions of columns are available here:  https://open.fda.gov/apis/drug/event/searchable-fields

## let's create seperate dataframes for reaction & drug info
## results.safetyreportid is the unique id

reaction_df <- data_df %>%
  select(results.safetyreportid, results.patient.reaction) %>%
  unnest(results.patient.reaction)

drug_df <-  data_df %>%
  select(results.safetyreportid, results.patient.drug) %>%
  unnest(results.patient.drug)

