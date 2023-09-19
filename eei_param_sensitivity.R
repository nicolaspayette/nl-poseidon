library(tidyverse)
library(here)
library(janitor)
library(showtext)
library(scales)

showtext_auto()

font_add(
  family = "Foundry Sterling",
  regular = fs::path_home(".local", "share", "fonts", "FoundrySterling-Book.otf")
)

oxford_blue <- "#002147"

df_values <-
  here("eei_params.finalCheckedBests.csv") %>%
  read_csv() %>%
  clean_names() %>%
  filter(best_fitness_rechecked == max(best_fitness_rechecked))

df_prob <-
  here("exploration-prob.csv") %>%
  read_csv(skip = 6) %>%
  clean_names()

df_prob %>%
  ggplot(aes(exploration_probability, mean_bank_balance_of_fishers)) +
  geom_vline(xintercept = df_values$exploration_probability, linetype = "dashed") +
  geom_point(alpha = 0.25, colour = oxford_blue) +
  theme_minimal(base_family = "Foundry Sterling") +
  scale_y_continuous(labels = label_number(scale_cut = cut_short_scale())) +
  labs(
    y = "Mean bank balance",
    x = "Exploration probability"
  )

ggsave(here("slides_behave", "images", "exploration_prob.pdf"), width = 4, height = 3)

df_radius <-
  here("exploration-radius.csv") %>%
  read_csv(skip = 6) %>%
  clean_names()

df_radius %>%
  ggplot(aes(exploration_radius, mean_bank_balance_of_fishers)) +
  geom_vline(xintercept = df_values$exploration_radius, linetype = "dashed") +
  geom_point(alpha = 0.25, colour = oxford_blue) +
  theme_minimal(base_family = "Foundry Sterling") +
  scale_y_continuous(labels = label_number(scale_cut = cut_short_scale())) +
  labs(
    y = "Mean bank balance",
    x = "Exploration radius"
  )

ggsave(here("slides_behave", "images", "exploration_radius.pdf"), width = 4, height = 3)
