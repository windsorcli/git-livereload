# Use an Alpine base image
FROM alpine:3.20.3

# Install git, git-daemon, rsync, openssh, nginx, and supervisor
RUN apk update && apk add --no-cache bash git git-daemon rsync \
    inotify-tools nginx fcgiwrap apache2-utils supervisor openssh-client \
    curl

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Ensure the non-root user has proper access to Nginx log directories
RUN mkdir -p /var/log/nginx && \
    chown -R appuser:appgroup /var/log/nginx
        
RUN mkdir -p /etc/nginx && \
    chmod -R 777 /etc/nginx

RUN mkdir -p /var/run && \
    chmod -R 777 /var/run

RUN mkdir -p /var/lib/nginx && \
    chmod -R 777 /var/lib/nginx

RUN mkdir -p /run/nginx && \
    chmod -R 777 /run/nginx

# Redirect logs to stdout and stderr (as root)
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

# Create the necessary directories and set ownership to the non-root user
RUN mkdir -p /repos/git /repos/serve /repos/mount && \
    chown -R appuser:appgroup /repos

# Copy the init script and supervisord configuration into the image
COPY init.sh /init.sh
COPY sync.sh /sync.sh
COPY fcgiwrap.sh /fcgiwrap.sh
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisord.conf

# Use 'main' as the default branch
RUN git config --global init.defaultBranch main

# Add a simple health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost/ || exit 1

# Switch to the non-root user
USER appuser

# Set the supervisord as the command to run when the container starts
CMD ["/init.sh"]
