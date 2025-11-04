#!/bin/bash

# =============================================================================
# Script para configurar NTP en un clúster OpenShift 4.x
#
# Genera y aplica un MachineConfig para establecer los servidores NTP
# en todos los nodos master y worker del clúster.
#
# PRERREQUISITO: Debes estar logueado en tu clúster con el comando `oc`.
# =============================================================================

set -euo pipefail

# --- Configuración: Modifique esta sección con sus servidores NTP ---
NTP_SERVERS=(
    "192.168.0.5"
    "192.168.0.6"
)
# --- Fin de la configuración ---

# --- Funciones de ayuda con colores ---
COLOR_GREEN=$(tput setaf 2)
COLOR_YELLOW=$(tput setaf 3)
COLOR_BLUE=$(tput setaf 4)
COLOR_RESET=$(tput sgr0)

info() {
    echo "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
}

warn() {
    echo "${COLOR_YELLOW}[AVISO]${COLOR_RESET} $1"
}

# --- Verificación de prerrequisitos ---
if ! command -v oc &> /dev/null; then
    echo "El comando 'oc' no se encuentra. Asegúrate de que está instalado y en tu PATH."
    exit 1
fi

if ! oc whoami &> /dev/null; then
    echo "No has iniciado sesión en un clúster de OpenShift. Por favor, ejecuta 'oc login' primero."
    exit 1
fi

info "Conectado al clúster: $(oc whoami --show-server)"

# --- Generación del contenido de chrony.conf ---
info "Generando el contenido para /etc/chrony.conf..."
CHRONY_CONF_CONTENT=""
for server in "${NTP_SERVERS[@]}"; do
    CHRONY_CONF_CONTENT+="server ${server} iburst\n"
done

# Añadir configuraciones estándar
CHRONY_CONF_CONTENT+=$(cat <<EOF
pool 2.pool.ntp.org iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
)

info "Contenido de chrony.conf a aplicar:"
echo "------------------------------------"
echo -e "$CHRONY_CONF_CONTENT"
echo "------------------------------------"

# --- Codificación en Base64 ---
info "Codificando el contenido en Base64..."
BASE64_CHRONY_CONF=$(echo -ne "$CHRONY_CONF_CONTENT" | base64 -w0)

# --- Creación del MachineConfig YAML ---
info "Generando el manifiesto MachineConfig YAML..."
MACHINE_CONFIG_YAML=$(cat <<EOF
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-master-chrony-configuration-custom
  labels:
    machineconfiguration.openshift.io/role: master
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${BASE64_CHRONY_CONF}
        mode: 420
        overwrite: true
        path: /etc/chrony.conf
---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  name: 99-worker-chrony-configuration-custom
  labels:
    machineconfiguration.openshift.io/role: worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,${BASE64_CHRONY_CONF}
        mode: 420
        overwrite: true
        path: /etc/chrony.conf
EOF
)

# --- Confirmación del usuario ---
warn "Se va a aplicar el siguiente MachineConfig al clúster."
warn "Esto provocará un reinicio progresivo de TODOS los nodos (masters y workers)."
echo
echo "${COLOR_YELLOW}$MACHINE_CONFIG_YAML${COLOR_RESET}"
echo

read -p "¿Estás seguro de que quieres continuar? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Operación cancelada."
    exit 1
fi

# --- Aplicación del MachineConfig ---
info "Aplicando la configuración al clúster..."
echo "$MACHINE_CONFIG_YAML" | oc apply -f -

info "${COLOR_GREEN}¡Configuración aplicada con éxito!${COLOR_RESET}"
info "El Machine Config Operator ahora comenzará a actualizar los nodos."
info "Puedes monitorizar el progreso con el siguiente comando:"
info "  watch oc get machineconfigpool"
echo

exit 0
