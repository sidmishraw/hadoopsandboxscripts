#!/bin/bash
#
# Author: Sidharth Mishra <sidmishraw@gmail.com>
#
# Description: This script will setup a brand new hadoop sandbox using VirtualBox and Centos 6.4 LTS
# and help with installation of the VirtualBox
#
# License: MIT
#
# Created: 08/12/2017
#
# Version: 0.0.1
#
# Note:
# Please don't hesitate to report the bugs. For reporting bugs, use the [BUG-Sandbox-Script-<script name>] tag
# in the subject line of the email.

###################### FUNCTIONS START #############
# Print the usage for this script
printUsage() {

  print "\n";
  print "Usage: Sandbox setup using Centos: defaults to 6.4";
  print "\n \n";
  print "./centos6_hadoop_setup.sh -v <version of centos to download and setup>";
  print "\n";
  exit $1;
}

# Print message, interprets special characters like \n etc
print() {

  echo -e "$@";
}

# For error handling
catchError() {
  echo -e "$1";
  exit $2;
}

# Download the centos version specified
downloadCentOS() {

  case "$1" in
    "6")
      print "Downloading CentOS 6.9 ...";

      # Download the minimal ISO for CentOS 6.9
      wget "http://mirrors.ocf.berkeley.edu/centos/6/isos/x86_64/CentOS-6.9-x86_64-minimal.iso";

      if [ $? -gt 0 ]
      then
        catchError "Failed to download, download manually and rerun with -i flag" 3;
      fi

      print "Successfully downloaded CentOS 6.9 ...";;
    "7")
      print "Downloading CentOS 7 ...";

      # Download the minimal ISO for CentOS 7.0
      wget "http://mirrors.ocf.berkeley.edu/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1611.iso";

      if [ $? -gt 0 ]
      then
        catchError "Failed to download, Download manually and rerun with -i flag" 3;
      fi

      print "Successfully downloaded CentOS 7 ...";;
    *)
      downloadCentOS "6";
  esac

  centosISO="$(ls | grep -i .*\.iso)";

  print "Installing ${centosISO} into VirtualBox ...";

  installCentOS "./${centosISO}";
}

# Install CentOS using VirtualBox CLI
installCentOS() {

  print "\n\nStarting installation of CentOS from $1...";

  print "Creating new VM named HadoopSandbox_CentOS...";

  vmName="HadoopSandbox_CentOS";

  if [ -n "$(VBoxManage list vms | grep $vmName)" ]
  then
    vmName="${vmName}_$(date +%s)";

    print "VM name is already taken, changing to: ${vmName}";
  fi

  VBoxManage createvm --name "${vmName}" --register;

  if [ $? -gt 0 ]
  then
    catchError "Failed to create VM, the script has failed, please contact the author of the script. Aborting...\n" 3;
  fi

  print "VM created and registered successfully ... Initiating setup and installation of CentOS into the VM...";

  print "Beginning configuration ...";

  VBoxManage modifyvm "${vmName}" \
    --ostype "RedHat_64" \
    --memory "6144" \
    --cpus "2" \
    --acpi "on" \
    --ioapic "on" \
    --defaultfrontend "gui" \
    --nic1 "nat" \
    --nictype1 "82540EM" \
    --natpf1 "ssh","tcp","127.0.0.1","2222","","22" \
    --natpf1 "mcs","tcp","127.0.0.1","8443","","8443";

  print "VM modified ...";
  print "Attaching Storage ...";

  # Adding IDE -- Disk port
  VBoxManage storagectl "${vmName}" \
    --name "IDE" \
    --add "ide" \
    --controller "PIIX4" \
    --portcount 2 \
    --bootable "on";

  if [ $? -gt 0 ]
  then
    catchError "Failed to attach IDE storage controller. Aborting ..." 3;
  fi

  print "IDE controller successfully attached...";

  # Adding SATA -- Storage port
  VBoxManage storagectl "${vmName}" \
    --name "SATA" \
    --add "sata" \
    --controller "IntelAhci" \
    --portcount 1 \
    --bootable "on";

  if [ $? -gt 0 ]
  then
    catchError "Failed to attach SATA storage controller to the VM. Aborting ..." 3;
  fi

  print "SATA controller successfully attached...";

  # Create and attach HDD to the VM of 16GB = 16384 MB
  print "Creating and attaching HDD of 16GB ~ 16384 MB";

  VBoxManage createmedium disk \
    --filename "HadoopCentOS" \
    --size "16384" \
    --format "VDI";

  if [ $? -gt 0 ]
  then
    catchError "Failed to create a 16GB HDD for the VM. Aborting..." 3;
  fi

  print "Created the HDD successfully. Attaching to VM...";

  VBoxManage storageattach "${vmName}" \
    --storagectl "SATA" \
    --port 0 \
    --device 0 \
    --type "hdd" \
    --medium "HadoopCentOS.vdi";

  if [ $? -gt 0 ]
  then
    catchError "Failed to attach HDD to the VM. Aborting...";
  fi

  print "Attached HDD to VM...";

  print "Now attaching CentOS ISO from $1...";

  isoSizeBytes="$(stat -f "%z" $1)";

  # Attach the ISO to the VM when it boots up for the first time
  VBoxManage storageattach "${vmName}" \
    --storagectl "IDE" \
    --port 1 \
    --device 1 \
    --type "dvddrive" \
    --medium "$1";

  if [ $? -gt 0 ]
  then
    catchError "Failed to attach ISO to the IDE controller of the VM. Aborting...";
  fi

  print "ISO successfully attached. VM is ready for installing CentOS...";

  print "\nFinished installation of CentOS...";

  print "Starting VM...";

  # VBoxManage startvm "${vmName}";
}
###################### FUNCTIONS END ###############

############ START
inputSwitch="$(echo $1 | tr [:upper:] [:lower:])";

# centos version, defaults to 6
centosVersion="6";

case "${inputSwitch}" in

  "-h")
    printUsage 0;;

  "-v")
    if [ -z "$2"  ]
    then
      printUsage 1;
    else
      print "Centos to be downloaded = $2 \n";

      centosVersion="$2";

      if [ ${#centosVersion} -gt 1 ]
      then
        centosVersion="$(echo $centosVersion | awk '{split($0,a,"."); print a[1]}')";
      fi

      # Download VirtualBox if not present
      downloadCentOS "${centosVersion}";
    fi;;

  "-i")

    if ! [ -z "$2" ]
    then
      isoPath="$2";
      print "Starting installing of CentOS into VirtualBox using ISO at ${isoPath} ...";

      installCentOS "${isoPath}";
    else
      printUsage 1;
    fi;;

  *)
    print "Bad switch";
    printUsage 1;;
esac

