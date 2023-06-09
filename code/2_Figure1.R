source("code/1_setup.R")
source("code/theme.R")

#------------------------------------------------------------
## Clean and combine SBC LTER data
#------------------------------------------------------------

# Biomass conversion from: Nelson, C, D. Reed, S. Harrer, R. Miller. 2021. SBC LTER: Reef: Coefficients for estimating biomass from body size or percent cover for kelp forest species ver 3. Environmental Data Initiative. https://doi.org/10.6073/pasta/0fe9233dabe35df5d61fb3b07f8fb51e. Accessed 2022-01-04.


# get the lte urchin size data

# data citation: Reed, D, R. Miller. 2021. SBC LTER: Reef: Long-term experiment: Kelp removal: Urchin size frequency distribution ver 21. Environmental Data Initiative. https://doi.org/10.6073/pasta/fd564dddfe7b77fe9e4bd8417f166057. Accessed 2022-01-03.

urc.s <- read.csv(here("data/LTER", "LTE_Urchin_All_Years_20210209.csv"), header = T, na.strings = "-99999") %>% # get urchin size data for SBC LTER LTE transects.
  filter(TREATMENT == "CONTROL", COMMON_NAME == "Purple Urchin", YEAR > 2011) %>%
  dplyr::select(YEAR, MONTH, DATE, SITE, TRANSECT, SIZE, COUNT) %>% 
  rename_all(tolower) %>%
  filter(month == 8) 

sites <- distinct(urc.s, site)$site #save sites to filter other data

urc.s <- urc.s %>% 
  group_by_at(vars(-count)) %>% # group by all variables other than count
  complete(count = full_seq(1:count, 1))%>% # add dummy variable that is a running count within a size bin
  ungroup() %>%
  mutate(size = as.numeric(size) + 0.25, # add adjustment so that the size is the center of the size bin
         count = NULL, 
         mass =  0.000592598*(size*10)^2.872636198*1.01) %>% # estimate mass based on SBC LTER test diameter - weigh relationship.  IS THIS WET OR DRY MASS!!!!!!
  drop_na(size) %>% 
  group_by(year, site) %>%
  dplyr::select(-c(size, month, date, transect)) 


# Organize and clean lobster data

# Data citation: Reed, D, R. Miller. 2021. SBC LTER: Reef: Abundance, size and fishing effort for California Spiny Lobster (Panulirus interruptus), ongoing since 2012 ver 6. Environmental Data Initiative. https://doi.org/10.6073/pasta/0bcdc7e8b22b8f2c1801085e8ca24d59. Accessed 2022-01-03.

lob <- read.csv(here("data/LTER", "Lobster_Abundance_All_Years_20210412.csv"), header = T, na.strings = c(-99999), stringsAsFactors = F) %>% # get lobster abundance and size data from LTER
  rename_all(tolower) %>%
  filter(site %in% sites) %>% 
  filter(size_mm != 600) %>% # get rid of the size error for one lobster
  dplyr::select(year, month, site, transect, replicate, size_mm, count)

lob.s <- lob %>% 
  group_by(year, site, size_mm) %>% 
  summarize(count = sum(count))%>%
  group_by_at(vars(-count)) %>% 
  complete(count = full_seq(1:count, 1)) %>%
  ungroup() %>%
  mutate(size_mm = as.numeric(size_mm), 
         count = NULL, 
         mass = 0.001352821*(size_mm)^2.913963113) %>% #IS THIS WET OR DRY MASS!!!!!!!!!
  drop_na(size_mm) %>% 
  group_by(year, site) %>%
  dplyr::select(-size_mm)

#------------------------------------
## Summary stats for P1 of results
#------------------------------------

summary(lob.s$mass)
rethinking::PI(lob.s$mass, prob = .95)
# 3%       98% 
#   88.84656 897.78328 

summary(urc.s$mass)
rethinking::PI(urc.s$mass, prob = .95)
# 3%        98% 
#   8.161326 132.176989 


#-------------------------------------
## Conceptual version of the figure
#-------------------------------------

lob.col = "#CB3458"
  
urc.col = "#3458CB"

plot(1:2, bg = c(lob.col, urc.col), cex = 10, pch = 21)

# lobster size-distribution histo

p1 <- ggplot(urc.s, aes(x = mass))+
  geom_histogram(bins = 14, boundary = 0, fill = urc.col, alpha = 0.5, color = "black")+
  theme_bd()+
  theme(panel.border = element_rect(fill = NA))+
  labs(y = "Frequency", x = "Urchin mass (g)")

