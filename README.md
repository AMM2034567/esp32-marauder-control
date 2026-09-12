# Marauder Control

仅 Android 的 Flutter 控制端，用 USB Host 串口连接 ESP32 Marauder。

## 首个 Release

当前版本：`v0.2.0`。

Release APK 和 SHA-256 校验文件由 GitHub Actions 在推送 `v*.*.*` tag 后自动构建并发布。

仓库：[AMM2034567/esp32-marauder-control](https://github.com/AMM2034567/esp32-marauder-control)

## 当前状态

- Material 3 控制台、终端和日志页面。
- Marauder CLI 行协议、命令构造、`@MARAUDER` JSON 事件解析和能力模型。
- Android 原生 USB Host 枚举桥接接口。
- 默认使用 Dart mock transport，便于没有真机时运行 UI 和协议测试。
- Android 原生串口连接已接入 `usb-serial-for-android` 3.11.0，默认探测 CH340/CH341、CDC/ACM、CP210x、FTDI 等设备；真实硬件仍需在目标手机和 OTG 线下验证。
- USB 连接成功后会自动发送 `protocolinfo --machine app_probe` 和 `help`，并显示驱动、VID/PID、固件版本和探测状态。
- ESP32 LDDB 的 GPS、直接上传能力默认保持关闭，只有从设备协议明确探测到时才会启用。
- 已增加 WiFi 扫描页面，支持 `scanall`、`list -a`、`stopscan`、AP 列表、信道、RSSI 和扫描状态显示。
- 已增加 SD 只读目录浏览，解析 `ls /` 的文件名和字节数；完整 PCAP/JSON 下载仍需先确认固件串口文件传输协议。
- 命令发送已加入串行队列：短命令等待 `> ` 提示符完成，长扫描命令不阻塞后续停止控制，命令超时为 8 秒，断线时会清理队列。
- WiFi 页面已扩展为 AP、Station、SSID 子页，并支持 `info -a <index>` AP 详情原始文本展示；同时加入 `list -c`、`list -s`、`list -b`、`list -f` 的只读解析模型。
- 已增加 Bluetooth 只读页面，支持 `sniffbt`、`list -b`、`list -f`、停止扫描和 Flipper/BLE 列表；`blespam`、`spoofat` 等危险命令仍不可用。
- WiFi 扫描停止后会自动刷新 AP 列表；SD 页面支持当前目录刷新和返回上级目录。
- 攻击、Evil Portal、BLE spam 等高风险按钮没有暴露；首期仅提供基础查询、扫描和停止控制。
- UI 已接入 `material_3_expressive` 主题和动态配色；长时间操作显示 Expressive 进度条。
- 扫描、列表刷新、详情查询和 Bluetooth 操作启用单操作锁；停止扫描保留为唯一例外，其他操作在执行期间禁用。
- 底部导航收纳为控制台、WiFi、Bluetooth，SD、仿真终端和日志从更多菜单进入。
- 终端改为深色等宽字体仿真终端，使用 `>` 提示符、彩色命令/错误输出和可选文本复制。
- 终端已加入主导航，串口新消息到达时自动滚动到最新一行；文件和日志保留在更多菜单。
- 关闭系统动态配色，固定 Marauder 绿色品牌主题，避免手机系统颜色导致界面整体偏红或偏紫。
- 仿真终端已增加清屏、暂停/恢复自动滚动、上下方向键命令历史和 Expressive 操作进度提示。
- 仿真终端视图已拆分到 `lib/src/features/terminal/marauder_terminal_view.dart`，主页面继续负责会话状态和命令队列。
- 已新增 `lib/src/core/session/marauder_session.dart`，统一管理连接状态、命令队列、流式扫描、停止命令、超时和断线清理；页面层开始通过会话事件接收状态和协议输出。
- WiFi、Bluetooth、SD 页面视图已分别拆分到 `lib/src/features/wifi`、`lib/src/features/bluetooth`、`lib/src/features/storage`，主页面只保留状态和回调适配。
- 已删除主页面中迁移后的旧 WiFi/Bluetooth/SD 页面实现；页面 feature 拆分清理完成。
- v0.2.0 增加 WiFi AP 搜索和 RSSI/信道/名称排序、Bluetooth/SD Controller、终端日志复制，以及 SD 文件分片传输协议提案文档。

## 硬件前置条件

ESP32-D0WD-V3 通常没有原生 USB 外设。请确认 LDDB 板载 CH340/CH341 USB-UART 芯片、Android OTG 线和供电方式。应用会请求 USB 权限并使用 115200 8N1 打开第一个串口。

## 开发

在本目录执行：

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## 目录

- `lib/src/core/models`：设备、能力、串口事件模型。
- `lib/src/core/protocol`：Marauder 文本/JSON 协议解析和命令目录。
- `lib/src/core/transport`：串口 transport 抽象、mock 和 Android channel adapter。
- `android/app/src/main/kotlin`：USB Host、权限、CH340 串口读写和 MethodChannel/EventChannel 边界。
- `test`：协议和 UI 测试。

## CI

GitHub Actions 会在 `main` 分支 push、Pull Request 和版本 tag 时执行：

- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`
- 版本 tag 额外构建 Release APK、生成 SHA-256 并创建 GitHub Release

CI 固定使用 Flutter 3.44.9 stable。

## 固件协议范围

控制端复用仓库中的 Marauder CLI，不重写 ESP32 的 WiFi/BLE 射频功能。首期基于 ESP32 LDDB 能力矩阵；GPS、直接上传等固件未启用的能力必须在 UI 中保持不可用。

SD 文件完整下载协议提案见 [docs/sd-file-transfer-protocol.md](docs/sd-file-transfer-protocol.md)。当前固件未实现该协议，应用仍只提供目录浏览。

## 安全边界

仅用于自有设备和授权实验室。危险命令默认由 UI 拦截，后续如需接入必须增加授权声明、风险说明、二次确认和可靠停止机制。
