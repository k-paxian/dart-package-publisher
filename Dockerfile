FROM dart:latest

ARG FLUTTER_BRANCH

# Installing prerequisites
RUN apt-get update && \
	apt-get install -y unzip && \
	apt-get clean
  
# Installing Flutter
RUN git clone -b stable --depth 1 https://github.com/flutter/flutter.git /flutter

ENV PATH $PATH:/flutter/bin

RUN flutter doctor

COPY . /

ENTRYPOINT ["/entrypoint.sh"]
