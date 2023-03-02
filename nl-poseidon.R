library(tidyverse)
library(here)
library(janitor)
library(scales)
library(ggrepel)
library(vroom)

library(showtext)
showtext_auto()

df <-
  vroom(here("data", "nl-poseidon experiment-table.csv"), skip = 6) %>%
  clean_names() %>%
  mutate(
    mpa_border = as_factor(mpa_border),
    year = step / 365
  ) %>%
  group_by(
    mpa_border,
    step,
    year
  ) %>%
  summarise(
    mean_earnings = mean(mean_bank_balance_of_fishers),
    mean_biomass = mean(mean_biomass_of_patches),
    .groups = "drop"
  )

glimpse(df)

g <- list(
  scale_fill_viridis_d(option = "inferno", end = 0.75),
  scale_color_viridis_d(option = "inferno", end = 0.75),
  scale_y_continuous(labels = scales::label_number_si()),
  theme_minimal(base_family = "FoundrySterling")
)

df %>%
  ggplot(aes(year, mean_earnings, group = mpa_border)) +
  g +
  geom_line(
    aes(color = mpa_border),
    size = 1.5,
    alpha = 0.75
  ) +
  geom_point(
    data = filter(df, step == max(step)),
    aes(color = mpa_border)
  ) +
  geom_text_repel(
    data = filter(df, step == max(step)),
    aes(label = mpa_border),
    min.segment.length = 0
  ) +
  labs(
    title = "Mean fisher earnings over time",
    x = "Year",
    y = "Earnings (£)",
    colour = "MPA border"
  )

ggsave(here("slides", "images", "earnings.pdf"), width = 8, height = 4.5)


df %>%
  ggplot(aes(year, mean_biomass, group = mpa_border)) +
  g +
  geom_line(
    aes(color = mpa_border),
    size = 1.5,
    alpha = 0.75
  ) +
  labs(
    title = "Biomass per cell over time",
    x = "Year",
    y = "Biomass (t)",
    colour = "MPA border"
  )

ggsave(here("slides", "images", "biomass.pdf"), width = 8, height = 4.5)

df %>%
  filter(step %in% (c(10, 25, 50) * 365)) %>%
  ggplot(aes(mean_biomass, mean_earnings)) +
  g +
  facet_wrap(~year, labeller = label_both) +
  geom_point(
    aes(fill = mpa_border),
    size = 6,
    alpha = 0.75,
    shape = 21
  ) +
  labs(
    title = "Biomass/earnings trade-off",
    y = "Earnings (£)",
    x = "Biomass (t)",
    fill = "MPA border"
  ) +
  geom_text(aes(label = mpa_border))


ggsave(here("slides", "images", "tradeoff.pdf"), width = 8, height = 4.5)
