
## Fetch Adverse Events data using open FDA API
## create a text file with links to all zip json files from open.fda.gov
## We are going to restrict to data from 2019

## https://open.fda.gov/apis/drug/event/searchable-fields
library(httr)
library(jsonlite)
library(tidyverse)

## json file containing path to zip files is available
## read in that, and get a file with all the zip files between 2017 and 2019
zips_json <- GET("https://api.fda.gov/download.json")
zips_json_content <- content(zips_json, as = "text", encoding = "UTF-8")
zips_df <- fromJSON(zips_json_content)
zips_df <- flatten(zips_df[[2]]$drug$event) %>% data.frame()

keep_df <- zips_df %>% filter(grepl("2019", display_name))
write.table(keep_df$file, file = "jsons_to_download.txt", 
            row.names = FALSE, col.names = FALSE, quote = FALSE)

## run wget -i jsons_to_download.txt
## run unzip \*.json.zip



