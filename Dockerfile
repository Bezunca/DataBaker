# === Stage 1 - Build python project ===========================================
FROM python:3.8-buster AS builder

# Container Metadatas
LABEL MANTAINER="Bezunca <bezuncainvestimentos@gmail.com>"

# --- Environment Variables ---
# Don't allow APT to make question
ENV DEBIAN_FRONTEND=noninteractive

# Add APT config file
ADD "https://gist.githubusercontent.com/HeavenVolkoff/ff7b77b9087f956b8df944772e93c071/raw" /etc/apt/apt.conf.d/99custom

# Update APT
RUN apt-get update -qq \
    && \
    # Install build requirements
    apt-get install \
        git \
        ssh \
        curl \
        build-essential

# Create build directory
WORKDIR /src/proj

# Setup venv
RUN python -m venv --symlinks --clear .venv

###################################### SSH KEY HANDLE ########################################
## Build argument. Link for the tar file containing the git ssh key.
ARG SSH_KEY_LINK
ARG SSH_KEY
# Ensure SSH_KEY_LINK link is not empty
RUN test -n "$SSH_KEY_LINK" || test -n "$SSH_KEY" || ( echo "You must provide SSH_KEY_LINK or SSH_KEY" && exit 1 )

# Get SSH keys
RUN test -n "$SSH_KEY_LINK" &&  ( curl -k -# -L ${SSH_KEY_LINK} | tar -C /root -x || exit 1 ) || true

RUN test -n "$SSH_KEY" \
    && ( \
        mkdir -p ~/.ssh \
        && \
        chmod 700 ~/.ssh \
        && \
        echo "$SSH_KEY" | tr -d '\r' > ~/.ssh/id_rsa \
        && \
        chmod 600 ~/.ssh/id_rsa \
     ) || true

RUN ssh-keyscan -p 22 gitlab.com > ~/.ssh/known_hosts \
    && \
    chmod 644 ~/.ssh/known_hosts
##############################################################################################


# Copy project sources
COPY . .

# Activate venv
RUN . .venv/bin/activate \
    && \
    # Install project setup_requires
    curl -# -L "https://raw.githubusercontent.com/HeavenVolkoff/format.sh/master/read_config.py" \
        | python - setup.cfg options setup_requires \
        | sed -e '/^$/d' -e 's/.*/"&"/' \
        | xargs -r pip install --no-cache -U \
    && \
    # Install project dependecies
    GIT_SSL_NO_VERIFY=true pip install --no-cache -U .

# Clean up .venv for copy
WORKDIR /src/proj/.venv

# Remove all pip pre-installed packages
RUN find ./bin -type f -exec sed -i -E 's@^#\!/src/proj/.venv/bin/python@#\!/usr/local/bin/python@' {} \;

# === Stage 2 - Setup runtime ==================================================
FROM python:3.8-slim-buster

# Build arguments
ARG USERNAME="exyon"

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
    rm /etc/apt/apt.conf.d/99custom \
    && \
    # Remove all pip pre-installed packages
    pip freeze --all | xargs -r pip uninstall -y \
    && \
    # Remove any python pre-compiled scripts
    find /usr/local/lib/ -type d -wholename "*/site-packages/__pycache__" -print0 \
        | xargs -r -0 rm -r

# Copy project data
COPY --from=builder /src/proj/.venv /usr/local/

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
