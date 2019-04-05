#!/usr/local/bin/Rscript

task <- dyncli::main()

library(dplyr, warn.conflicts = FALSE)
library(purrr, warn.conflicts = FALSE)
library(dynwrap, warn.conflicts = FALSE)
library(dyndimred, warn.conflicts = FALSE)
library(mclust, warn.conflicts = FALSE)
requireNamespace("igraph")

#   ____________________________________________________________________________
#   Load data                                                               ####

expression <- task$expression
parameters <- task$parameters

#   ____________________________________________________________________________
#   Infer trajectory                                                        ####


# TIMING: done with preproc
checkpoints <- list(method_afterpreproc = as.numeric(Sys.time()))

# infer dimred
space <- dyndimred::dimred(expression, method = parameters$dimred, ndim = parameters$ndim)

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

output <- dynwrap::wrap_data(cell_ids = rownames(expression)) %>%
  dynwrap::add_dimred_projection(
    milestone_ids = milestone_ids,
    milestone_network = milestone_network,
    dimred = space,
    dimred_milestones = centers
  ) %>%
  dynwrap::add_timings(checkpoints)

dyncli::write_output(output, task$output)
