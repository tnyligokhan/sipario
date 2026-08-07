FROM postgres:16

# Yedekleme betiğini imajın içine göm (Coolify bind-mount sorununu çözer)
COPY docker/backup/backup.sh /scripts/backup.sh
RUN chmod +x /scripts/backup.sh

ENTRYPOINT ["/bin/bash"]
CMD ["/scripts/backup.sh"]
