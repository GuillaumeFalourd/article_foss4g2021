# Prepare data for Arabesque

# Data source : INSEE, 2021, https://www.insee.fr/fr/statistiques/4507779?sommaire=4508161#consulter
# data title: Mobilités scolaires des individus : déplacements commune de résidence / commune de scolarisation en 2017

library(dplyr)
library(readr)
library(dplyr)
library(sf)
library(vroom)
library(here)
#remotes::install_github("jimhester/archive")
library(archive)

# download data
data_url <- "https://www.insee.fr/fr/statistiques/fichier/4507779/RP2017_mobsco_csv.zip"
temp <- tempfile()
download.file(data_url,temp)
file <- "FD_MOBSCO_2017.csv" # file to unzip
data <- vroom::vroom(archive::archive_read(temp, file), delim = ";")


filtered_data <- data %>%
  dplyr::filter(!ILETUD %in% c(1,7)) %>% # remove loops in the same commune or outside France
  dplyr::filter(DIPL %in% c(14:19)) %>% # keep only students
  dplyr::select("COMMUNE", # living city code -> **Origin**
                "DCETUF", # Studying department and commune code -> **Destination**
                "REGION", # Living Region
                "REGETUD", # Studying region
                "ILETUD", # indicator o
                "METRODOM", # useful to filter Metropolitan France and DROMs
                "IPONDI",# Weight variable
                "SEXE", # SEXE
                "CSM" # 	socio-professional category
                )
unlink(temp)

# checks
## Study in the same city (should be 0)
filtered_data %>% filter(COMMUNE == DCETUF) %>% count()
## Study outside France (should be 0)
filtered_data %>% dplyr::filter(DCETUF == 99999) %>% dplyr::count()

# Export
# Raw data
filtered_data %>% readr::write_csv(file = here::here("data", "OD_filtered_data.csv"))

# Weighted data
filtered_data %>%
  group_by(COMMUNE,
           DCETUF,
           CSM,
           SEXE,
           REGION,
           REGETUD,
           METRODOM,
           ILETUD) %>%
  summarise(flow = sum(IPONDI),
            count = n()) %>%
  readr::write_csv(file = here::here("data", "OD_weighted_data.csv"))

# Read Weighted data
OD_weighted_data <- readr::read_csv(
  file = here::here("data", "OD_weighted_data.csv"),
  col_types = readr::cols(.default = "c", flow = "d",count = "d"))

# Departement flows Weighted data
OD_weighted_data %>%
  dplyr::mutate(
    CODE_DEP = substr(COMMUNE, 1,2),
    DEP_ETUD = substr(DCETUF, 1,2)) %>%
  dplyr::group_by(CODE_DEP, DEP_ETUD, CSM, SEXE, REGION, REGETUD, METRODOM, ILETUD) %>%
  dplyr::summarise(flow=sum(flow), count = sum(count)) %>%
  readr::write_csv(file = here::here("data", "OD_departements_weighted_data.csv"))

# EPCI flows Weighted data
## get EPCI code for each commune
communes <- sf::read_sf(
  here::here("data-raw/COMMUNE_CARTO.shp"))  %>%
  sf::st_drop_geometry() %>%
  dplyr::select(INSEE_COM, CODE_EPCI)

OD_weighted_data %>% dplyr::left_join(communes, by =  c("COMMUNE" = "INSEE_COM")) %>%
  dplyr::rename(EPCI_ORIGIN = CODE_EPCI) %>%
  dplyr::left_join(communes, by =  c("DCETUF" = "INSEE_COM")) %>%
  dplyr::rename(EPCI_DEST = CODE_EPCI) %>%
  dplyr::group_by(EPCI_ORIGIN, EPCI_DEST, CSM, SEXE, REGION, REGETUD, METRODOM, ILETUD) %>%
  dplyr::summarise(flow=sum(flow), count = sum(count)) %>%
  readr::write_csv(file = here::here("data", "OD_epci_weighted_data.csv"))

