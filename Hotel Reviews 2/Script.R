source("Settings.R")
source("Tools.R")
source("Mongo.R")
list.of.packages <- c("tibble", "magrittr", "dplyr",
                      "sparklyr", "shiny", "leaflet",
                      "keras", "tm", "ffbase")

Require.packages(list.of.packages)

path = paste0("R -e \"shiny::runApp(\'", getwd(), "/shiny\', launch.browser = TRUE)\"")
print(paste0("use the following command to start shiny: ", path))

if (!file.exists(fn.mixed.reviews)) {
    hotel.reviews <- hotel.reviews.collection$find();

    if (!exists(hotel.reviews)) {
        hotel.reviews.raw <- read.csv2(file = fn.hotel.reviews,
                                           header = TRUE,
                                           quote = "\"",
                                           dec = ".",
                                           sep = ","
                                           )
        hotel.reviews.collection$insert(hotel.reviews.raw)
        rm(hotel.reviews.raw)
    }

    if (!file.exists(fn.positive.reviews)) {
        hotel.reviews.positive <- getPositiveReviews(numReviewsToDl);
        write.csv2.ffdf(hotel.reviews.positive, file = fn.positive.reviews)
    }

    if (!file.exists(fn.negative.reviews)) {
        hotel.reviews.negative <- getNegativeReviews(numReviewsToDl);
        write.csv2.ffdf(hotel.reviews.negative, file = fn.negative.reviews)
    }
}

if (file.exists(fn.mixed.reviews)) {
    print("Reviews file already exists. reusing!")
    reviews.mixed <- read.csv2.ffdf(file = fn.mixed.reviews)
    #reviews.mixed <- read.csv2(fn.mixed.reviews)
} else {
    hotel.reviews.positive <- read.csv2.ffdf(file = fn.positive.reviews, sep = ";")
    hotel.reviews.negative <- read.csv2.ffdf(file = fn.negative.reviews, sep = ";")

    reviews.mixed <- ffdfappend(hotel.reviews.positive, hotel.reviews.negative, adjustvmode = F)
    write.csv2.ffdf(reviews.mixed, file = fn.mixed.reviews)

    rm(hotel.reviews.negative)
    rm(hotel.reviews.positive)
}
        
print(paste0("Total number of reviews: ", nrow(reviews.mixed)))
print(paste0("number of positive reviews: ", nrow(reviews.mixed[ffwhich(reviews.mixed, reviews.mixed$Review_Is_Positive == 1),])))
print(paste0("number of negative reviews: ", nrow(reviews.mixed[ffwhich(reviews.mixed, reviews.mixed$Review_Is_Positive == 0),])))
                                 
#randomize the order 
data <- as.ffdf(reviews.mixed[sample(nrow(reviews.mixed)),])
rm(reviews.mixed)
train_size = nrow(data)
#train_size =  floor(nrow(data) * 0.90)

tokenizer <- text_tokenizer(num_words = vocab_size)

#grab the posts and set them as x-param
train_posts = data[1:train_size, 2]

tokenizer %<>% fit_text_tokenizer(train_posts)

# make a matrix
x_train = texts_to_matrix(tokenizer, train_posts, mode = 'tfidf')
rm(train_posts)

#grab the tags and set them as y-param
train_tags = data[1:train_size, 1]
y_train = to_categorical(train_tags)
rm(train_tags) 

#define the keras model 
model <- keras_model_sequential()

# softmax is used for multiclass logistic regression, 
# sigmoid is used for two-class logistic regression
# we use binary classification, therefore a rectified linear unit is used
#Dropout consists in randomly setting a fraction rate of input units to 0 at each update during training time, which helps prevent overfitting.
# returns max(x,0)
model %>%
    layer_dense(units = batch_size, input_shape = c(vocab_size), activation = 'relu') %>%
    layer_dropout(rate = 0.4) %>%
    layer_dense(units = (batch_size / 2), activation = "relu") %>%
    layer_dropout(rate = 0.2) %>%
    layer_dense(units = (batch_size / 4), activation = 'relu') %>%
    layer_dense(units = 2, activation = 'sigmoid')

# actually make the model
# use categorical_Crossentropy for multi-class logistic regression
# use binary_crossentropy for two-class logistic regression
model %>% compile(loss = 'binary_crossentropy',
                  optimizer = 'nadam',
                  metrics = c('accuracy'))

#train the model on our training dataset
history <- model %>% fit(x_train,
                         y_train,
                         batch_size = batch_size,
                         epochs = 2,
                         verbose = 1,
                         validation_split = 0.25)

#get some basic info about the model
summary(model)
plot(history)

#get rid of the training parameters
rm(x_train)
rm(y_train)

#predict new things
verify_post <- c("this hotel was very nice", "the waiter was bad and my bathroom was leaky")
x_verify = texts_to_matrix(tokenizer, verify_post, mode = 'tfidf')


prediction <- model %>% predict_classes(x_verify)
prediction