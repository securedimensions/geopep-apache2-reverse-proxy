FROM debian:jessie

MAINTAINER Secure Dimensions <support@secure-dimensions.de>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update

RUN apt-get -y install ansible python-apt

COPY ansible/* /etc/ansible/

COPY mod_authz_geopep/mod_authz_geopep.so /usr/lib/apache2/modules/
COPY mod_authz_geopep/libboost_system.* /usr/lib/
COPY mod_authz_geopep/libboost_locale* /usr/lib/
COPY mod_authz_geopep/libboost_iostreams* /usr/lib/
COPY mod_authz_geopep/libz* /usr/lib/
COPY apache2/html/favicon.ico /var/www/html/

RUN ansible-playbook -i "localhost," -c local /etc/ansible/site.yml

RUN apt-get -y remove ansible python-apt;apt-get -y autoremove
RUN apt-get -y install libtiff5 libgeotiff2 libgd3 libssl1.0.0 libxml2 libxslt1.1

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

CMD ["apache2-reverse-proxy"]
