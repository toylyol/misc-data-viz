
#***********
# HEXBIN MAP ----


## References ----

# https://r-graph-gallery.com/328-hexbin-map-of-the-usa.html


## Load packages ----

library(fontawesome)
library(tidyverse)
library(openxlsx)
library(mapview)
library(here)
library(sf)

path <- here()


## Retrieve subset of Multiple Chronic Conditions (MCC) dataset using CMS API ----
# 
# library(jsonlite)
# 
# url <- "https://data.cms.gov/data-api/v1/dataset/15b08729-6ea2-4789-bf1a-b96b1da8338f/data?filter[Bene_Demo_Lvl][value]=Sex&filter[Bene_Geo_Lvl][value]=State"
# 
# mcc_data <-  jsonlite::fromJSON(url)

# write.xlsx( mcc_data, paste0(path, "/data/mcc_data.xlsx") ) # save a copy of the MCC data


## Load MCC data ----

mcc_data <- read.xlsx( paste0(path, "/data/mcc_data.xlsx") )

### Ensure correct data type ----

mcc_data <- mcc_data %>% 
  mutate( across(c(Prvlnc, Tot_Mdcr_Stdzd_Pymt_PC, Tot_Mdcr_Pymt_PC, Hosp_Readmsn_Rate, ER_Visits_Per_1000_Benes), 
                 as.numeric) )


## Subset MCC data ----

data <- mcc_data %>%
  filter( Bene_Age_Lvl == "<65",
          Bene_Demo_Desc == "Female",
          Bene_MCC == "6+" )


## Load hexagonal U.S. shapefile ----

shapefile <- paste0(path,"/data/us_states_hexgrid.shp") # download from CARTO

hex_map <- read_sf(shapefile)

### Clean up shapefile columns ----

hex_map <- hex_map %>%
  mutate( google_nam = gsub(" \\(United States\\)", "", google_nam) ) %>%
  rename( state_name = google_nam,
          abbrev = iso3166_2 ) %>%
  select( -c(created_at, updated_at, label, bees) ) # remove necessary columns

### Join (non-spatial) with MCC data ----

hex_map <- hex_map %>%
  left_join( data, by = c("state_name" = "Bene_Geo_Desc") )


## Generate map ----

hex_map <- hex_map %>%
  ggplot() +
  geom_sf( aes(fill = Prvlnc) ) +
  coord_sf() +
  theme_void()

# I started to run into issues with geom_sf_label( aes(label = abbrev) ) from https://ggplot2-book.org/maps.html...  
# This produced an error message about using fortify().



#***********
# SLOPEGRAPH ----


## References ----

# The aca_data CSV was downloaded from Kaggle: https://www.kaggle.com/datasets/hhs/health-insurance
# A "light gray" gradient courtesy of ColorHexa: https://www.colorhexa.com/d3d3d3
# There is a package to create a momchromatic palette: https://github.com/cararthompson/monochromeR
# The colorgorical tool is great for generating color palettes that are easy to discriminate.
# https://community.rstudio.com/t/setting-colours-in-ggplot-conditional-on-value/8328/2
# https://r-graphics.org/recipe-appearance-hide-gridlines - remove horizontal gridlines
# http://www.sthda.com/english/wiki/ggplot2-line-types-how-to-change-line-types-of-a-graph-in-r-software
# https://stackoverflow.com/questions/14487188/increase-distance-between-text-and-title-on-the-y-axis
# https://stackoverflow.com/questions/15624656/label-points-in-geom-point
# https://github.com/rladies/meetup-presentations_freiburg/blob/master/2021-11-10_ggplot_fonts/ggplot_fonts_RLadiesFreiburg.Rmd


## Load packages and raw data ----

library(tidyverse)
library(openxlsx)
library(ggrepel)
library(ggtext)
library(here)


## Load and clean data ----

path <- here()

