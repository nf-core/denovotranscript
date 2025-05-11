FROM ubuntu:20.04

# Using conda or the biocontainer for transrate results in a SNAP index error.
# However, the error does not occur when using the tarball from the Oyster River Protocol.
# see https://github.com/blahah/transrate/issues/248
LABEL description="Transrate from the Oyster River Protocol."

# Set environment variable to avoid user interaction during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update the package list and install required tools
RUN apt-get update && apt-get install -y \
    wget \
    tar \
    build-essential \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /opt

# Install BLAST+
RUN wget https://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.2.31/ncbi-blast-2.2.31+-x64-linux.tar.gz && \
    tar zxvf ncbi-blast-2.2.31+-x64-linux.tar.gz && \
    cp ncbi-blast-2.2.31+/bin/* /usr/local/bin/ && \
    rm -rf ncbi-blast-2.2.31+ ncbi-blast-2.2.31+-x64-linux.tar.gz

# Download the tarball
RUN wget https://github.com/macmanes-lab/Oyster_River_Protocol/raw/master/software/orp-transrate.tar.gz -O orp-transrate.tar.gz

# Extract the tarball
RUN tar -xzvf orp-transrate.tar.gz

# Remove the tarball to save space
RUN rm orp-transrate.tar.gz

# Add orp-transrate directory to PATH
ENV PATH="/opt/orp-transrate:${PATH}"

# Set working directory
WORKDIR /opt/orp-transrate
