# https://mcr.microsoft.com/en-us/product/devcontainers/base/about
FROM mcr.microsoft.com/devcontainers/base:dev-ubuntu-24.04

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt update && \
    apt install -y \
      sudo \
      locales \
      net-tools \
      iputils-ping \
      dnsutils \
      bash-completion \
      less \
      curl \
      wget \
      tar \
      xz-utils \
      unzip \
      make \
      gcc \
      git \
      vim \
      tmux \
      jq \
      fzf \
      groff \
      procps \
      python3.12 \
      postgresql-client-16 \
      redis-tools

# ロケール設定
RUN echo 'ja_JP.UTF-8 UTF-8' >> /etc/locale.gen && \
    locale-gen && \
    update-locale LANG=ja_JP.UTF-8
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# terraform インストール
# https://developer.hashicorp.com/terraform/install
ENV TERRAFORM_VERSION=1.13.3
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
mv terraform /usr/local/bin/ && \
terraform -install-autocomplete

# aws cli インストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# uv をグローバルにインストール
RUN curl -LsSf https://astral.sh/uv/install.sh \
  | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh

ENV UV_PROJECT_ENVIRONMENT="/workspaces/datastreamer/.venv"