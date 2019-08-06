FROM fedora:latest
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

RUN dnf -y update \
 && dnf -y install \
        nginx \
        fcgiwrap \
        python3 \
        python3-scikit-learn \
        python3-matplotlib \
 && dnf clean all \
 && mkdir -p /cache/train \
 && chmod -R 777 /cache \
 && ln -sf /dev/stdout /var/log/nginx/access.log

COPY * /learn/

COPY nginx.conf /etc/nginx/

WORKDIR /
ENV TEST_DATA=/cache \
    PATH=$PATH:/learn \
    HOME=/home

EXPOSE 8080 8443
VOLUME /cache
VOLUME /cache/train
STOPSIGNAL SIGQUIT
CMD [ "/bin/bash" ]

# To run lighttpd container
# CMD ["lighttpd", "-D", "-f", "/learn/lighttpd.conf"]

# To run the batch training container
# CMD [ "/learn/train-tests", "--verbose", "--batch", "/cache/train/*" ]
