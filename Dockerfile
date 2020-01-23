FROM cirrusci/flutter:stable

USER root

WORKDIR /home/cirrus

COPY . /home/cirrus

RUN chmod +x entrypoint.sh

ENTRYPOINT ["/home/cirrus/entrypoint.sh"]