FROM dart:latest

# Installing prerequisites
RUN apt-get update && \
	apt-get install -y unzip && \
	apt-get clean
  
ENV PATH $PATH:/flutter/bin

COPY . /

ENTRYPOINT ["/entrypoint.sh"]
