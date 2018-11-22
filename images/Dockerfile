FROM cockpit/infra-base
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

RUN dnf -y update && \
    dnf -y install nginx && \
    dnf clean all

RUN mkdir -p /usr/local/bin && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    rm -rf /usr/share/nginx/html && \
    ln -snf /cache/images /usr/share/nginx/html && \
    chown -R user /home/user

COPY install-service /usr/local/bin/
COPY nginx.conf /etc/nginx/

VOLUME /secrets /cache

EXPOSE 8080 8443
STOPSIGNAL SIGQUIT
CMD /usr/sbin/nginx -g "daemon off;"

# We execute the script in the host, but it doesn't exist on the host. So pipe it in
LABEL INSTALL /usr/bin/docker run -ti --rm --privileged --volume=/:/host:rw --user=root IMAGE /bin/bash -c \"/usr/sbin/chroot /host /bin/sh -s < /usr/local/bin/install-service\"

# Run a simple interactive instance of the tasks container
LABEL RUN /usr/bin/docker run -ti --rm --publish=80:8080 --publish=8493:8443 --volume=/var/lib/cockpit-tasks/secrets:/secrets:ro --volume=/var/cache/cockpit-tasks:/cache:rw IMAGE /bin/bash -i
