FROM cockpit/infra-base
LABEL maintainer='"Stef Walter" <stefw@redhat.com>'

RUN dnf -y update && dnf -y install nginx && dnf clean all

RUN mkdir -p /usr/local/bin && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    rm -rf /usr/share/nginx/html && \
    ln -snf /cache/images /usr/share/nginx/html && \
    chown -R user /home/user

ADD install-service /usr/local/bin/
ADD nginx.conf /etc/nginx/

VOLUME /secrets
VOLUME /cache

EXPOSE 80 443
STOPSIGNAL SIGQUIT
CMD /usr/sbin/nginx -g "daemon off;"

# We execute the script in the host, but it doesn't exist on the host. So pipe it in
LABEL INSTALL /usr/bin/docker run -ti --rm --privileged --volume=/:/host:rw --user=root IMAGE /bin/bash -c \"/usr/sbin/chroot /host /bin/sh -s < /usr/local/bin/install-service\"

# Run a simple interactive instance of the tests container
LABEL RUN /usr/bin/docker run -ti --rm --publish=80:80 --publish=8493:443 --volume=/var/lib/cockpit-tests/secrets:/secrets:ro --volume=/var/cache/cockpit-tests:/cache:rw IMAGE /bin/bash -i
