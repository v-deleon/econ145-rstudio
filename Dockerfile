ARG BASE_IMAGE=jupyter/r-notebook:r-4.1.0
FROM $BASE_IMAGE

USER root

ENV PATH=$PATH:/usr/lib/rstudio-server/bin \
    R_HOME=/opt/conda/lib/R \
    RSESSION_PROXY_RSTUDIO_1_4=yes
ARG LITTLER=$R_HOME/library/littler

RUN \
    # download R studio
    curl --silent -L --fail https://download2.rstudio.org/server/bionic/amd64/rstudio-server-1.4.1717-amd64.deb > /tmp/rstudio.deb && \
    echo '7a125b0715ee38e00e5732fd3306ce15 /tmp/rstudio.deb' | md5sum -c - && \
    \
    # install R studio
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/rstudio.deb && \
    rm /tmp/rstudio.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    \
    # setting default CRAN mirror
    echo -e "local({ \n" \
         "   r <- getOption('repos')\n" \
         "   r['CRAN'] <- 'https://cloud.r-project.org'\n" \
         "   options(repos = r)\n" \
         "})\n" > $R_HOME/etc/Rprofile.site && \
    \
    # littler provides install2.r script
    R -e "install.packages(c('littler', 'docopt'))" && \
    \
    # modifying littler scripts to conda R location
    sed -i 's/\/usr\/local\/lib\/R\/site-library/\/opt\/conda\/lib\/R\/library/g' \
        ${LITTLER}/examples/*.r && \
	ln -s ${LITTLER}/bin/r ${LITTLER}/examples/*.r /usr/local/bin/ && \
	echo "$R_HOME/lib" | sudo tee -a /etc/ld.so.conf.d/littler.conf && \
	ldconfig
    
USER $NB_USER

RUN pip install nbgitpuller okpy && \
    pip install git+https://github.com/okpy/jassign.git && \
    pip install jupyter-server-proxy jupyter-rsession-proxy 
USER $NB_USER

# REmoving some packages that are probably duplicated
RUN R -e "install.packages(c('rsf', 'runit', 'rstan', 'udunits2', 'tidylog', 'tidytuesdayR', 'janitor', 'readxl', 'lubridate', 'lucid', 'magrittr', 'learnr', 'haven', 'summarytools', 'ggplot2', 'kableExtra', 'flextable', 'sandwich', 'sf', 'stargazer', 'viridis', 'titanic', 'labelled', 'Lahman', 'babynames', 'nasaweather', 'fueleconomy', 'mapproj', 'forcats', 'rvest', 'readxl', 'quantmod', 'polite', 'pdftools', 'ncdf4', 'modelsummary', 'maps', 'magrittr', 'lmtest', 'knitr', 'anytime', 'broom', 'devtools', 'fixest', 'ggmap', 'ggthemes', 'httr', 'jsonlite', 'kableExtra'), repos = 'http://cran.us.r-project.org')"
RUN conda install -c conda-forge udunits2 libv8 r-rstan imagemagick

RUN R --quiet -e "devtools::install_github('UrbanInstitute/urbnmapr', dep=FALSE)"
RUN R --quiet -e "devtools::install_github('Rapporter/pander')"

# remove cache
RUN rm -rf ~/.cache/pip ~/.cache/matplotlib ~/.cache/yarn && \
    conda clean --all -f -y && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER