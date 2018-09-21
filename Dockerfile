FROM dynverse/dynwrap:r

RUN R -e 'devtools::install_cran("igraph")'

RUN R -e 'devtools::install_cran("mclust")'

LABEL version 0.1.3

ADD . /code

ENTRYPOINT Rscript /code/run.R
