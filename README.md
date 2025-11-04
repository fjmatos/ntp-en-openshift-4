# Cómo usar el script

## 1. Descarga el script 
Descarga el fichero llamado `apply-ntp-config.sh`.

## 2. Dale permisos de ejecución
Abre un terminal y ejecuta:

```bash
chmod +x apply-ntp-config.sh
```

Inicia sesión en tu clúster: Asegúrate de que has iniciado sesión en tu clúster de OpenShift con las credenciales de administrador:

```bash
oc login --token=... --server=...
```

Ejecuta el script:

./apply-ntp-config.sh

El script te mostrará a qué clúster estás conectado, el contenido del fichero chrony.conf que va a generar, y finalmente el YAML completo del MachineConfig. Te pedirá una confirmación final antes de aplicar los cambios, ya que esto iniciará el reinicio de los nodos.
Una vez que confirmes, aplicará la configuración y te dará el comando para monitorizar el progreso. Verás cómo el MachineConfigPool de los workers y masters pasa a un estado de UPDATING y, una vez que todos los nodos se hayan reiniciado, volverá a UPDATED.
Después de este proceso, tu problema de NTP estará resuelto de forma definitiva y correcta.
