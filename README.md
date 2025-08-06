# Introduction 
This tool is designed to verify the core functionality of the Device Library, covering both Python and C# implementations. The tested features include:
- Platform Information (Motherboard name, DMI info, etc.)
- Onboard Sensors (Temperature, Voltage, Fan speed)
- GPIO

# Run Test
Run script :
```
./run_test.sh
```

# Mount Files

## SUSI

### Architecture : x86

```
/opt/Advantech/
/etc/Advantech/
/usr/lib/Advantech/
/usr/lib/x86_64-linux-gnu/
/usr/lib/libSUSI-4.00.so
/usr/lib/libSUSI-4.00.so.1
/usr/lib/libSUSI-3.02.so
/usr/lib/libSUSI-3.02.so.1
/usr/lib/libSusiIoT.so
/usr/lib/libSusiIoT.so.1.0.0
/usr/lib/libjansson.so
/usr/lib/libjansson.so.4
/usr/lib/libSUSIDevice.so
/usr/lib/libSUSIDevice.so.1
/usr/lib/libSUSIAI.so
/usr/lib/libSUSIAI.so.1
/usr/lib/libEApi.so
/usr/lib/libEApi.so.1
```

### Architecture : ARM

```
/etc/board
/usr/lib/Advantech/
/usr/lib/aarch64-linux-gnu
/lib/libSUSI-4.00.so
/lib/libSUSI-4.00.so.1
/lib/libSUSI-4.00.so.1.0.0
/lib/libjansson.a
/lib/libjansson.so
/lib/libjansson.so.4
/lib/libjansson.so.4.11.0
/lib/libSusiIoT.so
/lib/libSusiIoT.so.1.0.0
```

## PlatformSDK

```
/usr/src/advantech
/usr/lib/libATAuxIO.so
/usr/lib/libATGPIO.so
/usr/lib/libBoardResource.so
/usr/lib/libEAPI-IPS.so
/usr/lib/libEAPI.so
/usr/lib/libECGPIO.so
/usr/lib/libATSMBUS.so
```