# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development.
# ビルドの文脈はリポジトリの直下 (backend と frontend の両方を使うため。Issue #145):
# docker build -f backend/Dockerfile -t trip-diary .
# docker run -p 10000:10000 -e SECRET_KEY_BASE=<値> -e JWT_SECRET=<値> -e DB_HOST=<値> ... trip-diary

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.9
ARG NODE_VERSION=24.16.0
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl default-mysql-client libjemalloc2 libvips && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# 画面 (Nuxt) をビルドする段 (Issue #145)。出力は下の build の段で Rails に渡す。
FROM docker.io/library/node:$NODE_VERSION-slim AS frontend
WORKDIR /frontend
COPY frontend/ ./
RUN npm ci

# ビルドの時にしか効かない値。Render のサービスの環境変数で上書きできる。
ARG NUXT_PUBLIC_API_BASE=/api/v1
ARG NUXT_PUBLIC_SIGNUP_ENABLED=false
RUN npx nuxi generate

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential default-libmysqlclient-dev git libvips libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY backend/vendor/* ./vendor/
COPY backend/Gemfile backend/Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY backend/ .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# ビルド済みの画面を配る (Issue #145)。JS と CSS (_nuxt) は public へ、画面のひな形は public の外へ置く。
# public のファイルは 1 年キャッシュされるので、ひな形を置くと公開し直しても古い画面が読まれ続ける。
# frontend/public にファイルを足したときは、ここにも COPY を足す。
COPY --from=frontend /frontend/.output/public/_nuxt ./public/_nuxt/
COPY --from=frontend /frontend/.output/public/index.html ./frontend_shell/index.html
RUN mkdir -p log storage tmp/pids




# Final stage for app image
FROM base

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime.
# thrust が HTTP_PORT (10000) で受け、Puma を TARGET_PORT (3001) で起動する (Issue #145)。
# thrust は Puma の PORT を TARGET_PORT の値で上書きするので、Render が渡す PORT (10000) は Puma に届かない。
# どちらも 1024 より大きいので、root でないコンテナでも待ち受けられる (Issue #61)。
ENV HTTP_PORT="10000"
ENV TARGET_PORT="3001"
EXPOSE 10000
CMD ["./bin/thrust", "./bin/rails", "server"]
