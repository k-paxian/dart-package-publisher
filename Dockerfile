FROM google/dart:latest

ARG FLUTTER_VERSION=v1.12.13+hotfix.5

RUN curl https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz --output /flutter.tar.xz && \
	tar xf flutter.tar.xz && \
	rm flutter.tar.xz

ENV PATH $PATH:/flutter/bin

RUN flutter doctor

COPY . /

ENTRYPOINT ["/entrypoint.sh"]
