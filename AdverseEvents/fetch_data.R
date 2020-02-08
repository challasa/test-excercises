
## Fetch Adverse Events data using open FDA API
## create a text file with links to all zip json files from open.fda.gov
## We are going to restrict to data from 2019

## https://open.fda.gov/apis/drug/event/searchable-fields
library(httr)
library(jsonlite)
library(tidyverse)

## json file containing path to zip files is available
## read in that, and get a file with all the zip files within 2019 Q3
zips_json <- GET("https://api.fda.gov/download.json")
zips_json_content <- content(zips_json, as = "text", encoding = "UTF-8")
zips_df <- fromJSON(zips_json_content)
zips_df <- flatten(zips_df$results$drug$event) %>% data.frame()

keep_df <- zips_df %>% filter(grepl("2019 Q3", display_name))
write.table(keep_df$file, file = "jsons_to_download.txt", 
            row.names = FALSE, col.names = FALSE, quote = FALSE)

## ----------
## run within terminal
## wget -i jsons_to_download.txt
## unzip \*.json.zip
## rm *.json.zip
## ----------

path <- "/newvolume/home/ubuntu/adverse_events_fda"
files <- dir(path, pattern = "*.json")
system.time(
  data_list <- lapply(1:length(files), function(indx) {
    fname = files[indx]
    print(paste(indx, fname, sep = ":"));
    fromJSON(file.path(path, fname), flatten = TRUE)$results
  }) 
)
## reading in 37 json files took a good 17minutes #20GB memory
system.time(
  combined_df <- data.table::rbindlist(data_list, use.names = TRUE)
) ## got done in 35 seconds

dim(combined_df) #441477 39
saveRDS(combined_df, file = "/home/rstudio/combined_df.RDS")

## ================
## There is an easier way to get data using the Web API - however one can only get 100 records
## and that's the limit set by openFDA
## =============
apikey = rstudioapi::askForPassword("Enter API Key:")
base_url <- "https://api.fda.gov/"
endpoint <- "drug/event.json"
num_events = 100
call <- paste(base_url, 
              endpoint,
              "?api_key=", apikey, 
              "&search=receivedate:[20170101+TO+20191220]&limit=", 
              num_events, sep="")
request <- GET(call)
response <- content(request, as = "text", encoding = "UTF-8")
# convert response to dataframe
data_df <- fromJSON(response, flatten = TRUE) %>%
  data.frame()