# raw_data <- read.csv( paste0(path, "/data/aca_data.csv") )
# 
# ### Rename columns ----
# 
# data <- raw_data %>% rename(
#   
#   "state" = "State",                                        
#   "uninsured_rate_2010" = "Uninsured.Rate..2010.",                       
#   "uninsured_rate_2015" = "Uninsured.Rate..2015.",                        
#   "uninsured_rate_change" = "Uninsured.Rate.Change..2010.2015.",
#   "insurance_cvg_change" = "Health.Insurance.Coverage.Change..2010.2015.",  # unclear meaning
#   "employer_cvg_2015" = "Employer.Health.Insurance.Coverage..2015.",        # unclear meaning
#   "marketplace_cvg_2016" = "Marketplace.Health.Insurance.Coverage..2016.",  # unclear meaning
#   "marketplace_tax_credits_2016" = "Marketplace.Tax.Credits..2016.",
#   "avg_mon_tax_credit_2016" = "Average.Monthly.Tax.Credit..2016.",
#   "state_Medicaid_expan_2016" = "State.Medicaid.Expansion..2016.",
#   "Medicaid_enroll_2013" = "Medicaid.Enrollment..2013.",
#   "Medicaid_enroll_2016" = "Medicaid.Enrollment..2016.",
#   "Medicaid_enroll_change" = "Medicaid.Enrollment.Change..2013.2016.",
#   "Medicare_enroll_2016" = "Medicare.Enrollment..2016."
#   
# )
# 
# ### Convert percentages to decimals ----
# 
# data$uninsured_rate_2010 <- as.numeric( gsub("%","",data$uninsured_rate_2010) )/100
# 
# data$uninsured_rate_2015 <- as.numeric( gsub("%","",data$uninsured_rate_2015) )/100
# 
# data$uninsured_rate_change <- as.numeric( gsub("%","",data$uninsured_rate_change) )/100
# 
# ### Remove whitespace and dollar signs ----
# 
# data$state <- stringr::str_trim(data$state)
# data$avg_mon_tax_credit_2016 <- stringr::str_trim(data$avg_mon_tax_credit_2016)
# data$avg_mon_tax_credit_2016 <- as.numeric( gsub("\\$","",data$avg_mon_tax_credit_2016) )
# 
# ### Correct error in dataset ----
# 
# data$uninsured_rate_change <- ifelse(data$state == "United States", -0.061, data$uninsured_rate_change)
# 
# ### Save a copy of cleaned data ----
# 
# write.xlsx( data, paste0(path, "/data/clean_aca_data.xlsx") )

data <- read.xlsx( paste0(path, "/data/clean_aca_data.xlsx") )


## Restructure data for slopegraph ----

### Identify states with the top 10 largest uninsured_rate_change ----

top_states <- data %>% 
  select(state, uninsured_rate_change) %>%
  filter(state != "United States") %>%            # remove aggregate value for entire country so not in top 10
  slice_min(uninsured_rate_change, n = 10) %>%    # replace the superseded top_n() function
  pull(state)                                     # isolate data in one column to save as a character vector to filter later

top_states[[11]] <- "United States" # add aggregate US to the top_states list to use for filtering

### Add columns to use in formatting ggplot ----

data <- data %>%
  mutate( pct_change = as.character(round(uninsured_rate_change*100, 0)) ) %>%
  mutate( line_style = ifelse(state == "United States", "dotted", "solid") ) %>%
  mutate( abbrev = case_when(state == "Nevada" ~ "NV",
                             state == "Oregon" ~ "OR",
                             state == "California" ~ "CA",
                             state == "Kentucky" ~ "KY",
                             state == "New Mexico" ~ "NM",
                             state == "West Virginia" ~ "WV",
                             state == "Arkansas" ~ "AR",
                             state == "Florida" ~ "FL",
                             state == "Colorado" ~ "CO",
                             state == "Washington" ~ "WA",
                             state == "United States" ~ "USA"))
  

### Subset dataframe ----

