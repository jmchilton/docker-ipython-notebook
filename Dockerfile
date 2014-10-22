FROM debian:wheezy
MAINTAINER Bjoern Gruening <bjoern.gruening@gmail.com>

# Install all requirements and clean up afterwards
RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y libzmq1 libzmq-dev python-dev libc-dev pandoc python-pip
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y build-essential libblas-dev liblapack-dev gfortran
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y libfreetype6-dev libpng-dev net-tools procps cron
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y r-base
RUN pip install pyzmq ipython==2.2 jinja2 tornado pygments
RUN pip install distribute --upgrade
RUN pip install numpy biopython scikit-learn pandas scipy sklearn-pandas bioblend matplotlib
RUN pip install patsy
RUN pip install pysam khmer dendropy ggplot mpld3 sympy
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y libreadline-dev

RUN echo "deb http://cran.revolutionanalytics.com/bin/linux/debian wheezy-cran3/" >> /etc/apt/sources.list
RUN gpg --keyserver pgp.mit.edu --recv-key 381BA480 && gpg -a --export 381BA480 > jranke_cran.asc && apt-key add jranke_cran.asc
RUN DEBIAN_FRONTEND=noninteractive apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y r-base
RUN pip install rpy2
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y libxml2-dev libcurl4-openssl-dev
RUN echo ' \
    update.packages(checkBuilt = TRUE, ask = FALSE, repos="http://cran.rstudio.com/"); \
    source("http://bioconductor.org/biocLite.R"); \
    install.packages("dplyr", repos="http://cran.rstudio.com/"); \
    install.packages("knitr", repos="http://cran.rstudio.com/"); \
    install.packages("reshape2", repos="http://cran.rstudio.com/"); \
' | R --vanilla
RUN echo ' \
    source("http://bioconductor.org/biocLite.R"); \
    biocLite("cummeRbund"); \
    ' | R --vanilla
RUN pip install --upgrade bioblend
RUN DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge libzmq-dev python-dev libc-dev build-essential binutils gfortran
RUN DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
RUN DEBIAN_FRONTEND=noninteractive apt-get clean -y && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ADD ./monitor_traffic.sh /monitor_traffic.sh
RUN chmod +x /monitor_traffic.sh
RUN echo "* *     * * *   root    /monitor_traffic.sh" >> /etc/crontab

# /import will be the universal mount-point for IPython
# The Galaxy instance can copy in data that needs to be present to the IPython webserver
RUN mkdir /import
VOLUME ["/import/"]
WORKDIR /import/

# Add python module to a special folder for modules we want to be able to load within IPython
RUN mkdir /py/
ADD ./galaxy.py /py/galaxy.py
# Make sure the system is aware that it can look for python code here
ENV PYTHONPATH /py/

# Install MathJax locally because it has some problems with https as reported here: https://github.com/bgruening/galaxy-ipython/pull/8
RUN python -c 'from IPython.external import mathjax; mathjax.install_mathjax("2.4.0")'

# We can get away with just creating this single file and IPython will create the rest of the
# profile for us.
RUN mkdir -p /.ipython/profile_default/startup/
RUN mkdir -p /.ipython/profile_default/static/custom/
# These imports are done for every open IPython console
ADD ./ipython-profile.py /.ipython/profile_default/startup/00-load.py
ADD ./ipython_notebook_config.py /.ipython/profile_default/ipython_notebook_config.py
ADD ./custom.js /.ipython/profile_default/static/custom/custom.js
ADD ./custom.css /.ipython/profile_default/static/custom/custom.css

ADD ./startup.sh /startup.sh
RUN chmod +x /startup.sh

# IPython will run on port 6789, export this port to the host system
EXPOSE 6789

# Start IPython Notebook
CMD /startup.sh
