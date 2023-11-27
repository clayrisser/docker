FROM busybox:latest

COPY entrypoint.sh /usr/local/sbin/entrypoint
RUN chmod +x /usr/local/sbin/entrypoint

ENTRYPOINT [ "tail" ]
CMD [ "-f", "/dev/null" ]
