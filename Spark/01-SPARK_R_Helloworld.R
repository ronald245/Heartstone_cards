## http://spark.rstudio.com/
## https://www.rstudio.com/resources/cheatsheets/

install.packages("sparklyr")
#install.packages(c("nycflights13", "Lahman"))
library(sparklyr)
library(dplyr)
library(ggplot2)
library(DBI)


spark_install(version="2.0.0")
sc <- spark_connect(master = "local", version="2.0.0")

db_drop_table(sc, "iris")
iris_tbl <- copy_to(sc, iris)

src_tbls(sc)




iris_preview <- dbGetQuery(sc, "SELECT * FROM iris LIMIT 10")
iris_preview


# copy mtcars into spark
mtcars_tbl <- copy_to(sc, mtcars)

# transform our data set, and then partition into 'training', 'test'
partitions <- mtcars_tbl %>%
  filter(hp >= 100) %>%
  mutate(cyl8 = cyl == 8) %>%
  sdf_partition(training = 0.5, test = 0.5, seed = 1099)

# fit a linear model to the training dataset
model <- partitions$training %>%
  ml_linear_regression(response = "mpg", features = c("wt", "cyl"))

model
summary(model)

# Score the data
pred <- ml_predict(model, partitions$test) %>%
  collect

# Plot the predicted versus actual mpg
ggplot(pred, aes(x = mpg, y = prediction)) +
  geom_abline(lty = "dashed", col = "red") +
  geom_point() +
  theme(plot.title = element_text(hjust = 0.5)) +
  coord_fixed(ratio = 1) +
  labs(
    x = "Actual Fuel Consumption",
    y = "Predicted Fuel Consumption",
    title = "Predicted vs. Actual Fuel Consumption"
  )

spark_disconnect(sc)
