# === Stage 1 - Build python project ===========================================
FROM debian:buster AS builder

# --- Metadata ---
# Container Metadatas
LABEL MANTAINER="Bezunca <bezuncainvestimentos@gmail.com>"

# --- Environment Variables ---
# Don't allow APT to make question
ENV DEBIAN_FRONTEND=noninteractive

# --- System Dependencies ---
# Add APT config file
ADD "https://gist.githubusercontent.com/HeavenVolkoff/ff7b77b9087f956b8df944772e93c071/raw" /etc/apt/apt.conf.d/99custom
# Update packages
RUN apt-get update -qq
# install development base packages
RUN apt-get install -qq build-essential
# Install docker requirements
RUN apt-get install -qq \
    tar \
    git \
    ssh \
    zstd \
    curl

# --- Add SSH Key ---
# Build argument. Content of the ssh key.
ARG SSH_KEY
# Build argument. Link for the tar file containing the git ssh key.
ARG SSH_KEY_LINK

# Ensure at least one of the above build argument is provided and get SSH keys
RUN if [ -n "$SSH_KEY_LINK" ]; then \
        if ! ( curl -k -# -L ${SSH_KEY_LINK} | tar -C /root -x ); then \
            echo "Failed to download ssh key from: ${SSH_KEY_LINK}"; \
            exit 1; \
        fi; \
    elif [ -n "$SSH_KEY" ]; then \
        if ! ( mkdir -p ~/.ssh && echo "$SSH_KEY" | tr -d '\r' > ~/.ssh/id_rsa ); then \
            echo "Failed to create ssh key"; \
            exit 1; \
        fi; \
    else \
        echo "You must provide SSH_KEY_LINK or SSH_KEY"; \
        exit 1; \
    fi

# Acknowledge remote server
RUN ssh-keyscan -p 22 gitlab.com > ~/.ssh/known_hosts

# Fix ssh key permissions
RUN  chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/known_hosts

# --- Project Installation ---
# Create python directory
WORKDIR /opt

# Download python
RUN curl -L# \
    https://github.com/indygreg/python-build-standalone/releases/download/20200517/cpython-3.8.3-x86_64-unknown-linux-gnu-pgo-20200518T0040.tar.zst \
    | tar -ax --zstd --strip-components 2 -f - python/install

# Fix python executables shebang
RUN find bin/ -type f -exec sed -i '1 s/^#!.*python.*/#!\/opt\/bin\/python3/' {} \;

# Ensure basic dependencies are installed
RUN curl -L# "https://bootstrap.pypa.io/get-pip.py" \
        | bin/python3 - -U --ignore-installed

# Create build directory
WORKDIR /src

# Copy project files
COPY . .

# Install project setup requirements
RUN curl -# -L "https://raw.githubusercontent.com/HeavenVolkoff/format.sh/master/read_config.py" \
        | /opt/bin/python3 - setup.cfg options setup_requires \
        | sed -e '/^$/d' -e 's/.*/"&"/' \
        | xargs -r /opt/bin/pip install -U --ignore-installed

# Install project and it's dependecies
RUN /opt/bin/pip install -U .

# Fix python executables shebang
RUN find /opt/bin -type f -exec sed -i '1 s/^#!.*python.*/#!\/usr\/local\/bin\/python3/' {} \;

# Remove any pre-compiled file from venv
RUN find -type d -name "__pycache__" -print0 | xargs -r -0 rm -r

# === Stage 2 - Setup runtime ==================================================
FROM debian:buster-slim

# Build arguments
ARG USERNAME="bezunca"

# Environment Variables
# Don't allow APT to make question
ENV DEBIAN_FRONTEND=noninteractive

# Copy APT custom config
COPY --from=builder /etc/apt/apt.conf.d/99custom /etc/apt/apt.conf.d/99custom

# Update APT
RUN apt-get update -qq \
    && \
    # Clear APT cache
    apt-get clean \
    && \
    # Clear APT list
    rm -rf /var/lib/apt/lists/* \
    && \
    # Remove custom APT config
    rm /etc/apt/apt.conf.d/99custom

# Copy project and python
COPY --from=builder /opt /usr/local/

# Fix permissions and create unprivileged user
RUN useradd -b /home -s /bin/sh -u 1001 -g 65534 ${USERNAME} \
    && \
    # Setup data volumes directories
    install -g 65534 -o 1001 -d /home/${USERNAME}/logs \
    && \
    # Remove setuid and setgid permissions
    find / -perm /6000 -type f -exec chmod a-s {} \; || true

# Setup runtime
USER ${USERNAME}
VOLUME /home/${USERNAME}/logs
WORKDIR /home/${USERNAME}

# Run application
CMD ["data_baker"]
