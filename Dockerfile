FROM nginx:alpine

# Copy the exported Godot Web files to the Nginx html directory
COPY build/web /usr/share/nginx/html

# Godot 4 Web builds require these headers for SharedArrayBuffer support.
# Using a single-line printf to avoid Dockerfile multi-line parser issues.
RUN printf 'server { listen 80; location / { root /usr/share/nginx/html; index index.html; add_header "Cross-Origin-Opener-Policy" "same-origin"; add_header "Cross-Origin-Embedder-Policy" "require-corp"; } }' > /etc/nginx/conf.d/default.conf

EXPOSE 80
