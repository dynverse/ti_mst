library(jsonlite)
library(readr)
library(dplyr)
library(purrr)

library(dyndimred)
library(mclust)
requireNamespace("igraph")

#   ____________________________________________________________________________
#   Load data                                                               ####

data <- read_rds("/ti/input/data.rds")
params <- jsonlite::read_json("/ti/input/params.json")

#   ____________________________________________________________________________
#   Infer trajectory                                                        ####

expression <- data$expression

# TIMING: done with preproc
checkpoints <- list(method_afterpreproc = as.numeric(Sys.time()))

# infer dimred
space <- dyndimred::dimred(expression, method = params$dimred, ndim = params$ndim)

# cluster cells
clust <- mclust::Mclust(space, modelNames = "EEV", G = 5:15)

centers <- t(clust$parameters$mean)

milestone_ids <- paste0("M", seq_len(nrow(centers)))
rownames(centers) <- milestone_ids

# convert distance to similarity
dis <- as.matrix(dist(centers))
rownames(dis) <- colnames(dis) <- milestone_ids

disdf <- dis %>% 
  reshape2::melt(varnames = c("from", "to"), value.name = "weight") %>% 
  na.omit()

# calculate mst
gr <- igraph::graph_from_data_frame(disdf, directed = FALSE, vertices = milestone_ids)
mst <- igraph::minimum.spanning.tree(gr, weights = igraph::E(gr)$weight)

milestone_network <- 
  igraph::as_data_frame(mst) %>% 
  transmute(from, to, length = weight, directed = FALSE)

# TIMING: done with method
checkpoints$method_aftermethod <- as.numeric(Sys.time())

# return output
output <- lst(
  cell_ids = rownames(expression),
  milestone_ids,
  milestone_network,
  dimred_milestones = centers,
  dimred = space,
  timings = checkpoints
)

#   ____________________________________________________________________________
#   Save output                                                             ####

write_rds(output, "/ti/output/output.rds")
