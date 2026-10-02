# 1) Start from an official Ruby image (matches your .ruby-version ~ 3.3.12)
FROM docker.io/library/ruby:3.3.12

# 2) Folder inside the container where the app will live
WORKDIR /rails

# 3) OS packages needed to compile the `pg` gem (Postgres driver)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      libyaml-dev \
      libvips42 \
      curl && \
    rm -rf /var/lib/apt/lists/*

# 4) Install gems first (better Docker layer caching)
COPY Gemfile Gemfile.lock ./
RUN bundle install && bundle clean --force

# Bust leftover Solid gems from older image layers when Gemfile changes
ARG APP_REVISION=unknown
RUN echo "revision=${APP_REVISION}"

# 5) Copy the rest of the app (compose will also mount the folder live later)
COPY . .

# 6) Rails must listen on 0.0.0.0 so the Mac can reach it via published ports
EXPOSE 3000
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]