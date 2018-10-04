#!/usr/bin/env bash

set -e

# detect and assign usb devices

# special devices
busPirateSerialNo=AH02LWB5

# regular expressions
vboxDevelEmbedRegex="\"(vm\-debian\-devel_default_[0-9_]*)\"\s*\{([a-f0-9\-]*)\}"
vboxUsbUUIDRegex="UUID:\s*([0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12})"
vboxUsbManufacturerRegex="Manufacturer:\s*([a-zA-Z0-9\-\_\s]*)"
vboxUsbProductRegex="Product:\s*([a-zA-Z0-9\-\_\s]*)"
vboxUsbSerialNumberRegex="SerialNumber:\s*([A-Z0-9]*)"
vboxUsbVendorIDRegex="VendorId:\s*([a-fx0-9]*)"
vboxUsbProductIDRegex="ProductId:\s*([a-fx0-9]*)"
usbFtdiNameRegex="Bus\s[0-9]{3}\sDevice\s[0-9]{3}:\sID\s([a-f0-9]{4}):([a-f0-9]{4})\sFuture Technology Devices International, Ltd FT232 USB\-Serial \(UART\) IC"

# Attempt to attach a usb device
# usbAttach vm_uuid usb_uuid
function usbAttach
{
    if [[ $# -ne 2 ]]; then
        echo "illegal number of parameters"
    else
        vboxmanage controlvm $1 usbattach $2 ||  echo "Failed to attach $2"
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
foundVms=`vboxmanage list vms`

if [[ ${foundVms} =~ ${vboxDevelEmbedRegex} ]];
then
    vmName=${BASH_REMATCH[1]}
    vmUUID=${BASH_REMATCH[2]}
    echo
    echo Found: ${vmName}
    echo VM UUID: ${vmUUID}
    echo 
fi

while [ true ] ; do
    printf "\033c"

# Get a list of UUIDs of currently attached USB devices
    startUSBSection=0
    endUSBSection=0
    attachedSBIndex=0
    attachedUSBUUID=()
    attachedUSBManufacturer=()
    attachedUSBProduct=()
    attachedUSBSerialNumber=()
    
    OIFS=$IFS
    IFS=$'\x0a'; vboxUSBHostList=( `vboxmanage showvminfo ${vmUUID}` );
    IFS=$OIFS
    for index in "${!vboxUSBHostList[@]}"
    do
        if [[ ${vboxUSBHostList[index]} =~ "Currently Attached USB Devices:" ]]
        then
            startUSBSection=1
        fi
        if [[ ${vboxUSBHostList[index]} =~ "Bandwidth groups" ]]
        then
            endUSBSection=1
        fi
        if [[ ${startUSBSection} -eq 1 && ${endUSBSection} -eq 0 ]]
        then
            if [[ ${vboxUSBHostList[index]} =~ ${vboxUsbUUIDRegex} ]]
            then
                attachedUSBIndex=`expr ${attachedUSBIndex} + 1`
                attachedUSBUUID[attachedUSBIndex]=${BASH_REMATCH[1]}
            elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbManufacturerRegex} ]]
            then
                attachedUSBManufacturer[attachedUSBIndex]=${BASH_REMATCH[1]}
            elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbProductRegex} ]]
            then
                attachedUSBProduct[attachedUSBIndex]=${BASH_REMATCH[1]}
            elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbSerialNumberRegex} ]]
            then
                attachedUSBSerialNumber[attachedUSBIndex]=${BASH_REMATCH[1]}
            fi
        fi
    done

    echo
    echo Attached usb devices: ${vmName}
    echo   |
    for devIndex in "${!attachedUSBUUID[@]}"
    do
#        echo "  |- ${attachedUSBManufacturer[devIndex]} ${attachedUSBProduct[devIndex]} ${usbProduct[devIndex]} ${attachedUSBSerialNumber[devIndex]} "
        echo "  |- ${attachedUSBManufacturer[devIndex]} ${attachedUSBProduct[devIndex]} ${usbProduct[devIndex]} ${attachedUSBSerialNumber[devIndex]} ${attachedUSBUUID[devIndex]}"        
    done

    echo 
# Get all USB devices available to vms
    OIFS=$IFS
    IFS=$'\x0a'; vboxUSBHostList=( `vboxmanage list usbhost` );
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
        if [[ ${vboxUSBHostList[index]} =~ ${vboxUsbUUIDRegex} ]]
        then
            newUUID=${BASH_REMATCH[1]}
            containsElement "${newUUID}" "${attachedUSBUUID[@]}"
            if [[ ${alreadyAttached} -eq 0  ]]; then
                usbDeviceIndex=`expr ${usbDeviceIndex} + 1`
    	        usbUUID[usbDeviceIndex]=${newUUID}
            fi
        elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbManufacturerRegex} ]]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then            
	        usbManufacturer[usbDeviceIndex]=${BASH_REMATCH[1]}
            fi
        elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbProductRegex} ]]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbProduct[usbDeviceIndex]=${BASH_REMATCH[1]}
            fi
        elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbSerialNumberRegex} ]]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbSerialNumber[usbDeviceIndex]=${BASH_REMATCH[1]}
            fi
        elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbVendorIDRegex} ]]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbVendorId[usbDeviceIndex]=${BASH_REMATCH[1]}
            fi
        elif [[ ${vboxUSBHostList[index]} =~ ${vboxUsbProductIDRegex} ]]
        then
            if [[ ${alreadyAttached} -eq 0  ]]; then
	        usbProductId[usbDeviceIndex]=${BASH_REMATCH[1]}
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
    elif [[ ${choice} -gt "0" && ${choice} -lt ${#usbUUID[@]} ]] ; then
        echo Attempting to attach ${usbProduct[choice]}...
        usbAttach ${vmUUID} ${usbUUID[choice]}
        sleep 1
    else
        echo ${choice}
        exit;
    fi
done