df_slopegraph <- data %>% 
  filter(state %in% top_states) %>%
  select(state, uninsured_rate_2010, uninsured_rate_2015, pct_change, line_style, abbrev) %>%
  pivot_longer(!c(state, pct_change, line_style, abbrev), names_to = "date", values_to = "rate") 

df_slopegraph$date <- df_slopegraph$date %>%
  str_replace_all("uninsured_rate_2010", "2010") 

df_slopegraph$date <- df_slopegraph$date %>%
  str_replace_all("uninsured_rate_2015", "2015")


## Generate a monochromatic color palette ----

# mono_palette <- monochromeR::generate_palette( c(15, 75, 99), 
#                                     modification = "go_lighter", 
#                                     n_colours = 3 )
# 
# # use view_palette(mono_palette) to see the palette in viewer
# # put mono_palette in console to see all hex codes from darkest to lightest
# # [1] "#0F4B63" "#6F93A1" "#CFDBDF"

### Save monochromatic color palette ----

mono_palette <- c("-6" = "#d3d3d3",
                  "-8" = "#CFDBDF",
                  "-9" = "#6F93A1",
                  "-10" = "#0F4B63")


## Delineate Colorgorical color palette ----

# The following parameters were used in the Colorgorical tool () in order to generate the color palette:
# starting color, #0F4B63; lightness range, 25-85; hue filters, 150-177 degrees; score importance, 100% pair preference.

teal_palette <- c("-6" = "#d3d3d3",
                  "-8" = "#104a61", 
                  "-9" = "#94e4ca", 
                  "-10" = "#3fa187")

## Delineate minimal color palette ----

minimal_palette <- c("-6" = "#CFDBDF",
                     "-8" = "#CFDBDF", 
                     "-9" = "#CFDBDF", 
                     "-10" = "#0F4B63")

# Top 10 States with Largest Decrease in Percentage of Uninsured Persons after the Affordable Care Act 
# On average, the uninsured rate in the United States decreased six percent from 2010 to 2015. The states were the <span style ='color: #0F4B63'> largest decrease </span> were California, Oregon, and Nevada.

## Generate slopegraph ----

slopegraph <- ggplot(data = df_slopegraph, aes(x = date, y = rate, group = state, color = pct_change,
                                               linetype = line_style, label = paste0(abbrev, "  ", rate*100, "%")))  +
  geom_line(alpha = 1, size = 1.25) +
  geom_point(alpha = 1, size = 4) +
  geom_text_repel() +                                               # label points directly
  scale_color_manual(values = minimal_palette) +
  scale_linetype_manual(values = c("solid" = "solid", 
                                   "dotted" = "dotdash")) +
  xlab("\nYear") +                                            # change axes titles, using newline to add space between axes
  ylab("Percentage of Uninsured Persons\n") +
  labs(title = "Top 10 States with Largest Decrease in Percentage of Uninsured Persons after the Affordable Care Act",
       subtitle = "On average, the uninsured rate in the United States decreased six percent from 2010 to 2015. <br>The states with the <span style ='color: #0F4B63'>**largest decrease**</span> were California, Oregon, and Nevada.",
       caption = "Source: Kaggle") +
  theme_minimal() +
  theme(
    panel.grid.major.y = element_blank(),                     # remove horizontal gridlines 
    panel.grid.minor.y = element_blank(),
    plot.title = element_markdown(),                          # use {ggtext}; HTML tags will format text; markdown has to be used for bolding font-weight span style will not work
    plot.subtitle = element_markdown()
  )

# To DO:
# remove legends
# remove y-axis labels, but not title
# add point labels with state and rate
# use dark gray font (#3d3d3d) for all text
# fix labels
# add custom fonts: https://stackoverflow.com/questions/71573377/cannot-import-fonts-into-r
# https://cran.rstudio.com/web/packages/showtext/vignettes/introduction.html
# https://ibecav.github.io/slopegraph/
# https://ggrepel.slowkow.com/articles/examples.html
