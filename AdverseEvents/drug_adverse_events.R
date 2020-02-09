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
data_df <- readRDS("/newvolume/home/ubuntu/adverse_events_fda/combined_df.RDS")
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

## we see that reaction and drug columns are lists with dataframes
## definitions of columns are available here:  https://open.fda.gov/apis/drug/event/searchable-fields
## let's create seperate dataframes for reaction & drug info
reaction_df <- data_df %>%
  select(safetyreportid, patient.reaction) %>%
  unnest(patient.reaction)

drug_df <-  data_df %>%
  select(safetyreportid, patient.drug) %>%
  unnest(patient.drug)

#' #### Adverse Events by country
#' - Let's attempt to answer if different adverse events are reported in different countries?

## occurcountry column should help with this
## as per definitions - this column is the name of the country where the event occurred.
#' - Number of distinct countries where events occured: `r n_distinct(data_df$occurcountry)`
sort(table(data_df$occurcountry, exclude = NULL), decreasing = TRUE)
occurcountry_names <- read_csv("https://datahub.io/core/country-list/r/data.csv")
data_df <- data_df %>%
  left_join(occurcountry_names, by = c("occurcountry" = "Code"))
#' - Top 20 occuring countries with names
sort(table(data_df$Name, exclude = NULL), decreasing = TRUE) %>% head(20)

#' - What are different adverse reactions? 
#' - Number of distinct adverse reactions: `r n_distinct(reaction_df$reactionmeddrapt)`

reaction_df <- reaction_df %>% 
  left_join(data_df %>% select(safetyreportid, Name), by = "safetyreportid")

#' - Let's get what are the top 10 adverse reactions 
reaction_df <- data.table(reaction_df)
top10_ae <- reaction_df[, .(NumEvents = uniqueN(safetyreportid)), by = .(reactionmeddrapt)][order(-NumEvents)][1:10]

top10_ae %>%
  ggplot(aes(x= reorder(reactionmeddrapt, NumEvents), y = NumEvents)) +
  geom_col(fill = "steelblue") +
  geom_label(aes(label = NumEvents)) +
  labs(title = "Top 10 adverse events", 
       x = "Adverse Event", 
       y = "# Events Reported") +
  coord_flip() 
  
#' - What are the top 5 countries for each of the top 10 adverse reactions?
reaction_df[reactionmeddrapt %in% top10_ae$reactionmeddrapt, .(NumEvents = uniqueN(safetyreportid)), by = .(reactionmeddrapt, Name)][order(-NumEvents), head(.SD, 5), by = .(reactionmeddrapt)]

#' - How many countries have these top 10 adverse events
reaction_df[reactionmeddrapt %in% top10_ae$reactionmeddrapt, .(NumCountries = uniqueN(Name)), by = .(reactionmeddrapt)] %>%
  ggplot(aes(x = forcats::fct_relevel(reactionmeddrapt, levels = rev(top10_ae$reactionmeddrapt)), y = NumCountries)) +
  geom_col(fill = "steelblue") +
  geom_label(aes(label = NumCountries)) +
  labs(title = "Top 10 adverse events and # countries they occured in",
       y = "# countries",
       x = "Adverse Event") +
  coord_flip()


  
