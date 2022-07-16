FROM dart:latest
 
COPY . /

ENTRYPOINT ["/entrypoint.sh"]
