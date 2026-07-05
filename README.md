# GeoNest

GeoNest 是面向 HarmonyOS 的原生桌面 GIS 工作台。项目通过 N-API 将
ArkTS/ArkUI 界面连接到 C++ GIS 内核，并使用 QGIS Core、GDAL/OGR、
GEOS 与 PROJ 完成空间数据读取、渲染、编辑和分析。

项目主页：https://github.com/haohaoai0/GeoNest

> 当前代码属于持续开发版本。默认构建启用 QGIS Core 4.1.0 development
> snapshot，不建议直接用于未经验证的生产数据处理。

## 功能

- 打开 Shapefile、GeoJSON、GeoPackage、栅格等 GIS 数据；
- 图层增删、排序、显隐、活动图层和工程持久化；
- 地图平移、缩放、全图、坐标和比例尺状态；
- 属性表、要素识别、字段与属性编辑；
- 单一符号、分类、色带和字段标注；
- CRS 读取、定义投影和坐标转换；
- 缓冲区、裁剪、几何修复、简化、融合和质心；
- 矢量编辑、成果导出以及地图布局入口；
- HarmonyOS 手机与 2in1 设备界面适配。

## 架构

```text
ArkTS / ArkUI
    │
    ▼
GisService / GisNativeBridge
    │ N-API
    ▼
libgeonestgis.so
    │
    ├── QGIS Core
    ├── GDAL / OGR
    ├── GEOS / PROJ
    └── Qt 6 for OHOS
```

- `entry/src/main/ets`：页面、组件、工程模型和 GIS 服务；
- `native/napi_bridge`：ArkTS 与 C++ 的稳定接口边界；
- `native/gis_core`：QGIS Core、GDAL 和基础后端实现；
- `scripts/build_native`：Qt、QGIS 和原生依赖的可重复构建脚本；
- `native/third_party/*/patches`：HarmonyOS 移植补丁；
- `scripts/package_corresponding_source.ps1`：GPL 对应源码归档。

## 开发环境

- Windows 10/11；
- DevEco Studio 与 HarmonyOS SDK API 26；
- CMake、Ninja、Clang/LLVM（随 DevEco SDK 提供）；
- PowerShell 5.1 或更高版本；
- Qt 6.8.3 源码；
- 本仓库脚本所列的 QGIS 与 OSGeo 依赖源码。

## 配置签名

复制示例配置：

```powershell
Copy-Item .\build-profile.example.json5 .\build-profile.json5
```

然后在 DevEco Studio 中配置本机调试或发布签名。真实
`build-profile.json5` 被忽略，因为它包含加密签名口令和本机证书路径。

发布构建从以下环境变量读取签名材料：

- `GEONEST_SIGNING_STORE`
- `GEONEST_SIGNING_PROFILE`
- `GEONEST_SIGNING_CERTIFICATE`
- `GEONEST_SIGNING_ALIAS`
- `GEONEST_SIGNING_PASSWORD`

私钥、口令、证书私有材料和商店凭据不会进入源码发布。

## 构建

原生依赖的建议顺序见
[`scripts/build_native/README.md`](scripts/build_native/README.md)。准备好
`native/third_party/qgis/stage/<abi>` 和
`native/third_party/qt6/stage/<abi>` 后，更新
`entry/build-profile.json5` 中的 `QGIS_PREFIX` 与 `QT6_PREFIX`，然后执行：

```powershell
.\scripts\build_entry_hap.ps1
```

完整签名发布：

```powershell
.\scripts\build_release.ps1
```

发布脚本会：

1. 构建并验证签名 APP/HAP；
2. 将 GPL 和第三方许可证完整文本写入 HAP；
3. 在发布目录放置许可证、版权与源码说明；
4. 强制生成 GeoNest、修改后的 QGIS、修改后的 Qt 和原生依赖源码包；
5. 生成二进制与源码 SHA-256 校验文件。

缺少任一对应源码时，发布过程会直接失败。

## 单独生成对应源码

```powershell
.\scripts\package_corresponding_source.ps1 `
  -OutputDirectory .\output\source `
  -VersionName 1.0.0
```

大型 QGIS/Qt 工作树和构建缓存不直接提交到主 Git 历史。每个二进制版本
必须同时发布脚本生成的精确源码归档；仅链接到未固定的上游分支不满足本
项目的发布规则。

对应源码归档发布于：
https://github.com/haohaoai0/GeoNest/releases

## 开源许可

GeoNest 按 [GNU GPL-2.0-or-later](LICENSE) 发布，完整 GPL v2 文本见
[COPYING](COPYING)。

第三方组件、QGIS Qt 链接例外、Qt/GEOS LGPL 要求及对应源码说明见：

- [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)
- [SOURCE_OFFER.txt](SOURCE_OFFER.txt)

接收者可以在 GPL 条款下使用、研究、修改和再分发 GeoNest。软件按
“原样”提供，不附带适销性或特定用途适用性的担保。

## 贡献

提交代码时请：

- 遵守 ArkTS 静态类型和 HarmonyOS API 约束；
- 保留现有版权与许可证声明；
- 对上游 QGIS、Qt 或其他第三方文件的修改注明修改内容和日期；
- 不提交签名材料、令牌、用户数据、构建缓存或设备日志。
