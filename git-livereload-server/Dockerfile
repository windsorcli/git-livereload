# Use an Alpine base image
FROM alpine:3.20.3

# Create a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Create the necessary directories and set ownership to the non-root user
RUN mkdir -p /repos/git /repos/serve /repos/mount && \
    chown -R appuser:appgroup /repos /var

# Install git, git-daemon, rsync, openssh, nginx, and supervisor
RUN apk update && apk add --no-cache bash git git-daemon rsync \
    inotify-tools nginx fcgiwrap apache2-utils supervisor openssh-client \
    curl

USER appuser

# Copy the init script and supervisord configuration into the image
COPY init.sh /init.sh
COPY sync.sh /sync.sh
COPY fcgiwrap.sh /fcgiwrap.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisord.conf

# Create the necessary directories if they don't exist
RUN mkdir -p /repos/git /repos/serve /repos/mount

# Use 'main' as the default branch
RUN git config --global init.defaultBranch main

# Redirect nginx logs to stdout and stderr
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Add a simple health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost/ || exit 1

# Set the supervisord as the command to run when the container starts
CMD ["/init.sh"]
