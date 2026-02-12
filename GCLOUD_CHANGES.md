rm -rf packages/apps/ParanoidSense

## Disable ParanoidSense `libmegface` Conflict (MTK Xiaomi)

### Issue

Build fails with duplicate module error:


**Cause:**

- Xiaomi MTK devices already ship Megvii face unlock HAL (`hardware/xiaomi/megvii`)
- ParanoidSense also includes a prebuilt `libmegface`
- Soong loads both → duplicate module conflict

---

### Resolution

Disable only the ParanoidSense `libmegface` module while keeping the AIDL interfaces intact.

This preserves framework dependencies but removes the duplicate library.

---

### Files Modified


---

### Changes Applied

#### 1) Remove dependency reference

Inside the `required:` block:

```diff
- "libmegface",
+ // "libmegface",
// cc_prebuilt_library_shared {
//     name: "libmegface",
//     srcs: ["prebuilts/libmegface.so"],
//     vendor: true,
//     strip: {
//         none: true,
//     },
// }
