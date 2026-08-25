#!/bin/bash
# postgres'in resmi entrypoint'ini sarmalar: yanına rol eşitleyicisini koyar.
#
# `exec` ŞART: postgres PID 1 olarak koşmalı ki docker'ın SIGTERM'i doğrudan ona ulaşsın.
# Aksi halde durdurma sinyali kabuğa gider, postgres 10 sn sonra SIGKILL ile kesilir ve
# her kapanış kirli kapanış olur.
set -euo pipefail

/usr/local/bin/sipario-rol-esitle.sh &

exec docker-entrypoint.sh "$@"
