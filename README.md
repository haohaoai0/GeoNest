# GeoNest

GeoNest 是一个面向 HarmonyOS 2-in-1 设备的原生 GIS 工作台。它用 ArkTS/ArkUI 构建交互界面，通过 N-API 连接 C++ GIS 核心，并将 QGIS Core、GDAL/OGR、GEOS、PROJ 与 Qt 6 组合为可在 HarmonyOS 上运行的空间数据处理能力。

> 当前仓库处于持续开发阶段。主线默认使用 QGIS Core 4.1.0 development snapshot；在生产环境使用前，请先用目标设备和真实数据完成验证。

[![HarmonyOS](https://img.shields.io/badge/HarmonyOS-API%2026-0A59F7.svg)](https://developer.huawei.com/consumer/cn/) [![License](https://img.shields.io/badge/license-GPL--2.0--or--later-blue.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-1.0.3-orange.svg)](CHANGELOG.md)

## 目录

- [项目定位](#项目定位)
- [功能概览](#功能概览)
- [技术架构](#技术架构)
- [环境要求](#环境要求)
- [快速开始](#快速开始)
- [构建流程](#构建流程)
- [仓库结构](#仓库结构)
- [发布与许可证](#发布与许可证)
- [贡献指南](#贡献指南)
- [已知限制](#已知限制)

## 项目定位

GeoNest 试图把桌面 GIS 的数据浏览、编辑、分析和成果交付能力带到 HarmonyOS。项目重点不是提供一个简单的地图查看器，而是建立一条完整的“数据导入 → 地图交互 → 空间处理 → 工程保存 → 成果导出”工作流。

项目主页：[github.com/haohaoai0/GeoNest](https://github.com/haohaoai0/GeoNest)

## 功能概览

### 数据与工程

- 读取 Shapefile、GeoJSON、GeoPackage、KML/KMZ、CSV、XLS/XLSX、TIFF、JPEG、PNG 等常见数据；
- 支持工程图层管理、图层排序、显隐切换、活动图层和工程持久化；
- 读取与写出 `.qgs` / `.qgz` 工程，支持便携式工程打包和系统分享导入；
- 支持 Shapefile 关联文件、拖放导入、批量 URI 导入及文件关联打开。

### 地图浏览与编辑

- 平移、滚轮缩放、全图、比例尺、坐标显示和在线底图；
- 单选、多选、矩形、套索和多边形选择，并可跨图层进行空间选择；
- 属性表、字段搜索、要素识别、批量属性赋值和表达式工作台；
- 点/线/面新增、节点编辑、要素删除、切割、撤销、重做、提交和回滚；
- 第二地图窗口、数据视图/布局视图切换，以及地图集导出入口。

### 符号、标注与栅格

- 单一符号、分类/分级、表达式规则和色带渲染；
- 线型、填充、透明度、字段标注、避让及比例尺范围配置；
- QML 样式导入/导出；
- 单波段灰度、RGB 合成、拉伸、NoData、透明色带、阴影地形和不透明度设置。

### 空间分析与交付

- 几何修复、缓冲区、裁剪、融合、质心、凸包、最小外包矩形等常用工具；
- 叠加分析、邻近分析、空间统计、栅格分析、插值、密度、重分类和时空分析；
- 后台处理任务、进度显示、取消、系统通知、处理历史和结果自动加载；
- 拓扑规则检查、问题定位、修复预览、提交、回滚和复检；
- 导出 Shapefile、GeoJSON、GeoPackage、KML、CSV、FlatGeobuf 及常用栅格格式，支持 PDF/PNG/SVG 地图输出。

### HarmonyOS 集成

- 适配 2-in-1 窗口、全屏/分屏/悬浮模式、自定义标题栏和窗口状态保存；
- 华为账号登录、云文件同步和桌面服务卡片入口；
- 中文与深色主题资源，以及面向触控和鼠标的交互布局。

## 技术架构

```text
ArkTS / ArkUI 工作台
        │
        ▼
GisService / GisNativeBridge
        │  N-API
        ▼
libgeonestgis.so（C++）
        │
        ├── QGIS Core（默认后端）
        ├── GDAL / OGR
        ├── GEOS / PROJ
        └── Qt 6 for OHOS
```

应用层负责页面、状态和交互；N-API 桥接层提供稳定的 ArkTS/C++ 边界；原生层负责数据源、渲染、投影、空间运算和后台任务。构建配置也保留了 GDAL/OGR fallback，便于在 QGIS Core 依赖尚未就绪时进行基础链路验证。

## 环境要求

- Windows 10/11；
- DevEco Studio 及 HarmonyOS SDK API 26（target SDK 6.1.1，compatible SDK 6.1.0）；
- DevEco SDK 自带的 Clang/LLVM、CMake 和 Ninja；
- PowerShell 5.1 或更高版本；
- Qt 6.8.3 源码及对应的 host tools；
- QGIS Core、GDAL/OGR、PROJ、GEOS、SQLite、EXPAT、LibZip、Protobuf、ZLIB 等依赖源码或已构建 stage。

## 快速开始

```powershell
git clone https://github.com/haohaoai0/GeoNest.git
cd GeoNest
Copy-Item .\build-profile.example.json5 .\build-profile.json5
```

随后在 DevEco Studio 中配置本机调试签名，并根据本机依赖位置修改 `entry/build-profile.json5` 中的 `QGIS_PREFIX` 和 `QT6_PREFIX`。签名文件、密码、证书路径和本机 build profile 均不应提交到 Git。

如果只需要了解工程结构，可以先打开项目；如果要生成可运行 HAP，则必须先完成原生依赖 stage。依赖构建顺序、参数和常见问题见 [`scripts/build_native/README.md`](scripts/build_native/README.md)。

## 构建流程

### 1. 构建原生依赖

推荐顺序如下：

```text
zlib → sqlite → EXPAT → FreeXL → PROJ → GEOS → GDAL/OGR
→ Qt 6 for OHOS → QGIS Core → GeoNest native bridge
```

依赖脚本位于 [`scripts/build_native`](scripts/build_native)。大型源码树、构建缓存和 stage 目录默认被 `.gitignore` 排除。

### 2. 构建调试 HAP

```powershell
.\scripts\build_entry_hap.ps1
```

脚本会调用 Hvigor 和 CMake，生成 `entry/build/.../*.hap`。在已连接设备上安装时，可使用 DevEco Studio 或对应版本的 `hdc` 工具完成部署。

### 3. 构建签名发布包

```powershell
.\scripts\build_release.ps1
```

发布脚本会校验签名、打包许可证和第三方声明，并生成对应源码归档与 SHA-256 校验文件。发布签名材料从以下环境变量读取：

```text
GEONEST_SIGNING_STORE
GEONEST_SIGNING_PROFILE
GEONEST_SIGNING_CERTIFICATE
GEONEST_SIGNING_ALIAS
GEONEST_SIGNING_PASSWORD
```

不要把 `.p12`、`.p7b`、`.cer`、密码、用户数据、设备日志或本地构建目录提交到仓库。发布 APP/HAP 和对应源码包应通过 GitHub Releases 分发，而不是直接放进 Git 历史。

### 4. 生成对应源码归档

```powershell
.\scripts\package_corresponding_source.ps1 `
  -OutputDirectory .\output\source `
  -VersionName 1.0.3
```

每个包含 GPL/LGPL 组件的二进制版本，都应同时提供精确的 GeoNest、QGIS、Qt 和其他修改后依赖源码归档。详细说明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 和 [`SOURCE_OFFER.txt`](SOURCE_OFFER.txt)。

## 仓库结构

```text
AppScope/                         应用级资源与图标
common/                           公共 ArkTS 模块与样式
features/workbench/               工作台功能模块
entry/src/main/ets/               页面、组件、模型和 GIS 服务
entry/src/main/cpp/               HAP CMake 与原生模块入口
native/gis_core/                  QGIS/GDAL/空间分析实现
native/napi_bridge/               ArkTS ↔ C++ N-API 桥接
native/third_party/               依赖补丁和构建元数据
scripts/                          构建、打包和发布脚本
docs/                             移植计划、设计说明和未来 API 记录
design/                           图标与视觉设计资源
CHANGELOG.md                      版本变更记录
```

## 发布与许可证

GeoNest 以 [GNU GPL-2.0-or-later](LICENSE) 发布，GPL v2 完整文本见 [COPYING](COPYING)。QGIS、Qt、GDAL、GEOS、PROJ 及其他组件的许可证、链接例外、修改说明和对应源码义务见：

- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- [`SOURCE_OFFER.txt`](SOURCE_OFFER.txt)
- [`scripts/package_corresponding_source.ps1`](scripts/package_corresponding_source.ps1)

版本历史见 [`CHANGELOG.md`](CHANGELOG.md)，公开构建和对应源码归档见 [GitHub Releases](https://github.com/haohaoai0/GeoNest/releases)。软件按“原样”提供，不附带适销性或特定用途适用性的担保。

## 贡献指南

欢迎提交 Issue、改进建议和 Pull Request。提交前请：

1. 使用 ArkTS 支持的静态类型写法，并遵守 HarmonyOS API 的权限和 API Level 要求；
2. 对 ArkTS、C++、CMake 和 PowerShell 改动分别完成最小可行构建或静态检查；
3. 为用户可见的中文文案和颜色补齐 base/dark 资源；
4. 对上游 QGIS、Qt 或其他第三方代码的修改注明来源、内容和日期；
5. 不提交签名材料、令牌、用户数据、设备日志、构建缓存和大型依赖工作树。

## 已知限制

- 主线默认后端依赖 QGIS Core 4.1.0 development snapshot，完整构建链较重；
- 云同步、华为账号、桌面卡片和协同能力依赖目标设备的系统服务与登录状态；
- 当前发布定位为 2-in-1 设备，手机版布局仍需单独验证；
- 不同 HarmonyOS SDK、设备 ABI 和 Qt/QGIS 构建选项可能导致行为差异，请以目标设备实测结果为准。

如遇构建失败，建议先确认 SDK/API 版本、`QGIS_PREFIX`/`QT6_PREFIX`、ABI stage 是否完整，再查看 `scripts/build_native/README.md` 和构建日志。
