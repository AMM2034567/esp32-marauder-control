# SD 文件分片传输协议设计（提案）

## 状态

当前版本仅实现 SD 目录只读浏览。该文档定义未来 PCAP/JSON/文本文件导出边界，不代表当前固件已经支持下载。

## 目标

通过 Marauder 串口将设备端文件可靠传输到 Android，支持：

- 文件名和大小预声明
- 事务 ID
- 固定大小分片
- 分片序号和偏移
- CRC-32 校验
- 完成确认
- 取消和超时
- 文件名安全校验
- 不允许覆盖用户未选择的本地文件

## 建议命令

请求文件：

```text
fileget --machine <tx> --path "/logs/scan.pcap"
```

取消传输：

```text
filecancel --machine <tx>
```

## 机器事件

开始：

```text
@MARAUDER:{"protocol":1,"tx":"abc123","command":"fileget","status":"started","code":"OK","path":"/logs/scan.pcap","size":1048576,"chunkSize":1024,"crc":"CRC32"}
```

数据分片建议使用 Base64 JSON 事件，避免文本串口中的控制字符破坏帧边界：

```text
@MARAUDER:{"protocol":1,"tx":"abc123","command":"fileget","status":"chunk","seq":0,"offset":0,"data":"...base64...","crc32":"..."}
```

完成：

```text
@MARAUDER:{"protocol":1,"tx":"abc123","command":"fileget","status":"success","code":"OK","bytes":1048576,"chunks":1024,"crc32":"..."}
```

错误：

```text
@MARAUDER:{"protocol":1,"tx":"abc123","command":"fileget","status":"error","code":"FILE_NOT_FOUND"}
```

## Android 端状态机

```text
idle -> requesting -> receiving -> verifying -> completed
                         |             |
                         +-> cancel   +-> error
```

规则：

1. 先校验绝对路径和允许的文件类型。
2. 收到 `started` 后创建临时文件，不直接写最终文件名。
3. 每个分片校验序号、偏移、Base64 和 CRC-32。
4. 发现缺片、重复片或校验失败时停止并报告错误。
5. 全部接收后校验总大小和总 CRC，再原子移动到用户选择的位置。
6. 任何超时、断线或用户取消都删除临时文件。
7. 使用 Android Storage Access Framework 让用户选择保存位置。

## 安全边界

- 不接受 `..` 路径穿越。
- 默认只允许 `.pcap`、`.json`、`.txt`、`.log`、`.gpx`。
- 不自动下载、不覆盖现有文件。
- 文件协议需要固件端明确实现和测试后，Android 才能开放下载按钮。
