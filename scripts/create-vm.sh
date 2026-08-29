#!/usr/bin/env bash
# Create a VirtualBox VM for SSRS dev sandbox running Windows Server 2022.
# Usage: ./create-vm.sh /absolute/path/to/WindowsServer2022.iso
set -euo pipefail

ISO="${1:-}"
if [[ -z "$ISO" || ! -f "$ISO" ]]; then
  echo "ERROR: Pass the absolute path to the Windows Server 2022 ISO."
  echo "Usage: $0 /home/$USER/VMs/iso/WindowsServer2022.iso"
  exit 1
fi

VM_NAME="ssrs-dev-vm"
VM_DIR="$HOME/VMs/${VM_NAME}"
DISK="${VM_DIR}/${VM_NAME}.vdi"
RAM_MB=8192
VRAM_MB=128
CPUS=4
DISK_MB=81920   # 80 GB dynamic

mkdir -p "$VM_DIR"

# Bail if VM already exists.
if VBoxManage list vms | grep -q "\"${VM_NAME}\""; then
  echo "VM '${VM_NAME}' already exists. Delete it first with:"
  echo "  VBoxManage unregistervm '${VM_NAME}' --delete"
  exit 1
fi

echo "==> Creating VM '${VM_NAME}'"
VBoxManage createvm --name "$VM_NAME" --ostype "Windows2022_64" --register --basefolder "$HOME/VMs"

echo "==> Configuring hardware"
VBoxManage modifyvm "$VM_NAME" \
  --memory "$RAM_MB" \
  --vram "$VRAM_MB" \
  --cpus "$CPUS" \
  --firmware efi \
  --chipset ich9 \
  --graphicscontroller vboxsvga \
  --audio-driver none \
  --usbohci on \
  --clipboard-mode bidirectional \
  --draganddrop bidirectional \
  --nic1 nat \
  --nictype1 82540EM \
  --natpf1 "rdp,tcp,,3389,,3389" \
  --natpf1 "ssrs-http,tcp,,8080,,80" \
  --natpf1 "sql,tcp,,11433,,1433"

echo "==> Creating 80 GB dynamic disk"
VBoxManage createmedium disk --filename "$DISK" --size "$DISK_MB" --format VDI --variant Standard

echo "==> Attaching storage (SATA disk + IDE DVD with ISO)"
VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci --portcount 2 --bootable on
VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$DISK"

VBoxManage storagectl "$VM_NAME" --name "IDE" --add ide --controller PIIX4
VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium "$ISO"

VBoxManage modifyvm "$VM_NAME" --boot1 dvd --boot2 disk --boot3 none --boot4 none

echo
echo "Done. Host port forwards (host -> guest):"
echo "  RDP        : localhost:3389 -> guest 3389"
echo "  SSRS HTTP  : http://localhost:8080  -> guest port 80 (SSRS default)"
echo "  SQL Server : localhost,11433        -> guest port 1433"
echo
echo "Start the VM with:"
echo "  VBoxManage startvm '${VM_NAME}' --type gui"
