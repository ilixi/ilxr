#!/bin/bash
# ===============================================================================
# Installs linux-fusion modules.
#

if ! grep -Fxq "fusion" /etc/modules
then
   echo "Append fusion and linux-one to etc/modules..."
   sudo su -c "echo fusion >> /etc/modules"
   sudo su -c "echo linux-one >> /etc/modules"
fi

if [ ! -f "/etc/udev/rules.d/40-fusion.rules" ]
then
   echo "Creating udev rules..."
   sudo usermod -a -G video "$(whoami)"
   sudo sh -c "echo KERNEL==\\\"fusion[0-7]*\\\", NAME=\\\"fusion%n\\\", GROUP=\\\"video\\\", MODE=\\\"0666\\\" > /etc/udev/rules.d/40-fusion.rules"
   sudo sh -c "echo KERNEL==\\\"one[0-7]*\\\", NAME=\\\"one%n\\\", GROUP=\\\"video\\\", MODE=\\\"0666\\\" > /etc/udev/rules.d/40-one.rules"
   sudo /etc/init.d/udev reload
fi

sudo depmod -a

echo "Loading modules..."
sudo modprobe fusion
if [ $? -ne 0 ]
then
  echo "Cannot load fusion!"
  exit 1
fi

sudo modprobe linux-one
if [ $? -ne 0 ]
then
  echo "Cannot load linux-one!"
  exit 1
fi

echo "linux-fusion modules are installed."
exit 0
