# Use the official lightweight Nginx image
FROM nginx:1.27-alpine

LABEL maintainer="ruthvikk1214"
LABEL description="Static site served by Nginx for the APTY DevOps challenge"

# Copy the static HTML page into Nginx default html directory
# Note: In Kubernetes, this file is overridden by the Helm ConfigMap volume mount.
COPY index.html /usr/share/nginx/html/index.html

# Expose HTTP port
EXPOSE 80
