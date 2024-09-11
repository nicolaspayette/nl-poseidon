library(tidyverse)
library(here)
library(showtext)
library(scales)

showtext_auto()

font_add(
  family = "Foundry Sterling",
  regular = fs::path_home(".local", "share", "fonts", "FoundrySterling-Book.otf")
)

oxford_blue <- "#002147"

here("goodness-of-fit.csv") %>%
  read_csv() %>%
  ggplot(aes(balance)) +
  geom_histogram(alpha = 0.75, colour = oxford_blue, binwidth = 5000) +
  geom_vline(xintercept = 775000, linetype = "dashed") +
  theme_minimal(base_family = "Foundry Sterling") +
  scale_y_continuous(labels = label_number(scale_cut = cut_short_scale())) +
  scale_x_continuous(labels = label_number(scale_cut = cut_short_scale())) +
  labs(
    x = "Mean bank balance",
    y = "Number of runs"
  )

ggsave(here("slides_behave", "images", "goodness_of_fit.pdf"), width = 4, height = 3)
