# PIXELOS16


## Build Notes

### Vibrator HAL
The Vibrator HAL (`vendor/qcom/opensource/vibrator`) and its configuration in `device/xiaomi/mt6895-common/mt6895.mk` and `excluded-input-devices.xml` are **REQUIRED** for vibration to work. 

**Do not remove them** even if they appear to be Qualcomm-specific blobs. The MediaTek device tree depends on them for proper vibration functionality.
