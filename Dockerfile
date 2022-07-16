FROM dart:latest
 
ENV PATH $PATH:/flutter/bin

COPY . /

ENTRYPOINT ["/entrypoint.sh"]
