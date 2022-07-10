FROM dart:latest

ARG FLUTTER_BRANCH=stable

# Installing prerequisites
RUN apt-get update && \
	apt-get install -y unzip && \
	apt-get clean
  
# Installing Flutter
RUN git clone -b $FLUTTER_BRANCH --depth 1 https://github.com/flutter/flutter.git /flutter

ENV PATH $PATH:/flutter/bin

RUN flutter doctor

COPY . /

ENTRYPOINT ["/entrypoint.sh"]
