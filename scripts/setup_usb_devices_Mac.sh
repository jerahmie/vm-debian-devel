#!/usr/bin/env bash

set -e

# detect and assign usb devices

if [ "$(uname)" == "Darwin" ]; then
    VBoxManageBin=`which VBoxManage`
elif [ "$(uname)" == "Linux" ]; then
    VBoxManageBin=`which vboxmanage`
fi

# if [ ! "${VBoxManageBin}" ]; then
#   echo Could not find VBoxManage binary.  Check installation.
#   exit -1
#fi

# special devices
busPirateSerialNo=AH02LWB5

usbFtdiNameRegex="Bus\s[0-9]{3}\sDevice\s[0-9]{3}:\sID\s([a-f0-9]{4}):([a-f0-9]{4})\sFuture Technology Devices International, Ltd FT232 USB\-Serial \(UART\) IC"
# Attempt to attach a usb device
# usbAttach vm_uuid usb_uuid
function usbAttach
{
    if [[ $# -ne 2 ]]; then
        echo "illegal number of parameters"
    else
        $VBoxManageBin controlvm $1 usbattach $2 ||  echo "Failed to attach $2"
    fi
}

# Search for UUID value in array of UUIDs
function containsElement
{
    local e
#    for element in ${@:2}; do echo ${element}; done
    alreadyAttached=0
    for e in "${@:2}"
    do
        if [[ "$e" == "$1" ]]; then
            alreadyAttached=1
        fi
    done
}

# find vbox-devel-embed virtual box
# TODO: this should be able to find virtual box name from parent directory name
foundVms=`$VBoxManageBin list vms`
vmName=`echo ${foundVms} | sed 's/.*"\(vm-devel-embed_default_[0-9_]*\)" {\([a-f0-9\-]*\)}.*/\1/'`
vmUUID=`echo ${foundVms} | sed 's/.*"\(vm-devel-embed_default_[0-9_]*\)" {\([a-f0-9\-]*\)}.*/\2/'`

while [ true ] ; do
    printf "\033c"

    # Get a list of UUIDs of currently attached USB devices
    startUSBSection=0
    endUSBSection=0
    attachedUSBIndex=0
    attachedUSBUUID=()
    attachedUSBManufacturer=()
    attachedUSBProduct=()
    attachedUSBProductID=()
    attachedUSBSerialNumber=()
    
    OIFS=$IFS
    IFS=$'\x0a'; vboxUSBHostList=( `$VBoxManageBin showvminfo ${vmUUID}` );
    IFS=$OIFS
    for index in "${!vboxUSBHostList[@]}"
    do
        if [[ ${vboxUSBHostList[index]} == "Currently Attached USB Devices:" ]]
        then
            startUSBSection=1
        fi
        if [[ ${vboxUSBHostList[index]} == "Bandwidth groups" ]]
        then
            endUSBSection=1
        fi
        if [[ ${startUSBSection} -eq 1 && ${endUSBSection} -eq 0 ]]
        then
            vboxUSBUUID=`echo ${vboxUSBHostList[index]} | sed -n 's/^UUID:\s*\([-0-9a-f]*\)/\1/p'`
            vboxUSBManufacturer=`echo ${vboxUSBHostList[index]} | sed -n 's/^Manufacturer:\s*\([-a-zA-Z0-9_\s]*\)/\1/p'`
            vboxUSBProduct=`echo ${vboxUSBHostList[index]} | sed -n 's/^Product:\s*\([a-f0-9]*\)/\1/p'`
            vboxUSBProductID=`echo ${vboxUSBHostList[index]} | sed -n 's/^ProductId:\s*\([a-f0-9]*\)/\1/p'`
            vboxUSBSerialNumber=`echo ${vboxUSBHostList[index]} | sed -n 's/^SerialNumber:\s*\([A-Z0-9]*\)/\1/p'`
            vboxUSBVendorID=`echo ${vboxUSBHostList[index]} | sed -n 's/^VendorId:\s*\([a-fx0-9]*\)/\1/p'`
            if [ -n "${vboxUSBUUID}" ]; then
                attachedUSBIndex=`expr ${attachedUSBIndex} + 1`
                attachedUSBUUID[attachedUSBIndex]=${vboxUSBUUID}
            elif [ -n "${vboxUSBManufacturer}" ]; then
                attachedUSBManufacturer[attachedUSBIndex]=${vboxUSBManufacturer}
            elif [ -n "${vboxUSBProduct}" ]; then
                attachedUSBProduct[attachedUSBIndex]=${vboxUSBProduct}
            elif [ -n "${vboxUSBProductID}" ]; then
                attachedUSBProductID[attachedUSBIndex]=${vboxUSBProductID}
            elif [ -n "${vboxUSBSerialNumber}" ]; then
                attachedUSBSerialNumber[attachedUSBIndex]=${vboxUsbSerialNumber}
            fi
        fi
    done

    echo
    echo Attached usb devices: ${vmName}
    echo   |
    for devIndex in "${!attachedUSBUUID[@]}"
    do
        echo "  |- ${attachedUSBManufacturer[devIndex]} ${attachedUSBProduct[devIndex]} ${attachedUSBProductID[devIndex]} ${attachedUSBSerialNumber[devIndex]} ${attachedUSBUUID[devIndex]}"        
    done

    echo 
# Get all USB devices available to vms
    OIFS=$IFS
    IFS=$'\x0a'; vboxUSBHostList=( `$VBoxManageBin list usbhost` );
    IFS=$OIFS
    
    usbUUID=()
    usbManufacturer=()
    usbProduct=()
    usbSerialNumber=()
    usbVendorId=()
    usbProductId=()
    usbDeviceIndex=0

    for index in "${!vboxUSBHostList[@]}"
    do
            newUsbUUID=`echo ${vboxUSBHostList[index]} | sed -n 's/^UUID:\s*\([-0-9a-f]*\)/\1/p'`
            newUsbManufacturer=`echo ${vboxUSBHostList[index]} | sed -n 's/^Manufacturer:\s*\([-a-zA-Z0-9_\s]*\)/\1/p'`
            newUsbProduct=`echo ${vboxUSBHostList[index]} | sed -n 's/^ProductId:\s*\([a-f0-9]*\)/\1/p'`
            newUsbSerialNumber=`echo ${vboxUSBHostList[index]} | sed -n 's/^SerialNumber:\s*\([A-Z0-9]*\)/\1/p'`
            newUsbVendorId=`echo ${vboxUSBHostList[index]} | sed -n 's/^VendorId:\s*\([a-f0-9]*\)/\1/p'`

        if [ -n "${newUsbUUID}" ]
        then
            containsElement "${newUsbUUID}" "${attachedUSBUUID[@]}"
            if [[ ${alreadyAttached} -eq 0  ]]; then
                usbDeviceIndex=`expr ${usbDeviceIndex} + 1`
    	        usbUUID[usbDeviceIndex]=${newUsbUUID}
            fi
        elif [ -n "${newUsbManufacturer}" ]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then            
	        usbManufacturer[usbDeviceIndex]=${newUsbManufacturer}
            fi
        elif [ -n "${newUsbProduct}" ]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbProduct[usbDeviceIndex]=${newUsbProduct}
            fi
        elif [ -n "${newUsbSerialNumber}" ]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbSerialNumber[usbDeviceIndex]=${newUsbSerialNumber}
            fi
        elif [ -n "${newUsbVendorId}" ] 
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbVendorId[usbDeviceIndex]=${newUsbVendorId}
            fi
        elif [ -n "${newUsbProductId}" ]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbProductId[usbDeviceIndex]=${newUsbProductId}
            fi
        fi
    done

    echo 
    echo Available USB devices:
    for index in "${!usbUUID[@]}"
    do
        echo  "  $index: ${usbManufacturer[index]} ${usbProduct[index]} ${usbSerialNumber[index]}"
    done
    echo
    read  -p "Enter device to add ('q' to quit): " choice
    if [[ ${choice} == 'q' || ${choice} == 'Q' ]] ; then
        exit;
    elif [[ ${choice} -gt "0" && ${choice} -le ${#usbUUID[@]} ]] ; then
        echo Attempting to attach ${usbProduct[choice]}...
        usbAttach ${vmUUID} ${usbUUID[choice]}
        sleep 1
    #else
        #echo ${choice}/${#usbUUID[@]}
    #    exit;
    fi
done
