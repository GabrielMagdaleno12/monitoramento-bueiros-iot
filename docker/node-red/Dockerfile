FROM nodered/node-red:4.0.9

# no de gravacao no InfluxDB 2.x
RUN npm install --no-fund --no-audit --omit=dev node-red-contrib-influxdb@0.7.0

COPY settings.js /opt/bueiros/settings.js
COPY flows.json /opt/bueiros/flows.json
COPY start.sh /opt/bueiros/start.sh

ENTRYPOINT ["/bin/sh", "/opt/bueiros/start.sh"]