p2 <- ggplot(lob.s, aes(x = mass))+
  geom_histogram(boundary = 0, fill = lob.col, alpha = 0.5, color = "black")+
  theme_bd()+
  theme(panel.border = element_rect(fill = NA))+
  labs(y = "", x = "Lobster mass (g)")


toprow <- cowplot::plot_grid(p1, p2, nrow = 1)

# conceptual panels

summary(urc.s$mass)
# Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
# 8.161  19.893  39.229  46.568  52.297 266.129 

summary(lob.s$mass)
# Min.  1st Qu.   Median     Mean  3rd Qu.     Max. 
# 6.153  283.371  393.640  421.327  528.887 6184.008 

medium.urc <- data.frame(species = "Urchin", mass = rnorm(1000, 30, sd = 10),
                         scenario = "Medium")
hist(medium.urc$mass)

medium.lob <- data.frame(species = "Lobster", mass = rnorm(1000, 70, sd = 10),
                         scenario = "Medium")
hist(medium.lob$mass)

high.urc <- data.frame(species = "Urchin", mass = rnorm(1000, 10, sd = 10),
                       scenario = "High")
hist(high.urc$mass)

high.lob <- data.frame(species = "Lobster", mass = rnorm(1000, 100, sd = 10),
                       scenario = "High")
hist(high.lob$mass)

low.urc <- data.frame(species = "Urchin", mass = rnorm(1000, 45, sd = 10),
                      scenario = "Low")
hist(low.urc$mass)

low.lob <- data.frame(species = "Lobster", mass = rnorm(1000, 55, sd = 10),
                      scenario = "Low")
hist(low.lob$mass)


simu <- rbind(medium.urc, medium.lob, high.urc, high.lob, low.urc, low.lob) %>%
  filter(mass > 0)
#   group_by(species) %>%
#   mutate(mass = scale(mass))

b1 <- ggplot(simu, aes(x = mass))+
  geom_density(aes(x = mass, fill = species), adjust = 2, alpha = 0.5)+
  scale_fill_manual(values = c(lob.col, urc.col))+
  facet_wrap(~forcats::fct_relevel(scenario, "High", after = 2))+
  labs(x = "Relative body mass", y = "Density", fill = "")+
  theme_bd()+
  theme(legend.position = c(0.9, 0.5),
        strip.background = element_blank(),
        panel.border = element_rect(colour = "black", fill = NA), strip.text = element_text(hjust = 0, face = "bold", size = 16), 
        axis.ticks.x = element_blank(), 
        axis.text.x = element_blank())




plot1 <- cowplot::plot_grid(toprow, b1, nrow = 2) 

# effects on interaction strength


allometricFR <- function(lob_mass, urc_mass, urc_density, lob_density, beta1a., beta2a., beta1h., beta2h., h0., a0., T = 1, ...){
  
  loga <- a0. + beta1a.*log(lob_mass) + beta2a.*log(urc_mass)
  logh <- h0. + beta1h.*log(lob_mass) + beta2h.*log(urc_mass)
  a <- exp(loga)
  h <- exp(logh)
  a*urc_density*lob_density*T / (1 + a*h*urc_density)
  
}


simu2 <- rbind(medium.urc, medium.lob, high.urc, high.lob, low.urc, low.lob) %>%
  filter(mass > 0) %>%
  as_tibble() %>% 
  group_by(species) %>%
  mutate(id = 1:n()) %>%
  pivot_wider(names_from = species, values_from = mass) %>%
  mutate(IS = allometricFR(lob_mass = Lobster, urc_mass = Urchin, urc_density = 1, lob_density = 1,
                           beta1a. = 0.75, 
                           beta2a. = 0.75, 
                           beta1h. = -0.75, 
                           beta2h. = 0.5, 
                           h0. = 0.1, 
                           a0. = -1))


medians <- simu2 %>% group_by(scenario) %>% summarize(median = median(IS, na.rm = T)) %>%
  select(median)
medians <- as.vector(medians$median)

thirdrow <- ggplot()+
  geom_density(data = simu2, aes(x = IS, fill = scenario),adjust = 2, alpha = 0.75, show.legend = F)+
  scale_fill_manual(values = c("#31a354", "#e5f5e0", "#a1d99b"))+
  labs(y = "Density", x = "Interaction strength")+
  theme_bd()+
  theme(axis.ticks.x = element_blank(),
        axis.text.x = element_blank(), 
        panel.border = element_rect(fill = NA))

allthree <- cowplot::plot_grid(toprow, b1 + theme(legend.position = "none"), thirdrow, nrow = 3)

ggsave("figures/figure1_allthree.svg", plot = allthree, device = "svg", height = 10, width = 8.5)
ggsave("figures/figure1_allthree.png", plot = allthree, device = "png", height = 10, width = 8.5)







