FROM google/dart:latest

# Installing required packages
RUN apt-get update && \
	apt-get install -y git unzip ca-certificates && \
	apt-get clean

# Installing Flutter
RUN git clone -b stable --depth 1 https://github.com/flutter/flutter.git /flutter \
    && flutter --version

ENV PATH $PATH:/flutter/bin

RUN flutter doctor

COPY . /

ENTRYPOINT ["/entrypoint.sh"]
