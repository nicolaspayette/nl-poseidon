library(tidyverse)
library(here)
library(showtext)
showtext_auto()

p <- 1
t <- 1
r <- 0.9
k <- 5000
y <- 1:32
while (p < 5000) {
  p <- p + p * r * (1 - (p / k))
  t <- t + 1
  y[t] <- p
}

ggplot(tibble(x = 1:32, y = y), aes(x, y)) +
  geom_line(size = 1.5, alpha = 0.75, color = rgb(0,0.33,0.71)) +
  theme_minimal(base_family = "FoundrySterling") +
  labs(
    y = "Biomass",
    x = "Time"
  )

ggsave(here("slides", "images", "logistic_growth.pdf"), width = 6, height = 2.25)
