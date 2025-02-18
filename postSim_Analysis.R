library(terra)   # For spatial operations
library(ggplot2) # For plotting
library(dplyr)   # For data manipulation
library(tidyr)   # For data reshaping
NumberOfSpecies <- unique(outSim$cohortData$species)
terra::plot(outSim$burnMap, main = "post simulation cumulative burn", .png)
terra::plot(outSim$burnMap, main = "post simulation cumulative burn", .tif)

# Plotting the cumulative burn map over time
terra::plot(outSim$burnMap, main = "Post-Simulation Cumulative Burn")

# Save to PNG
png("cumulative_burn_map.png")
terra::plot(outSim$burnMap, main = "Post-Simulation Cumulative Burn")
dev.off()  # Close the plotting device

# Extract unique species
species <- unique(outSim$cohortData$species)

# Create a dataframe for species presence across time
species_presence <- data.frame(time = outSim$times)

for (spec in species) {
  species_presence[[spec]] <- ifelse(spec %in% outSim$cohortData$species, 1, 0)  # Binary presence (1 = present, 0 = absent)
}

# Visualize species presence over time
ggplot(species_presence, aes(x = time)) +
  geom_line(aes(y = `SpeciesName`, color = "SpeciesName")) + # Replace `SpeciesName` with actual species
  labs(title = "Species Presence Over Time", x = "Time", y = "Presence") +
  theme_minimal()

# Save the plot to PNG
ggsave("species_presence_over_time.png")

# Assume species abundance is available in 'cohortData'
abundance_data <- outSim$cohortData %>%
  group_by(species) %>%
  summarise(abundance = sum(abundance))  # Adjust this based on how abundance is stored

# Plot the relative abundance
ggplot(abundance_data, aes(x = species, y = abundance, fill = species)) +
  geom_bar(stat = "identity") +
  labs(title = "Species Relative Abundance", x = "Species", y = "Abundance") +
  theme_minimal()

# Save the plot
ggsave("species_relative_abundance.png")

# Create a dataframe to track the dominance of each species
dominance_data <- species_presence %>%
  gather(species, presence, -time) %>%
  group_by(species) %>%
  summarise(disappearance_rate = sum(presence == 0) / n())  # Calculate disappearance rate

# Evaluate dominance (species with higher abundance)
dominance_data %>%
  ggplot(aes(x = species, y = disappearance_rate, fill = species)) +
  geom_bar(stat = "identity") +
  labs(title = "Species Disappearance Rate", x = "Species", y = "Disappearance Rate") +
  theme_minimal()

# Save the plot
ggsave("species_disappearance_rate.png")

# Save the species presence table to CSV
write.csv(species_presence, "species_presence.csv")

# Save dominance and disappearance rates to CSV
write.csv(dominance_data, "species_dominance.csv")
# Assuming 'lakey_region' and 'not_lakey_region' are available as spatial polygons
lakey_species <- extract(outSim$cohortData, lakey_region)
not_lakey_species <- extract(outSim$cohortData, not_lakey_region)

# Compare species in both regions
lakey_abundance <- table(lakey_species$species)
not_lakey_abundance <- table(not_lakey_species$species)

# Plot the results
df_abundance <- data.frame(
  Region = rep(c("Lakey", "Not-Lakey"), each = length(lakey_abundance)),
  Species = c(names(lakey_abundance), names(not_lakey_abundance)),
  Abundance = c(lakey_abundance, not_lakey_abundance)
)

ggplot(df_abundance, aes(x = Species, y = Abundance, fill = Region)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Species Abundance: Lakey vs Not-Lakey", x = "Species", y = "Abundance") +
  theme_minimal()

# Save the plot
ggsave("species_abundance_lakey_notlakey.png")
