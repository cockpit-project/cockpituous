FROM cockpit/infra-base
LABEL maintainer='cockpit-devel@lists.fedorahosted.org'

RUN dnf -y update \
 && dnf -y install \
        lighttpd \
        python3 \
        python3-scikit-learn \
        python3-matplotlib \
        python3-pip \
 && pip3 install hdbscan \
 && dnf clean all

RUN mkdir -p /cache/train \
 && chown -R user /home/user /cache/train

COPY * /learn/
WORKDIR /
ENV TEST_DATA=/cache \
    PATH=$PATH:/learn \
    HOME=/home/user

EXPOSE 8080 8090
VOLUME /cache
VOLUME /cache/train
STOPSIGNAL SIGQUIT
CMD [ "/bin/bash" ]

# To run lighttpd container
# CMD ["lighttpd", "-D", "-f", "/learn/lighttpd.conf"]

# To run the batch training container
# CMD [ "/learn/train-tests", "--verbose", "--batch", "/cache/train/*" ]
