ARG ACES_CONTAINER_COMMIT=7a4e21e142fe46ac300ce047e614e8dbafa873cf
ARG RAWTOACES_COMMIT=master
ARG CERES=ceres-solver-1.14.0
ARG CERES_SHA256=4744005fc3b902fed886ea418df70690caa8e2ff6b5a90f3dd88a3d291ef8e8e
ARG CERES_CMAKE="-DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF"

FROM ubuntu:bionic AS builder

RUN rm -f /etc/apt/apt.conf.d/docker-clean && apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install --no-install-recommends \
    curl ca-certificates git build-essential cmake libilmbase-dev wget autoconf \
    libboost-all-dev libgoogle-glog-dev libatlas-base-dev libeigen3-dev libsuitesparse-dev

RUN wget https://www.libraw.org/data/LibRaw-0.21.1.tar.gz && \
 tar xzvf LibRaw-0.21.1.tar.gz && cd LibRaw-0.21.1 \
 autoreconf --install && \
 ./configure && \
 make && \
 make install

ARG CERES
ARG CERES_SHA256
RUN cd ~ && curl -O "http://ceres-solver.org/$CERES.tar.gz" \
 && echo "$CERES_SHA256 $CERES.tar.gz" | sha256sum -c -

ARG ACES_CONTAINER_COMMIT
RUN mkdir ~/aces_container && cd ~/aces_container \
 && git init && git remote add origin https://github.com/ampas/aces_container \
 && git fetch origin "$ACES_CONTAINER_COMMIT" && git checkout FETCH_HEAD \
 && mkdir build && cd build && cmake .. && make -j `nproc` && make install

ARG CERES
ARG CERES_CMAKE
RUN cd ~ && tar zxf "$CERES.tar.gz" && cd "$CERES" \
 && mkdir build && cd build && cmake $CERES_CMAKE .. && make -j `nproc` && make install

# use a fork with corrected illuminants (#108)
# even the fork has typos, so fix those too.

ARG RAWTOACES_COMMIT
RUN mkdir ~/rawtoaces && cd ~/rawtoaces \
 && git init && git remote add origin https://github.com/toashby/rawtoaces \
 && git fetch origin "$RAWTOACES_COMMIT" && git checkout FETCH_HEAD \
 && sed -i 's/0\.9547, 1\.0000, 1\.0883/0.95047, 1.0000, 1.08883/' lib/define.h \
 && mkdir build && cd build && cmake .. && make -j `nproc` && make install


FROM ubuntu:bionic AS runner

COPY --from=builder /usr/local /usr/local

RUN rm -f /etc/apt/apt.conf.d/docker-clean && apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get -qy install --no-install-recommends \
    libraw16 libilmbase12 libgoogle-glog0v5 libcholmod3 libatlas3-base libcxsparse3

RUN rm -rf /var/lib/apt/lists/* /usr/local/lib/libceres.a

CMD ["/usr/local/bin/rawtoaces"]
