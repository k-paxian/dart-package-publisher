FROM google/dart:latest

ARG FLUTTER_VERSION

RUN if [ "x$FLUTTER_VERSION" != "x" ] ; then apt-get update && \
	apt-get install -y unzip xz-utils && \
	apt-get clean ; else echo 'Argument FLUTTER_VERSION is not provided.' fi

RUN curl https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz --output /flutter.tar.xz && \
	tar xf flutter.tar.xz && \
	rm flutter.tar.xz

ENV PATH $PATH:/flutter/bin

RUN flutter doctor

COPY . /

ENTRYPOINT ["/entrypoint.sh"]
