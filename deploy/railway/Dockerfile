FROM frappe/erpnext:v15

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
        supervisor nginx gettext-base netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY supervisord.conf /etc/supervisor/conf.d/frappe.conf
COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && rm -f /etc/nginx/sites-enabled/default \
    && mkdir -p /var/log/supervisor /var/log/nginx \
    && chown -R frappe:frappe /home/frappe/frappe-bench \
    && chown -R frappe:frappe /var/log/supervisor

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
